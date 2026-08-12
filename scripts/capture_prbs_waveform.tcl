open_vcd docs/evidence/milestone-03/prbs15_waveform.vcd
log_vcd /tb_prbs15_waveform/clk
log_vcd /tb_prbs15_waveform/rst
log_vcd /tb_prbs15_waveform/load_seed
log_vcd /tb_prbs15_waveform/bit_valid
log_vcd /tb_prbs15_waveform/corrupt_bit
log_vcd /tb_prbs15_waveform/bit_in
log_vcd /tb_prbs15_waveform/error_pulse
log_vcd /tb_prbs15_waveform/source_state
log_vcd /tb_prbs15_waveform/dut_checker/expected_state
run all
close_vcd
quit
