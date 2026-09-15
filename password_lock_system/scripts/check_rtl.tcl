# 只做 RTL 展开和方法学检查，不运行布局布线；用于快速发现综合语法/结构问题。
set project_root [file normalize [file join [file dirname [info script]] ..]]
file mkdir [file join $project_root reports]
source [file join $project_root scripts create_project.tcl]
open_project [file join $project_dir password_lock_system.xpr]
# -rtl 停在 RTL 级网表，速度远快于完整综合实现。
synth_design -rtl -name rtl_check -top password_lock_top -part xc7a75tfgg484-2
report_methodology -file [file join $project_root reports rtl_methodology.rpt]
close_project
