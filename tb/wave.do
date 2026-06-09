# ============================================================
# wave.do  —  RISC-NPU benchmark waveform viewer
#
# Usage from Questa GUI:
#   Transcript: do tb/wave.do
#   Or: vsim -do tb/wave.do
# ============================================================

# Compile
vcom -2008 -quiet \
    fulladd.vhd adder4.vhd adder16.vhd adder32.vhd add.vhd \
    LZE.vhd UZE.vhd RED.vhd counter.vhd \
    PC.vhd register32.vhd mux2to1.vhd mux4to1.vhd \
    alu.vhd data_mem.vhd \
    multiplier.vhd accumulator.vhd relu.vhd npu_core.vhd \
    data_path.vhd Control_New.vhd reset_circuit.vhd cpu1.vhd \
    tb/bench_tb.vhd

vsim -gui bench_tb

# Clear and build wave window
delete wave *

add wave -divider "--- Clock / Reset ---"
add wave -label "clk"     /bench_tb/clk
add wave -label "rst"     /bench_tb/rst

add wave -divider "--- CPU State (T: 001=Fetch 010=Decode 100=Execute 111=MAC_WAIT) ---"
add wave -label "T"       -radix binary   /bench_tb/outT

add wave -divider "--- Program Counter & IR ---"
add wave -label "PC"      -radix unsigned /bench_tb/dOutPC
add wave -label "IR"      -radix hex      /bench_tb/dOutIR

add wave -divider "--- Registers ---"
add wave -label "Reg A"   -radix unsigned /bench_tb/dOutA
add wave -label "Reg B"   -radix unsigned /bench_tb/dOutB

add wave -divider "--- NPU ---"
add wave -label "npu_start" /bench_tb/dut/npu_start_s
add wave -label "npu_done"  /bench_tb/dut/npu_done_s

# Run the full benchmark
run -all

# Zoom to show the MAC_WAIT stall region (roughly cycle 168-186)
# Each cycle = 10 ns  →  cycle 160 = 1600 ns, cycle 190 = 1900 ns
wave zoom range 1550ns 1900ns

