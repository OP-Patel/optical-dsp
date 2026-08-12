# Arty A7-100T 100 MHz oscillator
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} \
    [get_ports clk_100mhz]

create_clock -add -name sys_clk \
    -period 10.000 \
    -waveform {0.000 5.000} \
    [get_ports clk_100mhz]

# BTN0: active-high reset
set_property -dict {PACKAGE_PIN D9 IOSTANDARD LVCMOS33} \
    [get_ports reset_btn]

# LD4: first standard single-color LED
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} \
    [get_ports heartbeat_led]