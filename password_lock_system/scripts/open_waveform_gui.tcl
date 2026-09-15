# 在 Vivado GUI 中打开已生成的 WDB 数据库和 WCFG 显示配置，供截图脚本调用。
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

# 禁止自动加载默认配置，确保使用本次测试配套的 wcfg 信号顺序。
open_wave_database -noautoloadwcfg $wdb
open_wave_config $wcfg
puts "WAVEFORM_READY $wcfg"
