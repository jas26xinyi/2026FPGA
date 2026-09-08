if {$argc < 2} {
    error "usage: run_waveform.tcl <testbench> <output-directory>"
}

set tb [lindex $argv 0]
set output_dir [file normalize [lindex $argv 1]]
file mkdir $output_dir

set project_root [file normalize [file join [file dirname [info script]] ..]]
source [file join $project_root scripts create_project.tcl]
open_project [file join $project_dir password_lock_system.xpr]
set_property top $tb [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "=== WAVEFORM RUN $tb ==="
launch_simulation -simset sim_1 -mode behavioral

set sim_objects [get_objects -r /$tb/*]
log_wave -quiet $sim_objects
open_vcd [file join $output_dir "$tb.vcd"]
log_vcd -quiet $sim_objects

if {[llength [get_wave_configs]] == 0} {
    create_wave_config
}
add_wave -quiet $sim_objects
save_wave_config [file join $output_dir "$tb.wcfg"]

run all
flush_vcd
close_vcd

if {[get_value /$tb/test_pass] ne "1"} {
    error "$tb failed"
}

set xsim_dir [file join $project_dir password_lock_system.sim sim_1 behav xsim]
set wdb_files [glob -nocomplain -directory $xsim_dir *.wdb]
if {[llength $wdb_files] == 0} {
    error "Vivado did not create a WDB for $tb"
}
file copy -force [lindex $wdb_files 0] [file join $output_dir "$tb.wdb"]

set result [open [file join $output_dir result.txt] w]
puts $result "PASS"
puts $result "testbench=$tb"
puts $result "simulator=Vivado XSim 2023.2"
puts $result "vcd=[file join $output_dir $tb.vcd]"
puts $result "wdb=[file join $output_dir $tb.wdb]"
close $result

puts "PASS WAVEFORM $tb"
exit 0
