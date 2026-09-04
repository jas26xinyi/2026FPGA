set project_root [file normalize [file join [file dirname [info script]] ..]]
set project_dir  [file join $project_root vivado]
if {[info exists ::env(VIVADO_PROJECT_DIR)]} {
    set project_dir [file normalize $::env(VIVADO_PROJECT_DIR)]
}
file mkdir $project_dir
create_project -force password_lock_system $project_dir -part xc7a75tfgg484-2
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# Default to the keypad-first build. Set the process environment variable
# ENABLE_CAMERA=1 before running this script to include the OV5640 path.
set enable_camera 0
if {[info exists ::env(ENABLE_CAMERA)]} {
    set enable_camera $::env(ENABLE_CAMERA)
}
if {$enable_camera ni {0 1}} {
    error "ENABLE_CAMERA must be 0 or 1"
}

add_files -norecurse [glob -directory [file join $project_root rtl] *.v]
set dvi_dir [file join $project_root third_party rgb2dvi src]
foreach source {DVI_Constants.vhd SyncAsync.vhd SyncAsyncReset.vhd ClockGen.vhd TMDS_Encoder.vhd OutputSERDES.vhd rgb2dvi.vhd} {
    add_files -norecurse [file join $dvi_dir $source]
}
add_files -fileset constrs_1 -norecurse [file join $project_root constraints password_lock_system.xdc]
if {$enable_camera == 1} {
    add_files -fileset constrs_1 -norecurse [file join $project_root constraints camera_timing.xdc]
    set camera_override [file join $project_root constraints camera_clock_override.xdc]
    add_files -fileset constrs_1 -norecurse $camera_override
    set_property USED_IN_SYNTHESIS false [get_files $camera_override]
}
set_property top password_lock_top [get_filesets sources_1]
set_property generic "ENABLE_CAMERA=$enable_camera" [get_filesets sources_1]
update_compile_order -fileset sources_1
close_project
puts "Created [file join $project_dir password_lock_system.xpr] (ENABLE_CAMERA=$enable_camera)"
