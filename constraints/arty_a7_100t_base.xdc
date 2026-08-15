# Arty A7-100T 100 MHz oscillator
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} \
    [get_ports clk_100mhz]

create_clock -add -name sys_clk \
    -period 10.000 \
    -waveform {0.000 5.000} \
    [get_ports clk_100mhz]

# BTN0: active-high reset
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} \
    [get_ports reset_btn]

# Top-specific pins are kept in separate XDC files so every constraint names a
# port that actually exists on the selected top module:
#   foundation_top.xdc
#   optical_tx_bringup_top.xdc
#   xadc_bringup_top.xdc
#   capture_uart_bringup_top.xdc
