create_clock -name core_clock -period 20.000 [get_ports clk]
derive_clock_uncertainty
# rst and stream/debug ports terminate at virtual pins. Constrain synchronous
# interfaces explicitly; physical board I/O needs its own external constraints.
set_input_delay -clock core_clock 0.0 [get_ports rst]
set_output_delay -clock core_clock 0.0 [get_ports {pixel_valid frame_done pixel_index[*] pixel_rgb[*] cycle_count[*] debug_pc[*] debug_a[*] debug_b[*] debug_phase[*]}]
