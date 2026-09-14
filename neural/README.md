# Neural image rendering

The workload is a trained `2 → 32 → 32 → 3` coordinate MLP. Integer x/y
coordinates enter the CPU; the NPU computes each layer, and the final three
outputs encode RGB. Training targets come from a reproducible analytic
interference field, not a stored image used at inference time.

Arithmetic contract: signed int8 operands, signed saturating int32 accumulation,
signed int16 bias seed, arithmetic right shift by six (floor, including negative
values), then ReLU/clamp to 0..127. Display maps 0..127 to 0..255. All layers share
this contract. Frozen JSON weights make retraining unnecessary for reproduction.

Commands added to the custom ISA:

| Opcode | Meaning | Result in A |
| --- | --- | --- |
| B | Legacy MAC16 followed by ReLU | Legacy result |
| C | Seed wide accumulator from signed A[15:0] | Signed bias |
| D | Accumulate signed A[7:0] × B[7:0] in int32 | Raw wide sum |
| E | Shift by instruction[4:0]; instruction[8] selects ReLU | Clamped int8, sign extended |

The multiplier is shared between legacy and wide MAC. Wide and legacy
accumulators are separate. E does not destroy the accumulator. All operations
use the same start/done CPU stall handshake. No throughput claim follows from
these instructions alone: firmware loads/stores and reset/frame boundaries must
be included in the image-level measurement.

Run training in the project environment with `python neural/train.py`. The
integer reference is not an RTL result; it becomes verified only after every
channel is compared against a fresh processor simulation.
