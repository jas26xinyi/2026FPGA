set project_root [file normalize [file join [file dirname [info script]] ..]]
file mkdir [file join $project_root reports]
source [file join $project_root scripts create_project.tcl]
open_project [file join $project_dir password_lock_system.xpr]
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "Synthesis failed" }
open_run synth_1
report_utilization -file [file join $project_root reports post_synth_utilization.rpt]
report_cdc -details -file [file join $project_root reports post_synth_cdc.rpt]
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "Implementation failed" }
open_run impl_1
report_timing_summary -file [file join $project_root reports timing_summary.rpt]
report_utilization -file [file join $project_root reports utilization.rpt]
report_drc -file [file join $project_root reports drc.rpt]
report_cdc -details -file [file join $project_root reports cdc.rpt]
file copy -force [get_property DIRECTORY [get_runs impl_1]]/password_lock_top.bit [file join $project_root password_lock_top.bit]
close_project
