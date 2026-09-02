set project_root [file normalize [file join [file dirname [info script]] ..]]
set project_dir  [file join $project_root vivado]
file mkdir $project_dir
create_project -force password_lock_system $project_dir -part xc7a75tfgg484-2
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -norecurse [glob -directory [file join $project_root rtl] *.v]
set dvi_dir [file join $project_root third_party rgb2dvi src]
foreach source {DVI_Constants.vhd SyncAsync.vhd SyncAsyncReset.vhd ClockGen.vhd TMDS_Encoder.vhd OutputSERDES.vhd rgb2dvi.vhd} {
    add_files -norecurse [file join $dvi_dir $source]
}
add_files -fileset constrs_1 -norecurse [file join $project_root constraints password_lock_system.xdc]
set camera_override [file join $project_root constraints camera_clock_override.xdc]
add_files -fileset constrs_1 -norecurse $camera_override
set_property USED_IN_SYNTHESIS false [get_files $camera_override]
set_property top password_lock_top [get_filesets sources_1]
update_compile_order -fileset sources_1
close_project
puts "Created [file join $project_dir password_lock_system.xpr]"
