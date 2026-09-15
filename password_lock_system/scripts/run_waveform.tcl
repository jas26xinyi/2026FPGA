# 单个测试的波形导出入口：生成 VCD、Vivado WDB/WCFG 和包含 PASS 元数据的 result.txt。
if {$argc < 3} {
    error "usage: run_waveform.tcl <testbench> <output-directory> <comma-separated-signals>"
}

set tb [lindex $argv 0]
set output_dir [file normalize [lindex $argv 1]]
set requested_signals [split [join [lrange $argv 2 end] ","] ","]
file mkdir $output_dir

set project_root [file normalize [file join [file dirname [info script]] ..]]
source [file join $project_root scripts create_project.tcl]
open_project [file join $project_dir password_lock_system.xpr]
set_property top $tb [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "=== WAVEFORM RUN $tb ==="
launch_simulation -simset sim_1 -mode behavioral

# 记录 testbench 层级全部对象到数据库/VCD，但 GUI 配置只显示调用者指定的关键信号。
set sim_objects [get_objects -r /$tb/*]
log_wave -quiet $sim_objects
open_vcd [file join $output_dir "$tb.vcd"]
log_vcd -quiet $sim_objects

if {[llength [get_wave_configs]] == 0} {
    create_wave_config
}
set existing_waves [get_waves -quiet -of [current_wave_config] *]
if {[llength $existing_waves] > 0} {
    remove_wave -quiet $existing_waves
}
set display_signals {}
# test_pass 与 clk 强制加入显示列表，其余名称来自 generate_waveforms.ps1 的 Signals 字段。
foreach signal [concat {test_pass clk} $requested_signals] {
    set object [get_objects -quiet "/$tb/$signal"]
    if {[llength $object] > 0 && [lsearch -exact $display_signals $object] < 0} {
        lappend display_signals $object
    }
}
if {[llength $display_signals] == 0} {
    error "No requested display signals were found for $tb"
}
add_wave -quiet $display_signals
save_wave_config [file join $output_dir "$tb.wcfg"]

run all
flush_vcd
close_vcd

if {[get_value /$tb/test_pass] ne "1"} {
    error "$tb failed"
}

# 必须先 close_sim 刷新行为仿真 WDB，否则可能复制到只含 0 ns 初态的小数据库。
close_sim

set xsim_dir [file join $project_dir password_lock_system.sim sim_1 behav xsim]
set behavior_wdb [file join $xsim_dir "${tb}_behav.wdb"]
if {![file exists $behavior_wdb]} {
    error "Vivado did not create the behavioral WDB for $tb: $behavior_wdb"
}
# 固定发布完整的 *_behav.wdb，而不是保存波形配置时临时生成的 <testbench>.wdb。
file copy -force $behavior_wdb [file join $output_dir "$tb.wdb"]

set result [open [file join $output_dir result.txt] w]
puts $result "PASS"
puts $result "testbench=$tb"
puts $result "simulator=Vivado XSim 2023.2"
puts $result "vcd=[file join $output_dir $tb.vcd]"
puts $result "wdb=[file join $output_dir $tb.wdb]"
close $result

puts "PASS WAVEFORM $tb"
exit 0
