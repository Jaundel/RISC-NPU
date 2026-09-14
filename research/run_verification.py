"""Archive an exhaustive multi-configuration arithmetic verification run."""
import json,subprocess,argparse
from datetime import datetime,timezone
from run_experiments import ROOT,digest

ap=argparse.ArgumentParser(); ap.add_argument('--ghdl',default='ghdl'); args=ap.parse_args()
run=ROOT/'artifacts'/'verification'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
run.mkdir(parents=True); (run/'work').mkdir()
sources=[ROOT/f'{s}.vhd' for s in ['multiplier','accumulator','relu','npu_core']]+[ROOT/'tb/research_arithmetic_tb.vhd']
flags=['--std=08','-fsynopsys',f'--workdir={run/"work"}']
subprocess.run([args.ghdl,'-a',*flags,*map(str,sources)],check=True)
r=subprocess.run([args.ghdl,'-r',*flags,'research_arithmetic_tb',f'-gRESULTS_FILE={run/"quantization.csv"}','--assert-level=error','--ieee-asserts=disable-at-0'],capture_output=True,text=True)
(run/'verification.log').write_text(r.stdout+r.stderr)
assert r.returncode==0 and 'EXHAUSTIVE_PASS' in r.stdout,r.stdout+r.stderr
(run/'manifest.json').write_text(json.dumps({'status':'complete','product_checks':196608,'pairs':65536,'configurations':3,
    'quantization_checks':12294,'quantization_sha256':digest(run/'quantization.csv'),
    'sources':{str(p.relative_to(ROOT)):digest(p) for p in sources},'log_sha256':digest(run/'verification.log')},indent=2))
print(r.stdout); print(f'COMPLETE {run}')
