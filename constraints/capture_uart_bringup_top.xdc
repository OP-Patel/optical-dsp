# Milestone 07 capture_uart_bringup_top
# Arty A7-100 Rev. D/E, xc7a100tcsg324-1

# BTN1 arms an empty capture. BTN2 triggers the armed capture.
set_property -dict {PACKAGE_PIN C9 IOSTANDARD LVCMOS33} \
    [get_ports arm_btn]
set_property -dict {PACKAGE_PIN B9 IOSTANDARD LVCMOS33} \
    [get_ports trigger_btn]

# ChipKit A0 through the board's single-ended 0-3.3 V scaling network.
set_property -dict {PACKAGE_PIN C6 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_p]
set_property -dict {PACKAGE_PIN C5 IOSTANDARD LVCMOS33} \
    [get_ports vaux4_n]

# Arty USB-UART: FPGA output to the USB bridge receiver.
set_property -dict {PACKAGE_PIN D10 IOSTANDARD LVCMOS33} \
    [get_ports uart_tx_out]

# LD4: capture is armed and waiting for BTN2.
set_property -dict {PACKAGE_PIN H5 IOSTANDARD LVCMOS33} \
    [get_ports capture_armed_led]

# LD5: capture buffer is accepting full-rate XADC samples.
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} \
    [get_ports capture_busy_led]

# LD6: buffer is frozen and its packet is ready/being sent.
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} \
    [get_ports capture_done_led]

# LD7: XADC, control, capture, or packet error.
set_property -dict {PACKAGE_PIN T10 IOSTANDARD LVCMOS33} \
    [get_ports capture_fault_led]
