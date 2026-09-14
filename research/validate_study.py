"""Fail-closed cross-checks for the released measurements and their provenance."""
import argparse,csv,json,re
from pathlib import Path
from run_experiments import ROOT,digest,CONFIGS

def validate(run,verification,synthesis):
    km=json.loads((run/'manifest.json').read_text()); vm=json.loads((verification/'manifest.json').read_text()); sm=json.loads((synthesis/'manifest.json').read_text())
    for folder,manifest in [(run,km),(verification,vm),(synthesis,sm)]:
        assert manifest['status']=='complete'
        for name,sha in manifest['sources'].items(): assert digest(ROOT/name)==sha,f'Source drift: {name}'
    assert digest(run/'results.csv')==km['results_sha256']
    assert digest(synthesis/'results.csv')==sm['results_sha256']
    assert digest(verification/'verification.log')==vm['log_sha256']
    assert digest(verification/'quantization.csv')==vm['quantization_sha256']
    rows=list(csv.DictReader((run/'results.csv').open())); assert len(rows)==592
    assert sum(int(r['outputs']) for r in rows)==1296==km['verified_outputs']
    cases={c['case']:c for c in km['cases']}; kernels={}; fixture_hashes={}
    for r in rows:
        folder=run/'cases'/r['case']; fixture=json.loads((folder/'inputs.json').read_text()); c=cases[r['case']]
        for name,key in [('inputs.json','input_sha256'),('program.hex','program_sha256'),('simulation.log','log_sha256')]:
            assert digest(folder/name)==c[key],f'Artifact drift: {r["case"]}/{name}'
        assert 'RAM_READBACK_PASS' in (folder/'simulation.log').read_text()
        n,m,cycles=int(r['n']),int(r['m']),int(r['cycles']); weights=[w for row in fixture['weights'] for w in row]
        assert fixture['expected']==[sum(x*w for x,w in zip(fixture['x'],row)) for row in fixture['weights']]
        assert all(-(2**31)<=v<2**31 for v in fixture['expected'])
        key=(n,m,r['configuration']); assert kernels.setdefault(key,r['kernel_sha256'])==r['kernel_sha256']
        key=(n,m,r['family'],r['seed']); assert fixture_hashes.setdefault(key,c['input_sha256'])==c['input_sha256']
        assert int(r['cold'])-cycles==12*n*(m+1)+4
        if r['configuration']=='software':
            k=sum(w!=0 for w in weights); p=sum((w&255).bit_count() for w in weights)
            assert cycles==12*m+9*n*m+141*k+12*p,f'Software accounting mismatch: {r["case"]}'
        else: assert cycles==m*({'iterative_staged':22,'iterative_fused':20,'parallel_fused':12}[r['configuration']]*n+10)
        assert cycles==sum(int(r[k]) for k in ['fetch','memory','scalar','setup','wait'])
    quant=list(csv.DictReader((verification/'quantization.csv').open())); assert len(quant)==2049
    for r in quant:
        q=max(-128,min(127,int(r['accumulator'])>>3))
        assert int(r['signed_int8'])==q and int(r['relu_int8'])==max(0,q)
    fits=list(csv.DictReader((synthesis/'results.csv').open())); assert len(fits)==12
    min_slack=1000
    for r in fits:
        folder=synthesis/f'{r["configuration"]}_seed{r["seed"]}'
        f=next(f for f in sm['fits'] if f['configuration']==r['configuration'] and f['seed']==int(r['seed']))
        assert digest(folder/'core.fit.summary')==f['summary_sha256'] and digest(folder/'core.sta.rpt')==f['timing_sha256']
        assert float(r['fmax_mhz_slow85'])>=50
        slacks=[float(v) for v in re.findall(r'Slack\s*:\s*([-\d.]+)',(folder/'core.sta.summary').read_text())]
        assert slacks and min(slacks)>=0; min_slack=min(min_slack,min(slacks))
        assert int(r['memory_bits'])==8192 and int(r['embedded_multiplier_9bit'])==(1 if r['configuration']=='parallel_fused' else 0)
    return {'status':'pass','kernel_runs':len(rows),'verified_outputs':1296,'fit_runs':12,'minimum_reported_slack_ns':min_slack,
            'checks':['source hashes','raw artifact hashes','matched fixtures','kernel invariance','RAM readback',
                      'independent outputs','exact cycle identities','cycle partition','quantization reference','timing summaries']}

if __name__=='__main__':
    ap=argparse.ArgumentParser(); ap.add_argument('--run',type=Path,required=True); ap.add_argument('--verification',type=Path,required=True); ap.add_argument('--synthesis',type=Path,required=True)
    a=ap.parse_args(); print(json.dumps(validate(a.run,a.verification,a.synthesis),indent=2))
