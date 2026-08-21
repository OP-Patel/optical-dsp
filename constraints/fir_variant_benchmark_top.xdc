# Milestone 10 8/16-tap routed benchmark wrapper.
# The board clock/reset come from arty_a7_100t_base.xdc.

set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} \
    [get_ports filter_activity_led]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} \
    [get_ports filter_saturation_led]
