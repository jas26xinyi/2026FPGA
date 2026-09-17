# 分段图索引

### 初始化与安全恢复

| 图 | 场景 | 时间/ns |
| --- | --- | --- |
| 01 | [上电门控：Flash 完成前不接收操作](notes/01_boot_gate.md) | 0–160 |
| 29 | [从 BOOT(0) 同步复位并重新初始化](notes/22_reset_from_0.md) | 86940–87090 |
| 30 | [从 WAIT/PASS(1) 同步复位并重新初始化](notes/23_reset_from_1.md) | 87190–87340 |
| 31 | [从 USER(2) 同步复位并重新初始化](notes/24_reset_from_2.md) | 87440–87590 |
| 32 | [从 ERROR(3) 同步复位并重新初始化](notes/25_reset_from_3.md) | 87790–87940 |
| 33 | [从 OPEN(4) 同步复位并重新初始化](notes/26_reset_from_4.md) | 88140–88290 |
| 34 | [从 ADMIN/SET(5) 同步复位并重新初始化](notes/27_reset_from_5.md) | 88390–88540 |
| 35 | [从 SAVE(6) 同步复位并重新初始化](notes/28_reset_from_6.md) | 88740–88890 |
| 36 | [从 ALARM(7) 同步复位并重新初始化](notes/29_reset_from_7.md) | 89990–90140 |
| 37 | [从 TEMP(8) 同步复位并重新初始化](notes/30_reset_from_8.md) | 90240–90390 |
| 38 | [非法状态编码恢复到 BOOT](notes/31_illegal_state_recovery.md) | 90390–90510 |

### 普通输入、编辑和超时

| 图 | 场景 | 时间/ns |
| --- | --- | --- |
| 02 | [输入编辑、永久密码开锁与 A 主动关锁](notes/02_entry_edit_unlock_close.md) | 160–490 |
| 03 | [用户取消不清除历史错误次数](notes/03_user_cancel_failure_history.md) | 490–960 |
| 04 | [用户输入无操作超时](notes/04_user_timeout.md) | 960–11070 |
| 05 | [用户输入无操作超时（期限放大）](notes/04_user_timeout_boundary.md) | 10905–11070 |
| 06 | [用户超时边界：有效数字优先，D 不算活动](notes/05_user_boundary_activity.md) | 11070–21220 |
| 07 | [用户超时边界：有效数字优先，D 不算活动（期限放大）](notes/05_user_boundary_activity_boundary.md) | 20995–21185 |

### 管理员改密和 Flash 保存握手

| 图 | 场景 | 时间/ns |
| --- | --- | --- |
| 08 | [管理员编辑、未满四位确认和取消](notes/06_admin_edit_cancel.md) | 21220–21430 |
| 09 | [管理员输入超时不写 Flash](notes/07_admin_timeout.md) | 21430–31540 |
| 10 | [管理员输入超时不写 Flash（期限放大）](notes/07_admin_timeout_boundary.md) | 31375–31540 |
| 11 | [保存成功握手与新永久密码验证](notes/08_save_success_new_password.md) | 31540–31960 |
| 12 | [保存失败、故障标志清除与 Flash 故障优先级](notes/09_save_failure_flash_priority.md) | 31960–32330 |
| 16 | [开锁期间进入管理员并保存](notes/13_open_admin_save.md) | 34230–34470 |

### 错误累计、报警与解除

| 图 | 场景 | 时间/ns |
| --- | --- | --- |
| 13 | [前三次错误：Err1、Err2、Err3 与自动重试](notes/10_first_three_failures.md) | 32410–33400 |
| 14 | [第四次错误直接报警、抓拍单脉冲与旁路阻断](notes/11_fourth_failure_alarm_block.md) | 33400–33740 |
| 15 | [KEY2 解除报警、新错误窗口与成功清零](notes/12_alarm_clear_retry_success.md) | 33740–34230 |

### 开锁退出、超时及优先级

| 图 | 场景 | 时间/ns |
| --- | --- | --- |
| 17 | [开锁 2000 拍自动关锁](notes/14_open_timeout.md) | 34470–54660 |
| 18 | [开锁 2000 拍自动关锁（期限放大）](notes/14_open_timeout_boundary.md) | 54495–54660 |
| 19 | [OPEN 优先级：超时与 A 关锁均优先于 KEY1](notes/15_open_deadline_priority.md) | 54660–74990 |
| 20 | [OPEN 优先级：超时与 A 关锁均优先于 KEY1（期限放大）](notes/15_open_deadline_priority_boundary.md) | 74685–74875 |
| 21 | [A 与 KEY1 同拍：主动关锁优先](notes/15_open_deadline_priority_manual.md) | 74760–74990 |

### 临时密码和 WAIT 入口优先级

| 图 | 场景 | 时间/ns |
| --- | --- | --- |
| 22 | [WAIT 同拍入口优先级](notes/16_wait_event_priority.md) | 74990–75180 |
| 23 | [TEMP 重新生成自环、显示计时重启及临时密码开锁](notes/17_temp_regenerate_priority.md) | 75180–75510 |
| 24 | [TEMP 显示按 A 返回等待](notes/18_temp_confirm_exit.md) | 75510–75620 |
| 25 | [TEMP 显示按 C 取消](notes/19_temp_cancel_exit.md) | 75620–75730 |
| 26 | [TEMP 显示超时退出](notes/20_temp_timeout.md) | 75730–85820 |
| 27 | [TEMP 显示超时退出（期限放大）](notes/20_temp_timeout_boundary.md) | 85655–85820 |
| 28 | [临时密码替换拒绝旧值、有效位门控和永久密码共存](notes/21_temp_replacement_valid_gate.md) | 85820–86810 |
