# Milestone 08 bpw34_characterization_top
# Arty A7-100 Rev. D/E, xc7a100tcsg324-1
#
# Transmitter controls:
#   SW0 enables the laser output.
#   {SW2, SW1}: 00=OFF, 01=ON, 10=TRAINING, 11=FRAMED.
#   SW3: 0=1 kbit/s, 1=10 kbit/s. Change rate while SW0 is off.
#
# Capture controls:
#   BTN1 arms an empty capture and BTN2 triggers it.

set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} \
    [get_ports tx_enable]
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} \
    [get_ports {mode[0]}]
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} \
    [get_ports {mode[1]}]
set_property -dict {PACKAGE_PIN A10 IOSTANDARD LVCMOS33} \
    [get_ports rate_10k]

set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} \
    [get_ports arm_btn]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} \
    [get_ports trigger_btn]

# ChipKit A0 is one physical 0-3.3 V input. The two ports below are
# the internal VAUX4 pair after the Arty analog scaling network.
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_p]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_n]

# Arty USB-UART FPGA transmit output.
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} \
    [get_ports uart_tx_out]

# KY-008 S input on physical JA4. JA5 is ground and the middle module pin
# remains unconnected for the delivered variant.
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} \
    [get_ports laser_drive]

# Capture status LEDs retain the Milestone 07 meanings.
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} \
    [get_ports capture_armed_led]
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} \
    [get_ports capture_busy_led]
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} \
    [get_ports capture_done_led]
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} \
    [get_ports capture_fault_led]

