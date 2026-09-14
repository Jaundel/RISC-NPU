"""Capture provenance while a run is active; refuse sources newer than its start."""
from pathlib import Path
import argparse
import hashlib
import json
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ['multiplier.vhd','accumulator.vhd','relu.vhd','npu_core.vhd',
           'fulladd.vhd','adder4.vhd','adder16.vhd','adder32.vhd','add.vhd',
           'mux2to1.vhd','mux4to1.vhd','register32.vhd','PC.vhd','LZE.vhd','UZE.vhd',
           'RED.vhd','alu.vhd','data_mem.vhd','data_path.vhd','reset_circuit.vhd',
           'Control_New.vhd','cpu1.vhd','neural/generated/neural_program.vhd',
           'neural/neural_image_system.vhd','tb/neural_image_tb.vhd',
           'neural/generated/expected-rgb.txt','neural/assets/model.json']


def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--start-unix',type=float,required=True)
    parser.add_argument('--output',default='artifacts/raw/run-inputs.json'); args=parser.parse_args()
    inputs={}
    for name in SOURCES:
        path=ROOT/name
        assert path.stat().st_mtime <= args.start_unix, f'Source changed after run start: {name}'
        inputs[name]=hashlib.sha256(path.read_bytes()).hexdigest()
    output=ROOT/args.output
    assert not output.exists(), 'Do not overwrite an existing run provenance record'
    output.write_text(json.dumps({'schema':1,'started_unix':args.start_unix,
        'captured_at':datetime.now(timezone.utc).isoformat(),
        'method':'source hashes captured during run; every source mtime precedes process start',
        'inputs':inputs},indent=2)+'\n')
    print(f'Sealed {len(inputs)} unchanged inputs')


if __name__=='__main__': main()
