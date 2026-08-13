# Milestone 05 optical_tx_bringup_top
# Arty A7-100 Rev. D/E, xc7a100tcsg324-1
#
# Physical control mapping:
#   SW0 -> tx_enable
#   SW1 -> mode[0] (least-significant mode bit)
#   SW2 -> mode[1] (most-significant mode bit)
#
# Read the mode using the physical switches in the order {SW2, SW1}:
#
#   SW2 SW1   mode[1:0]   Transmitter output
#    0   0       00       OFF      - constant 0
#    0   1       01       ON       - constant 1
#    1   0       10       TRAINING - alternating 1, 0, 1, 0...
#    1   1       11       FRAMED   - preamble, sync, sequence, PRBS payload
#
# SW0 is independent of mode. When SW0 is low, laser_output_guard forces
# laser_drive low regardless of SW2/SW1.

# SW0: final transmitter-output permission
set_property -dict {PACKAGE_PIN A8 IOSTANDARD LVCMOS33} \
    [get_ports tx_enable]

# SW1: least-significant mode bit
set_property -dict {PACKAGE_PIN C11 IOSTANDARD LVCMOS33} \
    [get_ports {mode[0]}]

# SW2: most-significant mode bit
set_property -dict {PACKAGE_PIN C10 IOSTANDARD LVCMOS33} \
    [get_ports {mode[1]}]

# LD5: live blocked-request indication from laser_output_guard
# The LED lights when tx_bit requests ON while SW0 is low and reset is inactive.
set_property -dict {PACKAGE_PIN J5 IOSTANDARD LVCMOS33} \
    [get_ports fault]

# Pmod JA physical pin 4: KY-008 S control input
#
# Digilent's master XDC calls physical JA4 "ja[3]" because its vectors are
# zero-based. On the Arty A7-100 Rev. D/E, physical JA4 maps to FPGA pin D12.
# JA5 is GND and JA6 is 3.3 V. They are fixed power pins, not FPGA signals, so
# they do not receive XDC constraints.
set_property -dict {PACKAGE_PIN D12 IOSTANDARD LVCMOS33 DRIVE 4 SLEW SLOW} \
    [get_ports laser_drive]

# Pmod JA physical pin 1: DAOKI digital-receiver diagnostic input
# Do not connect this signal until the receiver's illuminated high voltage has
# been measured at or translated to a safe 3.3 V FPGA input level.
set_property -dict {PACKAGE_PIN G13 IOSTANDARD LVCMOS33} \
    [get_ports daoki_rx_async]

# LD6: synchronized DAOKI digital-receiver diagnostic state
set_property -dict {PACKAGE_PIN T9 IOSTANDARD LVCMOS33} \
    [get_ports daoki_rx_led]
