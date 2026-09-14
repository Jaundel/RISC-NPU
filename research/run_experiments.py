"""Reproducible CPU-RTL study; no operand-specialized kernel instructions.

Run with --smoke first. Every invocation creates a new, immutable evidence folder.
GHDL must be installed; --ghdl accepts a non-PATH installation.
"""
from __future__ import annotations
import argparse, csv, hashlib, json, random, re, subprocess, time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ('multiplier accumulator relu npu_core fulladd adder4 adder16 adder32 add '
           'mux2to1 mux4to1 register32 PC LZE UZE RED alu data_mem data_path '
           'reset_circuit Control_New cpu1').split()
CONFIGS = ['software', 'iterative_staged', 'iterative_fused', 'parallel_fused']

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

class Program:
    def __init__(self): self.words = []
    def emit(self, opcode, value=0):
        self.words.append((opcode << 24) | value)
        return len(self.words)-1
    def load_signed(self, value):
        # Fixed-size input setup keeps absolute kernel branch targets invariant.
        self.emit(0x00); self.emit(0x10, abs(value))
        self.emit(0x72 if value < 0 else 0x70)

def firmware(x, weights, config):
    p = Program(); n = len(x); m = len(weights)
    assert n*(m+1) <= 232 and m <= 8
    values = x + [w & 255 for row in weights for w in row]
    for addr, value in enumerate(values):
        p.load_signed(value); p.emit(0x20, addr)
    start = len(p.words)
    for row in range(m):
        if config:
            p.emit(0x00); p.emit(0xC0)
            for i in range(n):
                p.emit(0x90, i); p.emit(0xA0, n+row*n+i); p.emit(0xD0)
        else:
            p.emit(0x00); p.emit(0x20, 232)
            for i in range(n):
                # Ordinary runtime zero skip, not a fixture-specific shortcut.
                p.emit(0x90, n+row*n+i); p.emit(0x79, 255)
                zero_branch = p.emit(0x7A)
                p.emit(0x90, i); p.emit(0x20, 233)
                for bit in range(8):
                    # Test the original coefficient with immediate bit masks;
                    # avoid shifting and spilling the coefficient every bit.
                    p.emit(0x90, n+row*n+i); p.emit(0x79, 1 << bit)
                    branch = p.emit(0x7A)
                    p.emit(0x90, 232); p.emit(0xA0, 233)
                    p.emit(0x72 if bit==7 else 0x70); p.emit(0x20, 232)
                    p.words[branch] |= len(p.words)
                    if bit < 7:
                        p.emit(0x90, 233); p.emit(0x74); p.emit(0x20, 233)
                p.words[zero_branch] |= len(p.words)
            p.emit(0x90, 232)
        p.emit(0x20, 240+row)
    end = len(p.words)
    # Untimed audit loads prove that every output actually reached data RAM.
    for row in range(m): p.emit(0x90, 240+row)
    p.emit(0x80, len(p.words))
    assert len(p.words)<65536
    kernel = p.words[start:end]
    return p.words, start, hashlib.sha256(b''.join(w.to_bytes(4,'big') for w in kernel)).hexdigest(), len(kernel)

