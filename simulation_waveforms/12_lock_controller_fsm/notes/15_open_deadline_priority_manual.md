# 15_open_deadline_priority_manual：A 与 KEY1 同拍：主动关锁优先

窗口：**74760–74990 ns**，连续绝对时间；scenario=15。

## 原生 Vivado 截屏

![原生 Vivado 分段波形](../images/15_open_deadline_priority_manual_native.png)

这是 Vivado 2023.2 的 Wave 面板实际截图，未重绘波形。左侧 Name/Value 列的 Value 是黄色游标位置的瞬时值，不一定是事件发生时的值；请按图中横向时间轴和下表判读。state 编码：0 BOOT、1 WAIT、2 USER、3 ERROR、4 OPEN、5 ADMIN、6 SAVE、7 ALARM、8 TEMP。密码和 key_code 为十六进制 BCD。

## 前置条件

同主题的第二次成功开锁，随后 A 与 KEY1 同拍。

## 当前激励与状态变化

成功开锁后自然等待，在 timer_count=1999 时同时送数字 1 和 KEY1：OPEN 的超时条件不检查 !activity，故仍 OPEN→WAIT，而不是留在 OPEN 或进入 ADMIN。再次成功开锁后，A 与 KEY1 同拍，主动关锁条件优先，仍 OPEN→WAIT。分别有期限边界与 A/KEY1 放大图。

所有事件输入都由测试平台产生一个 10 ns 周期的脉冲。key_valid=1 时 key_code 才是当前新按键；key_valid=0 时保留的 key_code 不是重复激励。next_state 是组合判断，state 在下一上升沿更新；采样后 save_request/capture_start 高一个完整周期。

## 实际端口跳变、采样沿与效果

下表由这次 XSim 的 VCD 数据逐拍反查；`T` ns 的测试平台激励一般在 `clk` 下降沿改变，下一次 `clk` 上升沿在 `T+5` ns 采样。状态/输出用采样后的值，不把 `key_valid` 释放沿误认为第二次按键。表中明确用 0→1 和 1→0 表示端口边沿；若放大窗口中没有新输入边沿，则写明由前序激励或自然计时触发。

| 激励时刻/ns | 输入端口变化 | clk 上升沿/ns | 状态、输出端口实际效果 / 功能 |
| --- | --- | --- | --- |
| 74800 | `admin_event 0→1`, `key_valid 0→1`, `key_code A→1` | 74805 | `state 4:OPEN→1:WAIT/PASS`, `entry_digits 1234→0000`, `entry_count 4→0`, `unlocked 1→0`, 有效键码 `1` |
| 74810 | `admin_event 1→0`, `key_valid 1→0` | 74815 | `state=1:WAIT/PASS` 保持, 按键有效位释放，不重复提交 |
| 74820 | `sw1_event 0→1` | 74825 | `state 1:WAIT/PASS→2:USER` |
| 74830 | `sw1_event 1→0` | 74835 | `state=2:USER` 保持 |
| 74840 | `key_valid 0→1` | 74845 | `state=2:USER` 保持, `entry_digits 0000→0001`, `entry_count 0→1`, 有效键码 `1` |
| 74850 | `key_valid 1→0` | 74855 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 74860 | `key_valid 0→1`, `key_code 1→2` | 74865 | `state=2:USER` 保持, `entry_digits 0001→0012`, `entry_count 1→2`, 有效键码 `2` |
| 74870 | `key_valid 1→0` | 74875 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 74880 | `key_valid 0→1`, `key_code 2→3` | 74885 | `state=2:USER` 保持, `entry_digits 0012→0123`, `entry_count 2→3`, 有效键码 `3` |
| 74890 | `key_valid 1→0` | 74895 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 74900 | `key_valid 0→1`, `key_code 3→4` | 74905 | `state=2:USER` 保持, `entry_digits 0123→1234`, `entry_count 3→4`, 有效键码 `4` |
| 74910 | `key_valid 1→0` | 74915 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 74920 | `key_valid 0→1`, `key_code 4→A` | 74925 | `state 2:USER→4:OPEN`, `unlocked 0→1`, 有效键码 `A` |
| 74930 | `key_valid 1→0` | 74935 | `state=4:OPEN` 保持, 按键有效位释放，不重复提交 |
| 74940 | `admin_event 0→1`, `key_valid 0→1` | 74945 | `state 4:OPEN→1:WAIT/PASS`, `entry_digits 1234→0000`, `entry_count 4→0`, `unlocked 1→0`, 有效键码 `A` |
| 74950 | `admin_event 1→0`, `key_valid 1→0` | 74955 | `state=1:WAIT/PASS` 保持, 按键有效位释放，不重复提交 |

窗口起点：`rst=0`, `flash_init_done=1`, `sw1_event=0`, `admin_event=0`, `alarm_clear_event=0`, `temporary_event=0`, `key_valid=0`, `key_code=A`, `save_done=0`, `save_success=0`, `stored_password=1234`, `temporary_password=0000`, `temporary_valid=0`, `flash_fault=0`。

## 对应实际功能

成功开锁后自然等待，在 timer_count=1999 时同时送数字 1 和 KEY1：OPEN 的超时条件不检查 !activity，故仍 OPEN→WAIT，而不是留在 OPEN 或进入 ADMIN。再次成功开锁后，A 与 KEY1 同拍，主动关锁条件优先，仍 OPEN→WAIT。分别有期限边界与 A/KEY1 放大图。

## 再次打开与分段截屏

配置：[WCFG](../configs/15_open_deadline_priority_manual.wcfg)，完整数据：[WDB](../tb_lock_controller_fsm.wdb)、[VCD](../tb_lock_controller_fsm.vcd)。

在 Vivado Tcl Console 执行（将路径替换为本地仓库路径）：

```tcl
open_wave_database -noautoloadwcfg E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/tb_lock_controller_fsm.wdb
open_wave_config E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/configs/15_open_deadline_priority_manual.wcfg
# 时间窗口已内嵌在 WCFG；打开配置即恢复对应分段。
```
