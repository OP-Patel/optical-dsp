set script_dir [file dirname [file normalize [info script]]]
set repo_dir [file dirname $script_dir]
cd $repo_dir

set report_dir [file join artifacts reports]
file mkdir $report_dir

foreach tap_count {8 16} {
    read_verilog -sv [list \
        rtl/common/reset_sync.sv \
        rtl/dsp/fir_coefficients.sv \
        rtl/dsp/round_saturate.sv \
        rtl/dsp/fir_filter.sv \
        rtl/top/fir_variant_benchmark_top.sv]

    read_xdc [list \
        constraints/arty_a7_100t_base.xdc \
        constraints/fir_variant_benchmark_top.xdc]

    synth_design \
        -top fir_variant_benchmark_top \
        -part xc7a100tcsg324-1 \
        -generic TAPS=$tap_count

    opt_design
    place_design
    route_design

    report_utilization \
        -file [file join $report_dir milestone-10-fir${tap_count}-utilization.rpt]
    report_timing_summary \
        -file [file join $report_dir milestone-10-fir${tap_count}-timing-summary.rpt]

    close_design
}

quit
