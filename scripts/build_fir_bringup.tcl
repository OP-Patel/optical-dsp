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
    rtl/dsp/dc_removal.sv \
    rtl/dsp/fir_coefficients.sv \
    rtl/dsp/round_saturate.sv \
    rtl/dsp/fir_filter.sv \
    rtl/top/dc_removal_bringup_top.sv]

read_xdc [list \
    constraints/arty_a7_100t_base.xdc \
    constraints/dc_removal_bringup_top.xdc]

synth_design -top dc_removal_bringup_top -part xc7a100tcsg324-1

opt_design -directive RuntimeOptimized
place_design
route_design

report_utilization -file [file join $report_dir milestone-10-utilization.rpt]
report_timing_summary -file [file join $report_dir milestone-10-timing-summary.rpt]
report_drc -file [file join $report_dir milestone-10-drc.rpt]

write_bitstream -force [file join $output_dir fir_bringup_top.bit]
quit
