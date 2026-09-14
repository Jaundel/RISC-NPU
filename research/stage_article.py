"""Stage the linked article files locally; never publish or edit sealed runs."""
import argparse
import hashlib
import json
import shutil
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import unquote, urlsplit

from article_page import Page


def stage(article):
    article = Path(article).resolve(strict=True)
    html = (article / 'index.html').read_text(encoding='utf-8')
    page = Page()
    page.feed(html)
    assert not page.stack, 'Unclosed HTML tags'
    assert '\u2014' not in html, 'Em dash in article'
    assert len(page.images) == 6, 'Unexpected figure inventory'
    linked = {Path('index.html')}
    for link in page.links:
        url = urlsplit(link)
        if url.scheme or url.netloc:
            continue
        if not url.path:
            assert not url.fragment or url.fragment in page.ids, link
            continue
        relative = Path(unquote(url.path))
        resolved = (article / relative).resolve()
        assert resolved.is_relative_to(article), link
        assert relative.suffix in {'.html', '.css', '.svg', '.png', '.csv', '.json', '.log', '.zip'}, link
        assert resolved.is_file(), link
        linked.add(relative)
    runtime = article / '.sites-runtime'
    runtime.mkdir(exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    pending = runtime / ('article-stage-' + stamp)
    pending.mkdir()
    for relative in sorted(linked):
        target = pending / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(article / relative, target)
    dist = article / 'dist'
    assert dist.parent == article and not dist.is_symlink()
    backup = None
    if dist.exists():
        backup = runtime / ('article-dist-backup-' + stamp)
        dist.rename(backup)
    pending.rename(dist)
    assert not list(dist.rglob('*.md'))
    return {'files': len(linked), 'figures': len(page.images), 'links': len(page.links),
            'staged': str(dist), 'previous_dist_preserved': str(backup) if backup else None}


def prepare_evidence(article):
    """Create a derivative download without editorial notes; retain original zip."""
    data = Path(article).resolve() / 'assets' / 'data'
    source = data / 'reproduction.zip'
    target = data / 'reproduction-article.zip'
    with zipfile.ZipFile(source) as old, zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as new:
        for item in old.infolist():
            if item.filename.replace('\\', '/') == 'docs/RESEARCH_REVAMP.md':
                continue
            name = item.filename.replace('\\', '/')
            project_file = Path(__file__).resolve().parents[1] / name
            if name in {'README.md', 'research/README.md'}:
                new.writestr(item, project_file.read_bytes())
            else:
                new.writestr(item, old.read(item.filename))
    with zipfile.ZipFile(target) as check:
        assert check.testzip() is None
    manifest = json.loads((data / 'publication-manifest.json').read_text())
    manifest.pop('visual_review', None)
    manifest['original_archive_sha256'] = manifest['archive_sha256']
    manifest['archive_sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
    manifest['archive_file'] = target.name
    manifest['packaging_note'] = 'Editorial notes omitted and reproduction documentation refreshed. Experiment sources and records unchanged.'
    (data / 'article-evidence-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--article', type=Path, required=True)
    parser.add_argument('--prepare-evidence', action='store_true')
    args = parser.parse_args()
    if args.prepare_evidence:
        prepare_evidence(args.article)
    print(json.dumps(stage(args.article), indent=2))
