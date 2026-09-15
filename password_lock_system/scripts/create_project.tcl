# 从脚本位置计算工程根目录；VIVADO_PROJECT_DIR 可把临时工程输出重定向到别处。
set project_root [file normalize [file join [file dirname [info script]] ..]]
set project_dir  [file join $project_root vivado]
if {[info exists ::env(VIVADO_PROJECT_DIR)]} {
    set project_dir [file normalize $::env(VIVADO_PROJECT_DIR)]
}
file mkdir $project_dir
create_project -force password_lock_system $project_dir -part xc7a75tfgg484-2
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# 默认综合树莓派 UART 拍照功能；环境变量 ENABLE_RPI_CAMERA=0 可只综合密码锁核心。
set enable_rpi_camera 1
if {[info exists ::env(ENABLE_RPI_CAMERA)]} {
    set enable_rpi_camera $::env(ENABLE_RPI_CAMERA)
}
if {$enable_rpi_camera ni {0 1}} {
    error "ENABLE_RPI_CAMERA must be 0 or 1"
}

# 分别加入 RTL、约束和 SystemVerilog 仿真源，并指定综合顶层与可配置参数。
add_files -norecurse [glob -directory [file join $project_root rtl] *.v]
add_files -fileset constrs_1 -norecurse [file join $project_root constraints password_lock_system.xdc]
add_files -fileset sim_1 -norecurse [glob -directory [file join $project_root sim] *.sv]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
set_property top password_lock_top [get_filesets sources_1]
set_property generic "ENABLE_RPI_CAMERA=$enable_rpi_camera" [get_filesets sources_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
close_project
puts "Created [file join $project_dir password_lock_system.xpr] (ENABLE_RPI_CAMERA=$enable_rpi_camera)"
