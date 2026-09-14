# RISC-NPU Timing Constraints
# Target board clock: 50 MHz

create_clock -period 20.000 -name CLOCK_50 [get_ports CLOCK_50]

# KEY(0) is an asynchronous push-button reset in the hardware wrapper.
set_false_path -from [get_ports {KEY[*]}]

# LEDs are human-visible debug/status outputs, not synchronous off-chip buses.
set_false_path -to [get_ports {LEDR[*] LEDG[*]}]

derive_clock_uncertainty
