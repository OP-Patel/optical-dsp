# Program exactly one attached FPGA whose part matches the declared pattern.
#
# Intended invocation (normally through fpga.ps1):
#   vivado -mode batch -source program_device.tcl \
#     -tclargs <bitstream.bit> <expected-part-glob>


# Vivado Executable: C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat
# Program Path: .\scripts\fpga.cmd program -Bitstream "C:\path\to\actual.bit" -DryRun

if {$argc < 1 || $argc > 2} {
    error "Usage: program_device.tcl <bitstream.bit> ?expected-part-glob?"
}

set bitstream [file normalize [lindex $argv 0]]
set expected_part "*xc7a100t*"
if {$argc == 2} {
    set expected_part [lindex $argv 1]
}

if {![file exists $bitstream] || ![file isfile $bitstream]} {
    error "Bitstream does not exist: $bitstream"
}
if {![string equal -nocase [file extension $bitstream] ".bit"]} {
    error "Expected a .bit file: $bitstream"
}

set manager_open 0
set target_open 0
set failure_message ""

if {[catch {
    open_hw_manager
    set manager_open 1
    connect_hw_server
    open_hw_target
    set target_open 1

    set matching_devices {}
    foreach device [get_hw_devices -quiet] {
        set part [get_property PART $device]
        if {[string match -nocase $expected_part $part]} {
            lappend matching_devices $device
        }
    }

    if {[llength $matching_devices] != 1} {
        set all_devices [get_hw_devices -quiet]
        error "Expected exactly one device matching '$expected_part'; found [llength $matching_devices]. Attached devices: $all_devices"
    }

    set device [lindex $matching_devices 0]
    set part [get_property PART $device]
    puts "PROGRAM_DEVICE=$device"
    puts "PROGRAM_PART=$part"
    puts "PROGRAM_FILE=$bitstream"

    current_hw_device $device
    refresh_hw_device -update_hw_probes false $device
    set_property PROGRAM.FILE $bitstream $device
    set_property PROBES.FILE {} $device
    program_hw_devices $device
    refresh_hw_device -update_hw_probes false $device

    puts "CONFIG_STATUS=[get_property REGISTER.CONFIG_STATUS $device]"
    puts "PROGRAM_RESULT=SUCCESS"
} failure_message]} {
    puts stderr "PROGRAM_RESULT=FAILURE"
    puts stderr $failure_message
}

if {$target_open} {
    catch {close_hw_target}
}
if {$manager_open} {
    catch {disconnect_hw_server}
    catch {close_hw_manager}
}

if {$failure_message ne ""} {
    error $failure_message
}
