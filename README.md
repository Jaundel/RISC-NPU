# RISC-NPU

RISC-NPU is a VHDL/Quartus project that extends a 32-bit RISC CPU with hooks for neural-processing instructions such as MAC, RELU, and VLOAD. The project targets the Altera Cyclone IV E EP4CE115F29C7 device and is set up for Intel Quartus Prime Lite.

## Project Status

- CPU and datapath source files are included.
- Quartus project files are included as `RISC-NPU.qpf` and `RISC-NPU.qsf`.
- NPU integration hooks and stubs are present.
- Generated Quartus build/cache outputs are ignored.

## Key Files

- `cpu1.vhd` - top-level CPU entity.
- `data_path.vhd` - CPU datapath and NPU result hook.
- `Control_New.vhd` - control logic.
- `npu_core.vhd` - NPU core scaffold.
- `system_memory.mif` - memory initialization data.
- `PROJECT_CONTEXT.md` - detailed design context and implementation notes.

## Toolchain

- Intel Quartus Prime Lite 25.1std
- VHDL with IEEE `std_logic_1164`, `std_logic_arith`, and `std_logic_unsigned`

Open `RISC-NPU.qpf` in Quartus to work with the project.
