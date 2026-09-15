# 将 bitstream 转为 MCS 并写入板载配置 Flash，使 FPGA 断电重启后能自动加载。
# 这是 FPGA 配置存储器，不是 RTL 中保存用户密码的 W25Q64 双扇区。
set project_root [file normalize [file join [file dirname [info script]] ..]]
set bit_file [file join $project_root password_lock_top.bit]
set mcs_file [file join $project_root password_lock_top_boot.mcs]
set prm_file [file join $project_root password_lock_top_boot.prm]
set cfgmem_name mt25ql128-spi-x1_x2_x4

if {![file exists $bit_file]} {
    error "Bitstream not found: $bit_file"
}

# 实测配置器件由 Vivado 识别为 mt25ql128；选择兼容性更好的 SPI x1。
# write_cfgmem 的 size 单位为 MB：128 Mbit=16 MB。
write_cfgmem -force -format mcs -size 16 -interface SPIx1 \
    -loadbit "up 0x00000000 $bit_file" -file $mcs_file

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

# 先锁定 XC7A75T，再为它创建间接配置存储器对象。
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

set cfgmem_part [lindex [get_cfgmem_parts -quiet $cfgmem_name] 0]
if {$cfgmem_part eq ""} {
    error "Vivado cfgmem part not found: $cfgmem_name"
}

current_hw_device $target_device
refresh_hw_device -update_hw_probes false $target_device
create_hw_cfgmem -hw_device $target_device $cfgmem_part
set hw_cfgmem [get_property PROGRAM.HW_CFGMEM $target_device]

# 执行空白检查、擦除、编程和回读校验，任一步失败都会由 Vivado 报错。
set_property PROGRAM.ADDRESS_RANGE {use_file} $hw_cfgmem
set_property PROGRAM.FILES [list $mcs_file] $hw_cfgmem
set_property PROGRAM.PRM_FILE $prm_file $hw_cfgmem
set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $hw_cfgmem
set_property PROGRAM.BLANK_CHECK 1 $hw_cfgmem
set_property PROGRAM.ERASE 1 $hw_cfgmem
set_property PROGRAM.CFG_PROGRAM 1 $hw_cfgmem
set_property PROGRAM.VERIFY 1 $hw_cfgmem
set_property PROGRAM.CHECKSUM 0 $hw_cfgmem

# 先加载 Vivado 的间接访问位流，FPGA 才能充当 JTAG 到配置 Flash 的桥接器。
create_hw_bitstream -hw_device $target_device \
    [get_property PROGRAM.HW_CFGMEM_BITFILE $target_device]
program_hw_devices $target_device

program_hw_cfgmem -hw_cfgmem $hw_cfgmem
puts "CFGMEM_PROGRAMMED_DEVICE=[get_property PART $target_device]"
puts "CFGMEM_PROGRAMMED_PART=$cfgmem_name"
puts "CFGMEM_PROGRAMMED_FILE=$mcs_file"

# 从新写入的配置 Flash 触发重配置，并打印器件状态供人工确认 DONE。
boot_hw_device $target_device
after 3000
refresh_hw_device -update_hw_probes false $target_device
report_property $target_device
foreach prop [list_property $target_device] {
    if {[string match -nocase *STATUS* $prop]} {
        puts "BOOT_PROPERTY:$prop=[get_property $prop $target_device]"
    }
}

close_hw_target
disconnect_hw_server
close_hw_manager
