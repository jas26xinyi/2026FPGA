# XSim 回归入口：不传参数时列出全部测试；run_all.ps1 实际上每次只传入一个 testbench。
set project_root [file normalize [file join [file dirname [info script]] ..]]
source [file join $project_root scripts create_project.tcl]
open_project [file join $project_dir password_lock_system.xpr]
set tests {tb_basic_entry_timeout tb_basic_admin_save tb_basic_alarm_policy tb_lock_controller tb_temporary_password_generator tb_alarm_buzzer tb_rpi_camera_link tb_keypad_scanner tb_sevenseg_display tb_flash_default_fail tb_flash_journal}
if {$argc > 0} { set tests [list [lindex $argv 0]] }
foreach tb $tests {
    puts "=== RUNNING $tb ==="
    set_property top $tb [get_filesets sim_1]
    update_compile_order -fileset sim_1
    # 行为仿真不依赖综合/实现结果，适合验证状态机和外设协议功能。
    launch_simulation -simset sim_1 -mode behavioral
    run all
    if {[get_value /$tb/test_pass] ne "1"} { error "$tb failed" }
    # 本机 Vivado 2023.2 在 $finish 后关闭 XSim 可能卡住，因此每个测试使用独立批处理进程。
    exit 0
}
