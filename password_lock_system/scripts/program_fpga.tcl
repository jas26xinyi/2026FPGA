set project_root [file normalize [file join [file dirname [info script]] ..]]
set bit_file [file join $project_root password_lock_top.bit]
if {![file exists $bit_file]} {
    error "Bitstream not found: $bit_file"
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set target_device ""
foreach device [get_hw_devices] {
    set part_name [string tolower [get_property PART $device]]
    if {[string match "xc7a75t*" $part_name]} {
        set target_device $device
        break
    }
}
if {$target_device eq ""} {
    error "No XC7A75T device was found on the JTAG chain"
}

current_hw_device $target_device
refresh_hw_device -update_hw_probes false $target_device
set_property PROGRAM.FILE $bit_file $target_device
program_hw_devices $target_device
refresh_hw_device -update_hw_probes false $target_device
puts "PROGRAMMED_DEVICE=[get_property PART $target_device]"
puts "PROGRAMMED_BITSTREAM=$bit_file"

close_hw_target
disconnect_hw_server
close_hw_manager
