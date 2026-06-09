# RISC-NPU Timing Constraints
# Target: Cyclone IV E EP4CE115F29C7 on DE2-115 board (50 MHz oscillator)

create_clock -period 20.000 -name clk     [get_ports clk]
create_clock -period 20.000 -name mem_clk [get_ports mem_clk]

derive_clock_uncertainty
