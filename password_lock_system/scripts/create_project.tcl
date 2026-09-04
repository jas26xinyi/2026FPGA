set project_root [file normalize [file join [file dirname [info script]] ..]]
set project_dir  [file join $project_root vivado]
if {[info exists ::env(VIVADO_PROJECT_DIR)]} {
    set project_dir [file normalize $::env(VIVADO_PROJECT_DIR)]
}
file mkdir $project_dir
create_project -force password_lock_system $project_dir -part xc7a75tfgg484-2
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# The Raspberry Pi UART camera trigger is enabled by default. Set the process
# environment variable ENABLE_RPI_CAMERA=0 to synthesize the core lock alone.
set enable_rpi_camera 1
if {[info exists ::env(ENABLE_RPI_CAMERA)]} {
    set enable_rpi_camera $::env(ENABLE_RPI_CAMERA)
}
if {$enable_rpi_camera ni {0 1}} {
    error "ENABLE_RPI_CAMERA must be 0 or 1"
}

add_files -norecurse [glob -directory [file join $project_root rtl] *.v]
add_files -fileset constrs_1 -norecurse [file join $project_root constraints password_lock_system.xdc]
set_property top password_lock_top [get_filesets sources_1]
set_property generic "ENABLE_RPI_CAMERA=$enable_rpi_camera" [get_filesets sources_1]
update_compile_order -fileset sources_1
close_project
puts "Created [file join $project_dir password_lock_system.xpr] (ENABLE_RPI_CAMERA=$enable_rpi_camera)"
