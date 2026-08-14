set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
cd $repo_dir

set output_dir [file join artifacts bitstreams]
set report_dir [file join artifacts reports]
file mkdir $output_dir
file mkdir $report_dir

read_verilog -sv [list \
    rtl/common/reset_sync.sv \
    rtl/acquisition/xadc_drp_controller.sv \
    rtl/acquisition/xadc_single_channel.sv \
    rtl/top/xadc_bringup_top.sv]

read_xdc [list \
    constraints/arty_a7_100t_base.xdc \
    constraints/xadc_bringup_top.xdc]

synth_design -top xadc_bringup_top -part xc7a100tcsg324-1
opt_design
place_design
route_design

report_utilization -file [file join $report_dir milestone-06-utilization.rpt]
report_timing_summary -file [file join $report_dir milestone-06-timing-summary.rpt]
report_drc -file [file join $report_dir milestone-06-drc.rpt]

write_bitstream -force [file join $output_dir xadc_bringup_top.bit]
quit
