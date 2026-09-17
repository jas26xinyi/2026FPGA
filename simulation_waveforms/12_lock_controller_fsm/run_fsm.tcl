# Self-contained project: never touches the user's production XPR.
set here [file normalize [file dirname [info script]]]
set repo [file normalize [file join $here .. ..]]
set project_dir [file join $repo tmp lock_controller_fsm_project]
create_project -force lock_controller_fsm $project_dir -part xc7a75tfgg484-2
add_files -norecurse [file join $repo password_lock_system rtl lock_controller.v]
add_files -fileset sim_1 -norecurse [file join $here tb_lock_controller_fsm.sv]
set_property top tb_lock_controller_fsm [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation -mode behavioral
log_wave -r /tb_lock_controller_fsm/*
open_vcd [file join $here tb_lock_controller_fsm.vcd]
log_vcd [get_objects -r /tb_lock_controller_fsm/*]
run all
flush_vcd
close_vcd
if {[get_value /tb_lock_controller_fsm/test_pass] ne "1"} {error "FSM regression failed"}
close_sim
set simdir [file join $project_dir lock_controller_fsm.sim sim_1 behav xsim]
file copy -force [file join $simdir tb_lock_controller_fsm_behav.wdb] [file join $here tb_lock_controller_fsm.wdb]
foreach artifact {segments.csv transitions.csv coverage.txt} {
    file copy -force [file join $simdir $artifact] [file join $here $artifact]
}
puts "PASS: FSM waveform database and coverage exported"
exit 0
