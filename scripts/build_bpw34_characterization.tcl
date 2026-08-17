set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
cd $repo_dir

set output_dir [file join artifacts bitstreams]
set report_dir [file join artifacts reports]
file mkdir $output_dir
file mkdir $report_dir

read_verilog -sv [list \
    rtl/common/reset_sync.sv \
    rtl/common/async_input_sync.sv \
    rtl/common/clock_enable_gen.sv \
    rtl/common/prbs15_gen.sv \
    rtl/common/uart_tx.sv \
    rtl/common/crc16_ccitt.sv \
    rtl/tx/optical_framer.sv \
    rtl/tx/laser_output_guard.sv \
    rtl/acquisition/xadc_drp_controller.sv \
    rtl/acquisition/xadc_single_channel.sv \
    rtl/acquisition/sample_capture.sv \
    rtl/control/capture_streamer.sv \
    rtl/control/packet_tx.sv \
    rtl/top/bpw34_characterization_top.sv]

read_xdc [list \
    constraints/arty_a7_100t_base.xdc \
    constraints/bpw34_characterization_top.xdc]

synth_design -top bpw34_characterization_top -part xc7a100tcsg324-1

# Vivado 2026.1's optional block-RAM power pass fails internally on the
# capture RAM. This supported directive omits that pass and retains the normal
# netlist cleanup used by the Milestone 07 routed build.
opt_design -directive RuntimeOptimized
place_design
route_design

report_utilization -file [file join $report_dir milestone-08-utilization.rpt]
report_timing_summary -file [file join $report_dir milestone-08-timing-summary.rpt]
report_drc -file [file join $report_dir milestone-08-drc.rpt]

write_bitstream -force [file join $output_dir bpw34_characterization_top.bit]
quit
