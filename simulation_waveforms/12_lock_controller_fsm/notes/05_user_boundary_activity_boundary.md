# 05_user_boundary_activity_boundary：用户超时边界：有效数字优先，D 不算活动（期限放大）

窗口：**20995–21185 ns**，连续绝对时间；scenario=5。

## 原生 Vivado 截屏

![原生 Vivado 分段波形](../images/05_user_boundary_activity_boundary_native.png)

这是 Vivado 2023.2 的 Wave 面板实际截图，未重绘波形。左侧 Name/Value 列的 Value 是黄色游标位置的瞬时值，不一定是事件发生时的值；请按图中横向时间轴和下表判读。state 编码：0 BOOT、1 WAIT、2 USER、3 ERROR、4 OPEN、5 ADMIN、6 SAVE、7 ALARM、8 TEMP。密码和 key_code 为十六进制 BCD。

## 前置条件

同主题完整图的最后期限附近；此图连续时间轴，不拼接、不压缩等待。

## 当前激励与状态变化

SW1 后输入 1。自然等待至 998，在下一下降沿使 key_valid=1/key_code=2，此时 timer_count=999；上升沿因 activity=1 抑制超时，仍 USER，输入=0012，timer_count=0。D 不改变输入且不清零计时器；C 退出。未 force 计时器。

所有事件输入都由测试平台产生一个 10 ns 周期的脉冲。key_valid=1 时 key_code 才是当前新按键；key_valid=0 时保留的 key_code 不是重复激励。next_state 是组合判断，state 在下一上升沿更新；采样后 save_request/capture_start 高一个完整周期。

## 实际端口跳变、采样沿与效果

下表由这次 XSim 的 VCD 数据逐拍反查；`T` ns 的测试平台激励一般在 `clk` 下降沿改变，下一次 `clk` 上升沿在 `T+5` ns 采样。状态/输出用采样后的值，不把 `key_valid` 释放沿误认为第二次按键。表中明确用 0→1 和 1→0 表示端口边沿；若放大窗口中没有新输入边沿，则写明由前序激励或自然计时触发。

| 激励时刻/ns | 输入端口变化 | clk 上升沿/ns | 状态、输出端口实际效果 / 功能 |
| --- | --- | --- | --- |
| 21130 | `key_valid 0→1`, `key_code 1→2` | 21135 | `state=2:USER` 保持, `entry_digits 0001→0012`, `entry_count 1→2`, 有效键码 `2` |
| 21140 | `key_valid 1→0` | 21145 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 21150 | `key_valid 0→1`, `key_code 2→D` | 21155 | `state=2:USER` 保持, 有效键码 `D` |
| 21160 | `key_valid 1→0` | 21165 | `state=2:USER` 保持, 按键有效位释放，不重复提交 |
| 21170 | `key_valid 0→1`, `key_code D→C` | 21175 | `state 2:USER→1:WAIT/PASS`, `entry_digits 0012→0000`, `entry_count 2→0`, 有效键码 `C` |
| 21180 | `key_valid 1→0` | 21185 | `state=1:WAIT/PASS` 保持, 按键有效位释放，不重复提交 |

窗口起点：`rst=0`, `flash_init_done=1`, `sw1_event=0`, `admin_event=0`, `alarm_clear_event=0`, `temporary_event=0`, `key_valid=0`, `key_code=1`, `save_done=0`, `save_success=0`, `stored_password=1234`, `temporary_password=0000`, `temporary_valid=0`, `flash_fault=0`。

## 对应实际功能

SW1 后输入 1。自然等待至 998，在下一下降沿使 key_valid=1/key_code=2，此时 timer_count=999；上升沿因 activity=1 抑制超时，仍 USER，输入=0012，timer_count=0。D 不改变输入且不清零计时器；C 退出。未 force 计时器。

## 再次打开与分段截屏

配置：[WCFG](../configs/05_user_boundary_activity_boundary.wcfg)，完整数据：[WDB](../tb_lock_controller_fsm.wdb)、[VCD](../tb_lock_controller_fsm.vcd)。

在 Vivado Tcl Console 执行（将路径替换为本地仓库路径）：

```tcl
open_wave_database -noautoloadwcfg E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/tb_lock_controller_fsm.wdb
open_wave_config E:/26FPGA/simulation_waveforms/12_lock_controller_fsm/configs/05_user_boundary_activity_boundary.wcfg
# 时间窗口已内嵌在 WCFG；打开配置即恢复对应分段。
```
