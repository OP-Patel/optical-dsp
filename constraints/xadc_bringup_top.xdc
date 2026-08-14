# Milestone 06 xadc_bringup_top
# Arty A7-100 Rev. D/E, xc7a100tcsg324-1

# ChipKit A0 through the board's single-ended 0-3.3 V scaling network.
# The A0 header is one physical voltage input referenced to board ground. These
# are the two internal VAUX4 nodes after the Arty resistor network.
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_p]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_n]

# LD4: at least one sample was accepted since reset
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} \
    [get_ports sample_seen_led]

# LD5: toggles every 65,536 accepted samples
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} \
    [get_ports sample_activity_led]

# LD6: sticky DRP timeout, overrun, or unexpected-response fault
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} \
    [get_ports xadc_fault_led]

# LD7: latest sample is at or above half scale
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} \
    [get_ports sample_level_led]
