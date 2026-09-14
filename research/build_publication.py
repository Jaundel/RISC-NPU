"""Validate completed experiments and package the article for local staging."""
import argparse
import json
import shutil
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path

from run_experiments import ROOT, SOURCES, digest
from stage_article import prepare_evidence, stage
from validate_study import validate


def run_regressions(evidence):
    result = subprocess.run(
        [shutil.which('pwsh') or 'powershell', '-NoProfile', '-File',
         str(ROOT / 'scripts/run_ghdl_tests.ps1')],
        cwd=ROOT, capture_output=True, text=True,
    )
    output = result.stdout + result.stderr
    (evidence / 'regression.log').write_text(output)
    assert result.returncode == 0, output
    assert 'All 13 RISC-NPU GHDL regressions passed' in result.stdout, output


def source_files():
    files = [ROOT / f'{name}.vhd' for name in SOURCES]
    files.extend(ROOT / name for name in [
        'system_memory.vhd', 'system_memory.mif', 'risc_npu_top.vhd',
        'README.md', 'scripts/run_ghdl_tests.ps1',
    ])
    files.extend(path for path in (ROOT / 'tb').rglob('*.vhd')
                 if 'neural_image' not in path.name)
    files.extend(path for path in (ROOT / 'research').iterdir()
                 if path.is_file())
    return sorted(set(files))


def build_archive(archive_path, run, verification, synthesis, evidence):
    report_suffixes = {'.json', '.csv', '.qsf', '.qpf', '.sdc', '.log', '.rpt', '.summary'}
    with zipfile.ZipFile(archive_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in source_files():
            archive.write(path, str(path.relative_to(ROOT)))
        for folder in (run, verification):
            for path in folder.rglob('*'):
                if path.is_file() and 'work' not in path.relative_to(folder).parts:
                    archive.write(path, str(path.relative_to(ROOT)))
        for path in synthesis.rglob('*'):
            if (path.is_file() and path.suffix in report_suffixes
                    and len(path.relative_to(synthesis).parts) <= 2):
                archive.write(path, str(path.relative_to(ROOT)))
        archive.write(evidence / 'regression.log', 'evidence/regression.log')
    with zipfile.ZipFile(archive_path) as archive:
        assert archive.testzip() is None, 'Corrupt reproduction archive'


def main():
    parser = argparse.ArgumentParser()
    for name in ('run', 'verification', 'synthesis', 'article'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    run = args.run.resolve()
    verification = args.verification.resolve()
    synthesis = args.synthesis.resolve()
    article = args.article.resolve()

    check = validate(run, verification, synthesis)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    evidence = ROOT / 'artifacts' / 'publication' / stamp
    evidence.mkdir(parents=True)
    run_regressions(evidence)
    check['regression_tests'] = 13

    data = article / 'assets' / 'data'
    data.mkdir(parents=True, exist_ok=True)
    shutil.copy2(evidence / 'regression.log', data / 'regression.log')
    archive_path = data / 'reproduction.zip'
    build_archive(archive_path, run, verification, synthesis, evidence)

    publication = {
        **check,
        'created_utc': datetime.now(timezone.utc).isoformat(),
        'figure_generator_sha256': digest(ROOT / 'research/plot_results.py'),
        'archive_sha256': digest(archive_path),
        'figures': {path.name: digest(path)
                    for path in sorted((article / 'assets/figures').glob('*.svg'))},
        'kernel_run': run.name,
        'arithmetic_run': verification.name,
        'synthesis_run': synthesis.name,
    }
    manifest = json.dumps(publication, indent=2)
    (data / 'publication-manifest.json').write_text(manifest)
    (evidence / 'validation.json').write_text(manifest)
    prepare_evidence(article)

    html = (article / 'index.html').read_text(encoding='utf-8')
    assert 'canvas' not in html and '<script' not in html
    css = (article / 'style.css').read_text()
    assert css.count('{') == css.count('}')
    previous_css = subprocess.check_output(
        ['git', 'show', 'HEAD:style.css'], cwd=article, text=True,
    )
    assert css.startswith(previous_css.rstrip()), 'Existing stylesheet was replaced'
    staged = stage(article)
    print(json.dumps({
        'status': 'validated',
        'regressions': 13,
        'figures': staged['figures'],
        'links_checked': staged['links'],
        'archive_bytes': archive_path.stat().st_size,
        'evidence': str(evidence),
        'staged': staged['staged'],
    }, indent=2))


if __name__ == '__main__':
    main()
