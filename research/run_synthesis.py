"""Controlled Quartus fits. Results describe a virtual-pin core, not a board."""
import argparse,csv,json,re,subprocess
from pathlib import Path
from datetime import datetime,timezone
from run_experiments import ROOT,SOURCES,CONFIGS,digest

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--quartus',default=r'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe')
    ap.add_argument('--seeds',default='1,2,3'); args=ap.parse_args()
    run=ROOT/'artifacts'/'synthesis'/datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'); run.mkdir(parents=True)
    sources=[ROOT/f'{s}.vhd' for s in SOURCES]+[ROOT/'research/research_core_top.vhd']
    manifest={'created_utc':datetime.now(timezone.utc).isoformat(),'device':'EP4CE115F29C7','target_clock_mhz':50,
              'boundary':'Virtual-pin CPU core including 256x32 data RAM; external instruction source; no program ROM or board I/O',
              'sources':{str(p.relative_to(ROOT)):digest(p) for p in sources+[Path(__file__)]},'fits':[]}
    rows=[]
    for seed in map(int,args.seeds.split(',')):
        for config,name in enumerate(CONFIGS):
            folder=run/f'{name}_seed{seed}'; folder.mkdir()
            qsf=['set_global_assignment -name FAMILY "Cyclone IV E"',
                 'set_global_assignment -name DEVICE EP4CE115F29C7',
                 'set_global_assignment -name TOP_LEVEL_ENTITY research_core_top',
                 'set_global_assignment -name VHDL_INPUT_VERSION VHDL_2008',
                 'set_global_assignment -name NUM_PARALLEL_PROCESSORS 4',
                 f'set_global_assignment -name SEED {seed}',
                 'set_global_assignment -name SDC_FILE core.sdc',
                 f'set_parameter -name CONFIG {config}',
                 'set_location_assignment PIN_Y2 -to clk',
                 'set_instance_assignment -name VIRTUAL_PIN ON -to rst',
                 'set_instance_assignment -name VIRTUAL_PIN ON -to instruction[*]',
                 'set_instance_assignment -name VIRTUAL_PIN ON -to address[*]',
                 'set_instance_assignment -name VIRTUAL_PIN ON -to result_a[*]']
            qsf += [f'set_global_assignment -name VHDL_FILE "{p.as_posix()}"' for p in sources]
            (folder/'core.qsf').write_text('\n'.join(qsf)+'\n')
            (folder/'core.qpf').write_text('PROJECT_REVISION = "core"\n')
            (folder/'core.sdc').write_text('create_clock -name clk -period 20.000 [get_ports {clk}]\n'
                'derive_clock_uncertainty\nset_input_delay -clock clk 2.000 [get_ports {instruction[*]}]\n'
                'set_output_delay -clock clk 2.000 [get_ports {address[*] result_a[*]}]\n'
                'set_false_path -from [get_ports {rst}]\n')
            with (folder/'compile.log').open('w') as log:
                result=subprocess.run([args.quartus,'--flow','compile','core'],cwd=folder,stdout=log,stderr=subprocess.STDOUT)
            if result.returncode: raise RuntimeError(f'Fit failed; inspect {folder/"compile.log"}')
            summary=(folder/'core.fit.summary').read_text(); timing=(folder/'core.sta.rpt').read_text()
            def integer(label):
                match=re.search(re.escape(label)+r'\s*:\s*([\d,]+)',summary)
                return int(match[1].replace(',','')) if match else None
            # Preserve all timing reports; parse the named slow 85C Fmax section.
            section=re.search(r'Slow 1200mV 85C Model Fmax Summary[\s\S]*?;\s*([\d.]+) MHz\s*;\s*([\d.]+) MHz\s*;\s*clk',timing)
            fmax=float(section[1]) if section else None
            row={'configuration':name,'seed':seed,'logic_elements':integer('Total logic elements'),
                 'registers':integer('Total registers'),'memory_bits':integer('Total memory bits'),
                 'embedded_multiplier_9bit':integer('Embedded Multiplier 9-bit elements'),'fmax_mhz_slow85':fmax}
            rows.append(row)
            manifest['fits'].append({'configuration':name,'seed':seed,'summary_sha256':digest(folder/'core.fit.summary'),
                                    'timing_sha256':digest(folder/'core.sta.rpt')})
            with (run/'results.csv').open('w',newline='') as f:
                writer=csv.DictWriter(f,fieldnames=list(row)); writer.writeheader(); writer.writerows(rows)
            print(json.dumps(row),flush=True)
    manifest['status']='complete'; manifest['results_sha256']=digest(run/'results.csv')
    (run/'manifest.json').write_text(json.dumps(manifest,indent=2)); print(f'COMPLETE {run}')

if __name__=='__main__': main()
