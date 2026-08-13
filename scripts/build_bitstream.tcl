set script_dir [file dirname [file normalize [info script]]]
set repo_dir   [file dirname $script_dir]

# Keep paths passed into Vivado relative. Some Vivado commands reparse absolute
# Windows paths as lists and mishandle spaces in directory names.
cd $repo_dir

set rtl_dir         rtl
set constraints_dir constraints
set output_dir      [file join artifacts bitstreams]
set report_dir      [file join artifacts reports]

file mkdir $output_dir
file mkdir $report_dir

set rtl_sources [list \
    [file join $rtl_dir common reset_sync.sv] \
    [file join $rtl_dir common clock_enable_gen.sv] \
    [file join $rtl_dir common heartbeat.sv] \
    [file join $rtl_dir top foundation_top.sv]]

# Vivado treats the positional read_verilog argument as a Tcl list. Building
# that list explicitly preserves repository paths containing spaces.
read_verilog -sv $rtl_sources

read_xdc [list \
    [file join $constraints_dir arty_a7_100t_base.xdc] \
    [file join $constraints_dir foundation_top.xdc]]

synth_design \
    -top foundation_top \
    -part xc7a100tcsg324-1

opt_design
place_design
route_design

report_utilization \
    -file [file join $report_dir utilization.rpt]

report_timing_summary \
    -file [file join $report_dir timing_summary.rpt]

write_bitstream -force \
    [file join $output_dir optical_dsp_top.bit]
