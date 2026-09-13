if {$argc != 2} {
    error "usage: open_waveform_gui.tcl <wdb> <wcfg>"
}

set wdb [file normalize [lindex $argv 0]]
set wcfg [file normalize [lindex $argv 1]]

if {![file exists $wdb]} {
    error "waveform database not found: $wdb"
}
if {![file exists $wcfg]} {
    error "waveform configuration not found: $wcfg"
}

open_wave_database -noautoloadwcfg $wdb
open_wave_config $wcfg
puts "WAVEFORM_READY $wcfg"
