# 03_user_cancel_failure_history：用户取消不清除历史错误次数

窗口：**490–960 ns**，连续绝对时间；scenario=3。

## 原生 Vivado 截屏

![原生 Vivado 分段波形](../images/03_user_cancel_failure_history_native.png)

这是 Vivado 2023.2 的 Wave 面板实际截图，未重绘波形。左侧 Name/Value 列的 Value 是黄色游标位置的瞬时值，不一定是事件发生时的值；请按图中横向时间轴和下表判读。state 编码：0 BOOT、1 WAIT、2 USER、3 ERROR、4 OPEN、5 ADMIN、6 SAVE、7 ALARM、8 TEMP。密码和 key_code 为十六进制 BCD。

## 前置条件

WAIT，密码 1234。

## 当前激励与状态变化

SW1 后输入 1111+A，USER→ERROR，error_count=1；提示时间结束 ERROR→USER，清空输入。输入 2 后 C 使 USER→WAIT，error_count 仍为 1；再次 SW1 后仍为 1，再次 C 退出。取消和重新进入不是报警计数清零手段。

所有事件输入都由测试平台产生一个 10 ns 周期的脉冲。key_valid=1 时 key_code 才是当前新按键；key_valid=0 时保留的 key_code 不是重复激励。next_state 是组合判断，state 在下一上升沿更新；采样后 save_request/capture_start 高一个完整周期。

## 实际端口跳变、采样沿与效果

下表由这次 XSim 的 VCD 数据逐拍反查；`T` ns 的测试平台激励一般在 `clk` 下降沿改变，下一次 `clk` 上升沿在 `T+5` ns 采样。状态/输出用采样后的值，不把 `key_valid` 释放沿误认为第二次按键。表中明确用 0→1 和 1→0 表示端口边沿；若放大窗口中没有新输入边沿，则写明由前序激励或自然计时触发。

| 激励时刻/ns | 输入端口变化 | clk 上升沿/ns | 状态、输出端口实际效果 / 功能 |
| --- | --- | --- | --- |
| 530 | `sw1_event 0→1` | 535 | `state 1:WAIT/PASS→2:USER` |
| 540 | `sw1_event 1→0` | 545 | `state=2:USER` 保持 |
| 550 | `key_valid 0→1`, `key_code A→1` | 555 | `state=2:USER` 保持, `entry_digits 0000→0001`, `entry_count 0→1`, 有效键码 `1` |
| 560 | `key_valid 1→0` | 565 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 570 | `key_valid 0→1` | 575 | `state=2:USER` 保持, `entry_digits 0001→0011`, `entry_count 1→2`, 有效键码 `1` |
| 580 | `key_valid 1→0` | 585 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 590 | `key_valid 0→1` | 595 | `state=2:USER` 保持, `entry_digits 0011→0111`, `entry_count 2→3`, 有效键码 `1` |
| 600 | `key_valid 1→0` | 605 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 610 | `key_valid 0→1` | 615 | `state=2:USER` 保持, `entry_digits 0111→1111`, `entry_count 3→4`, 有效键码 `1` |
| 620 | `key_valid 1→0` | 625 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 630 | `key_valid 0→1`, `key_code 1→A` | 635 | `state 2:USER→3:ERROR`, `error_count 0→1`, 有效键码 `A` |
| 640 | `key_valid 1→0` | 645 | `state=3:ERROR` 保持, 按键有效位释放，不重复提交 |
| 835 | 无新外部脉冲；计时或状态逻辑自然转移 | 835 | `state 3:ERROR→2:USER`, `entry_digits 1111→0000`, `entry_count 4→0` |
| 850 | `key_valid 0→1`, `key_code A→2` | 855 | `state=2:USER` 保持, `entry_digits 0000→0002`, `entry_count 0→1`, 有效键码 `2` |
| 860 | `key_valid 1→0` | 865 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 870 | `key_valid 0→1`, `key_code 2→C` | 875 | `state 2:USER→1:WAIT/PASS`, `entry_digits 0002→0000`, `entry_count 1→0`, 有效键码 `C` |
| 880 | `key_valid 1→0` | 885 | `state=1:WAIT/PASS` 保持, 按键有效位释放，不重复提交 |
| 890 | `sw1_event 0→1` | 895 | `state 1:WAIT/PASS→2:USER` |
| 900 | `sw1_event 1→0` | 905 | `state=2:USER` 保持 |
| 910 | `key_valid 0→1` | 915 | `state 2:USER→1:WAIT/PASS`, 有效键码 `C` |
| 920 | `key_valid 1→0` | 925 | `state=1:WAIT/PASS` 保持, 按键有效位释放，不重复提交 |

窗口起点：`rst=0`, `flash_init_done=1`, `sw1_event=0`, `admin_event=0`, `alarm_clear_event=0`, `temporary_event=0`, `key_valid=0`, `key_code=A`, `save_done=0`, `save_success=0`, `stored_password=1234`, `temporary_password=0000`, `temporary_valid=0`, `flash_fault=0`。

## 对应实际功能

SW1 后输入 1111+A，USER→ERROR，error_count=1；提示时间结束 ERROR→USER，清空输入。输入 2 后 C 使 USER→WAIT，error_count 仍为 1；再次 SW1 后仍为 1，再次 C 退出。取消和重新进入不是报警计数清零手段。

## 再次打开与分段截屏

配置：[WCFG](../configs/03_user_cancel_failure_history.wcfg)，完整数据：[WDB](../tb_lock_controller_fsm.wdb)、[VCD](../tb_lock_controller_fsm.vcd)。

在 Vivado Tcl Console 执行（将路径替换为本地仓库路径）：

```tcl
open_wave_database -noautoloadwcfg E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/tb_lock_controller_fsm.wdb
open_wave_config E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/configs/03_user_cancel_failure_history.wcfg
# 时间窗口已内嵌在 WCFG；打开配置即恢复对应分段。
```
