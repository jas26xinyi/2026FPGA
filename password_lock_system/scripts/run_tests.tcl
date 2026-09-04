set project_root [file normalize [file join [file dirname [info script]] ..]]
source [file join $project_root scripts create_project.tcl]
open_project [file join $project_dir password_lock_system.xpr]
add_files -fileset sim_1 -norecurse [glob -directory [file join $project_root sim] *.sv]
set_property file_type SystemVerilog [get_files -of_objects [get_filesets sim_1] *.sv]
set tests {tb_lock_controller tb_alarm_buzzer tb_keypad_scanner tb_sevenseg_display tb_frame_capture tb_mosaic_renderer tb_flash_default_fail tb_flash_journal}
if {$argc > 0} { set tests [list [lindex $argv 0]] }
foreach tb $tests {
    puts "=== RUNNING $tb ==="
    set_property top $tb [get_filesets sim_1]
    update_compile_order -fileset sim_1
    launch_simulation -simset sim_1 -mode behavioral
    run all
    if {[get_value /$tb/test_pass] ne "1"} { error "$tb failed" }
    # Vivado 2023.2 on this Windows host can hang while closing XSim after
    # $finish. Each test is therefore run in its own batch process.
    exit 0
}
