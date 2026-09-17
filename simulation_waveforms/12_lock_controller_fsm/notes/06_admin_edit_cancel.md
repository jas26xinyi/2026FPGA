# 06_admin_edit_cancel：管理员编辑、未满四位确认和取消

窗口：**21220–21430 ns**，连续绝对时间；scenario=6。

## 原生 Vivado 截屏

![原生 Vivado 分段波形](../images/06_admin_edit_cancel_native.png)

这是 Vivado 2023.2 的 Wave 面板实际截图，未重绘波形。左侧 Name/Value 列的 Value 是黄色游标位置的瞬时值，不一定是事件发生时的值；请按图中横向时间轴和下表判读。state 编码：0 BOOT、1 WAIT、2 USER、3 ERROR、4 OPEN、5 ADMIN、6 SAVE、7 ALARM、8 TEMP。密码和 key_code 为十六进制 BCD。

## 前置条件

WAIT。KEY1 对应 admin_event。

## 当前激励与状态变化

KEY1→ADMIN；输入 5 后 A 被忽略，不触发 save_request。9、B、6 将输入改为 0056；C 使 ADMIN→WAIT，清空输入，始终没有保存请求。

所有事件输入都由测试平台产生一个 10 ns 周期的脉冲。key_valid=1 时 key_code 才是当前新按键；key_valid=0 时保留的 key_code 不是重复激励。next_state 是组合判断，state 在下一上升沿更新；采样后 save_request/capture_start 高一个完整周期。

## 实际端口跳变、采样沿与效果

下表由这次 XSim 的 VCD 数据逐拍反查；`T` ns 的测试平台激励一般在 `clk` 下降沿改变，下一次 `clk` 上升沿在 `T+5` ns 采样。状态/输出用采样后的值，不把 `key_valid` 释放沿误认为第二次按键。表中明确用 0→1 和 1→0 表示端口边沿；若放大窗口中没有新输入边沿，则写明由前序激励或自然计时触发。

| 激励时刻/ns | 输入端口变化 | clk 上升沿/ns | 状态、输出端口实际效果 / 功能 |
| --- | --- | --- | --- |
| 21260 | `admin_event 0→1` | 21265 | `state 1:WAIT/PASS→5:ADMIN/SET` |
| 21270 | `admin_event 1→0` | 21275 | `state=5:ADMIN/SET` 保持 |
| 21280 | `key_valid 0→1`, `key_code C→5` | 21285 | `state=5:ADMIN/SET` 保持, `entry_digits 0000→0005`, `entry_count 0→1`, 有效键码 `5` |
| 21290 | `key_valid 1→0` | 21295 | `state=5:ADMIN/SET` 保持, 按键有效位释放，不重复提交 |
| 21300 | `key_valid 0→1`, `key_code 5→A` | 21305 | `state=5:ADMIN/SET` 保持, 有效键码 `A` |
| 21310 | `key_valid 1→0` | 21315 | `state=5:ADMIN/SET` 保持, 按键有效位释放，不重复提交 |
| 21320 | `key_valid 0→1`, `key_code A→9` | 21325 | `state=5:ADMIN/SET` 保持, `entry_digits 0005→0059`, `entry_count 1→2`, 有效键码 `9` |
| 21330 | `key_valid 1→0` | 21335 | `state=5:ADMIN/SET` 保持, 按键有效位释放，不重复提交 |
| 21340 | `key_valid 0→1`, `key_code 9→B` | 21345 | `state=5:ADMIN/SET` 保持, `entry_digits 0059→0005`, `entry_count 2→1`, 有效键码 `B` |
| 21350 | `key_valid 1→0` | 21355 | `state=5:ADMIN/SET` 保持, 按键有效位释放，不重复提交 |
| 21360 | `key_valid 0→1`, `key_code B→6` | 21365 | `state=5:ADMIN/SET` 保持, `entry_digits 0005→0056`, `entry_count 1→2`, 有效键码 `6` |
| 21370 | `key_valid 1→0` | 21375 | `state=5:ADMIN/SET` 保持, 按键有效位释放，不重复提交 |
| 21380 | `key_valid 0→1`, `key_code 6→C` | 21385 | `state 5:ADMIN/SET→1:WAIT/PASS`, `entry_digits 0056→0000`, `entry_count 2→0`, 有效键码 `C` |
| 21390 | `key_valid 1→0` | 21395 | `state=1:WAIT/PASS` 保持, 按键有效位释放，不重复提交 |

窗口起点：`rst=0`, `flash_init_done=1`, `sw1_event=0`, `admin_event=0`, `alarm_clear_event=0`, `temporary_event=0`, `key_valid=0`, `key_code=C`, `save_done=0`, `save_success=0`, `stored_password=1234`, `temporary_password=0000`, `temporary_valid=0`, `flash_fault=0`。

## 对应实际功能

KEY1→ADMIN；输入 5 后 A 被忽略，不触发 save_request。9、B、6 将输入改为 0056；C 使 ADMIN→WAIT，清空输入，始终没有保存请求。

## 再次打开与分段截屏

配置：[WCFG](../configs/06_admin_edit_cancel.wcfg)，完整数据：[WDB](../tb_lock_controller_fsm.wdb)、[VCD](../tb_lock_controller_fsm.vcd)。

在 Vivado Tcl Console 执行（将路径替换为本地仓库路径）：

```tcl
open_wave_database -noautoloadwcfg E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/tb_lock_controller_fsm.wdb
open_wave_config E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/configs/06_admin_edit_cancel.wcfg
# 时间窗口已内嵌在 WCFG；打开配置即恢复对应分段。
```