def inputs(n, m, family, seed):
    rng = random.Random(seed+n*1009+m*9176)
    def sample(i):
        if family=='zero': return 0
        if family=='small': return rng.randint(-7,7)
        if family=='sparse': return rng.randint(-128,127) if rng.random()<0.2 else 0
        if family=='extrema': return -128 if i%2 else 127
        return rng.randint(-128,127)
    if family.startswith('density_'):
        density=float(family.split('_')[1])
        x=[rng.choice([v for v in range(-128,128) if v]) for _ in range(n)]
        w=[[rng.choice([v for v in range(-128,128) if v]) if rng.random()<density else 0 for _ in range(n)] for _ in range(m)]
        return x,w
    return [sample(i) for i in range(n)], [[sample(i+r) for i in range(n)] for r in range(m)]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--ghdl', default='ghdl'); ap.add_argument('--smoke',action='store_true')
    ap.add_argument('--output',type=Path); ap.add_argument('--replicates',type=int,default=3); args=ap.parse_args()
    run=args.output or ROOT/'artifacts'/'research'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    run.mkdir(parents=True,exist_ok=False); (run/'work').mkdir(); (run/'cases').mkdir()
    flags=['--std=08','-fsynopsys',f'--workdir={run / "work"}']
    sources=[ROOT/f'{s}.vhd' for s in SOURCES]+[ROOT/'tb/research_kernel_tb.vhd']
    manifest={'created_utc':datetime.now(timezone.utc).isoformat(),'seeds':list(range(1729,1729+args.replicates)),'smoke':args.smoke,
              'sources':{str(p.relative_to(ROOT)):digest(p) for p in sources+[Path(__file__)]},
              'ghdl':subprocess.check_output([args.ghdl,'--version'],text=True),
              'timing':'first kernel fetch through final output store retirement, inclusive; cold starts first rising edge after reset release',
              'clock_period_ns':10,'clock_is_simulation_only':True,'cases':[]}
    for p in sources: subprocess.run([args.ghdl,'-a',*flags,str(p)],check=True,capture_output=True,text=True)
    shapes=[(1,1),(8,1)] if args.smoke else [(n,1) for n in [1,4,8,16,32,64,96]]+[(8,4),(16,4),(16,8),(32,4)]
    families=['full','extrema'] if args.smoke else ['zero','sparse','small','full','extrema']
    fixtures=[(n,m,family,seed) for n,m in shapes for family in families
              for seed in ([1729] if args.smoke or family in ['zero','extrema'] else range(1729,1729+args.replicates))]
    if not args.smoke:
        fixtures += [(64,1,f'density_{d}',seed) for d in [0,0.01,0.02,0.05,0.1,0.2,0.4,0.7,1]
                     for seed in range(1729,1729+args.replicates)]
    rows=[]; hashes={}; start_time=time.monotonic()
    for n,m,family,seed in fixtures:
            x,w=inputs(n,m,family,seed); expected=[sum(a*b for a,b in zip(x,r)) for r in w]
            for config,name in enumerate(CONFIGS):
                case=f'n{n}_m{m}_{family}_s{seed}_{name}'; folder=run/'cases'/case; folder.mkdir()
                words,entry,khash,codewords=firmware(x,w,config)
                key=(n,m,name)
                assert hashes.setdefault(key,khash)==khash, 'value-dependent kernel specialization'
                (folder/'program.hex').write_text(''.join(f'{v:08X}\n' for v in words))
                (folder/'expected.hex').write_text(''.join(f'{v & 0xFFFFFFFF:08X}\n' for v in expected))
                (folder/'inputs.json').write_text(json.dumps({'x':x,'weights':w,'expected':expected},indent=2))
                cmd=[args.ghdl,'-r',*flags,'research_kernel_tb',f'-gPROGRAM_FILE={folder/"program.hex"}',
                     f'-gEXPECTED_FILE={folder/"expected.hex"}',f'-gSTART_PC={entry}',f'-gOUTPUT_COUNT={m}',f'-gCONFIG={config}',
                     '--assert-level=error','--ieee-asserts=disable-at-0','--max-stack-alloc=0']
                result=subprocess.run(cmd,text=True,capture_output=True)
                (folder/'simulation.log').write_text(result.stdout+result.stderr)
                if result.returncode: raise RuntimeError(f'{case} failed: {result.stdout[-2500:]} {result.stderr[-1000:]}')
                match=re.search(r'RESULT (.*)',result.stdout)
                if not match: raise RuntimeError(f'No measurement in {case}')
                if 'RAM_READBACK_PASS' not in result.stdout: raise RuntimeError(f'No RAM audit in {case}')
                stats={k:int(v) for k,v in re.findall(r'(\w+)=(\d+)',match[1])}
                assert stats['cycles']==sum(stats[k] for k in ['fetch','memory','wait','setup','scalar'])
                row={'case':case,'n':n,'m':m,'family':family,'seed':seed,'configuration':name,'macs':n*m,
                     'weight_density':sum(v!=0 for row in w for v in row)/(n*m),
                     'kernel_words':codewords,'kernel_sha256':khash,'input_words':n*(m+1),**stats}
                rows.append(row)
                manifest['cases'].append({'case':case,'program_sha256':digest(folder/'program.hex'),
                                          'input_sha256':digest(folder/'inputs.json'),'log_sha256':digest(folder/'simulation.log')})
                with (run/'results.csv').open('w',newline='') as f:
                    writer=csv.DictWriter(f,fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
                print(f'{case}: {stats["cycles"]} cycles, verified {m} outputs',flush=True)
    manifest['elapsed_seconds']=time.monotonic()-start_time; manifest['verified_outputs']=sum(r['outputs'] for r in rows)
    manifest['results_sha256']=digest(run/'results.csv'); manifest['status']='complete'
    (run/'manifest.json').write_text(json.dumps(manifest,indent=2))
    print(f'COMPLETE {run}',flush=True)

if __name__=='__main__': main()
