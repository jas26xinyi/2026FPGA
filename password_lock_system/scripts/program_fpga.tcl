# 通过 JTAG 把 password_lock_top.bit 下载到 FPGA SRAM；断电后会丢失。
set project_root [file normalize [file join [file dirname [info script]] ..]]
set bit_file [file join $project_root password_lock_top.bit]
if {![file exists $bit_file]} {
    error "Bitstream not found: $bit_file"
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

# 遍历 JTAG 链并只选择 XC7A75T，避免误编程同链路其他器件。
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
# PROGRAM.FILE 指定本次位流，program_hw_devices 执行实际下载。
set_property PROGRAM.FILE $bit_file $target_device
program_hw_devices $target_device
refresh_hw_device -update_hw_probes false $target_device
puts "PROGRAMMED_DEVICE=[get_property PART $target_device]"
puts "PROGRAMMED_BITSTREAM=$bit_file"

close_hw_target
disconnect_hw_server
close_hw_manager
