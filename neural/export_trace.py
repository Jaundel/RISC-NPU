"""Extract sampled RTL signals for a truthful architectural playback.

Sample once per rising edge after delta updates. No interpolated signal values.
All other VCD signals are intentionally omitted from the web payload.
"""
from pathlib import Path
import json
import hashlib

ROOT = Path(__file__).resolve().parents[1]
BASE = 'neural_image_tb.dut.dut'
SIGNALS = {
    'cycle': 'neural_image_tb.cycles[31:0]',
    'pc': BASE+'.doutpc[31:0]', 'ir': BASE+'.doutir[31:0]',
    'a': BASE+'.douta[31:0]', 'b': BASE+'.doutb[31:0]',
    'phase': BASE+'.outt[2:0]',
    'read': BASE+'.memen', 'write': BASE+'.memwen',
    'mem_address': BASE+'.dat.red_out_data_mem[7:0]',
    'mem_value': BASE+'.dat.data_mem_out[31:0]',
    'start': BASE+'.npu_start_s', 'done': BASE+'.npu_done_s',
    'product': BASE+'.npu.mul_result[15:0]',
    'accumulator': BASE+'.npu.wide_acc[31:0]',
    'result': BASE+'.npu_result_s[31:0]',
    'busy': BASE+'.npu.mul0.busy', 'bit': BASE+'.npu.mul0.count[3:0]',
    'partial': BASE+'.npu.mul0.acc_reg[15:0]',
    'shift_a': BASE+'.npu.mul0.a_reg[15:0]',
    'shift_b': BASE+'.npu.mul0.b_reg[7:0]',
}


def main():
    source = ROOT / 'artifacts/raw/neural-trace.vcd'
    scope, ids, widths, values, rows = [], {}, {}, {}, []
    time = 0
    header = True
    reverse = {v: k for k, v in SIGNALS.items()}

    def snapshot():
        if time % 20000000 == 10000000 and values.get('cycle', 0) > 0:
            rows.append([values.get(k) for k in SIGNALS])

    with source.open() as stream:
        for line in stream:
            fields = line.strip().split()
            if not fields: continue
            if header:
                if fields[0] == '$scope': scope.append(fields[2])
                elif fields[0] == '$upscope': scope.pop()
                elif fields[0] == '$var':
                    path = '.'.join(scope + [fields[4]])
                    if path in reverse:
                        key = reverse[path]; ids[fields[3]] = key; widths[key] = int(fields[2])
                elif fields[0] == '$enddefinitions':
                    header = False
                    assert set(ids.values()) == set(SIGNALS), f'Missing signals: {set(SIGNALS)-set(ids.values())}'
            elif fields[0][0] == '#':
                snapshot(); time = int(fields[0][1:])
            else:
                if fields[0][0] == 'b': raw, code = fields[0][1:], fields[1]
                else: raw, code = fields[0][0], fields[0][1:]
                if code in ids:
                    key = ids[code]
                    value = int(raw, 2) if set(raw) <= {'0', '1'} else None
                    if value is not None and key in {'a','b','mem_value','product','accumulator','result'}:
                        if value >= 2 ** (widths[key]-1): value -= 2 ** widths[key]
                    values[key] = value
        snapshot()
    assert len(rows) >= 27000
    out = ROOT / 'article/dist/data'; out.mkdir(parents=True, exist_ok=True)
    payload = {'schema': 1, 'source': 'GHDL RTL simulation', 'pixel': [0, 0],
               'sample': 'post-delta rising-edge, every cycle; pixel (0,0) only',
               'clock_period_ns': 20, 'vcd_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
               'signals': SIGNALS, 'columns': list(SIGNALS), 'rows': rows}
    (out / 'trace.json').write_text(json.dumps(payload, separators=(',', ':')))
    print(f'Exported {len(rows)} actual clock samples ({len(SIGNALS)} signals)')


if __name__ == '__main__': main()
