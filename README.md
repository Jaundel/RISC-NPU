# RISC-NPU

A custom 32-bit RISC processor with a signed multiply–accumulate extension for FPGA implementation. The instruction set is custom; it does not implement RISC-V.

[Read the article](https://jaundel.github.io/risc-npu-article/) · [Reproduce the experiments](research/README.md)

## Architecture

The processor has two operand registers, a multicycle controller, and 256 words of data RAM. The NPU accepts signed eight-bit operands through the existing registers and returns its result through the datapath. Its instructions support explicit accumulator initialization, signed 32-bit saturating accumulation, and conversion to signed or ReLU INT8 output. The original 16-bit MAC/ReLU instruction remains supported.

Four configurations isolate the effects of hardware multiplication and result timing:

- Software multiplication on the scalar core.
- An iterative multiplier with separate result-retirement states.
- The same multiplier with fused retirement.
- A registered parallel multiplier with fused retirement.

## Results

For a 64-element dot product with uniformly sampled signed-byte inputs, median software execution takes 12,648 cycles. The parallel configuration takes 778 cycles, a 16.26× kernel speedup. Including the common input-writing program and reset settling gives 6.12×. With all-zero weights, software skips multiplication and wins: 588 versus 778 cycles.

These are CPU simulation results. The FPGA results are matched core fits for a Cyclone IV E EP4CE115F29C7 under a 50 MHz constraint. The experiments do not measure board performance, power, energy, or trained-network accuracy.

The evidence includes 592 kernel runs, 1,296 checked outputs, 196,608 product checks, 12,294 conversion checks, and 12 FPGA fits. Raw records and exact experiment sources are available in the article's reproduction download.

## Run the regression suite

Install GHDL and run from the repository root in PowerShell:

```powershell
.\scripts\run_ghdl_tests.ps1
```

The suite covers 13 arithmetic, register, branch, processor/NPU integration, and board-wrapper tests. The Questa workflow is available in `scripts/run_wave_tests.ps1`.

## Repository guide

| Path | Purpose |
| --- | --- |
| `cpu1.vhd`, `Control_New.vhd`, `data_path.vhd` | Processor configuration, instruction control, and datapath |
| `npu_core.vhd` | Operand capture, MAC variants, accumulator, and output conversion |
| `risc_npu_top.vhd`, `system_memory.mif` | DE2-115 wrapper and legacy demonstration program |
| `tb/` | Unit and integration testbenches |
| `research/` | Workload generation, measurements, fitting, validation, and figures |
| `neural/`, `synthesis/neural/` | Earlier neural-image experiment, retained separately from the article's evaluated kernels |

The board wrapper retains its original pin assignments and demonstration program. Its measurement boundary differs from the research core fits. See the study guide for precise timing and resource boundaries.
