set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
cd $repo_dir

file mkdir artifacts/reports

read_verilog -sv [list \
    rtl/common/prbs15_gen.sv \
    rtl/tx/optical_framer.sv]

synth_design -top optical_framer -part xc7a100tcsg324-1
report_utilization -file artifacts/reports/milestone-04-utilization.rpt
report_timing_summary -file artifacts/reports/milestone-04-timing-summary.rpt
report_drc -file artifacts/reports/milestone-04-drc.rpt
write_checkpoint -force artifacts/reports/milestone-04-synth.dcp
quit
