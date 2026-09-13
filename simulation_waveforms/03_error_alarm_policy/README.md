# 03 四次错误与报警解除策略

![Vivado 仿真波形](tb_basic_alarm_policy.png)

## 波形判读

- `sw1: 0→1→0` 启动输入。每次错误密码的确认键在 `clk` 上升沿被采样后，`error_count` 依次 `0→1→2→3`，`state` 短暂进入 `3 (ERROR)` 再回到 `USER`。
- 第四次错误确认后，`error_count: 3→4`、`state: 2→7 (ALARM)`、`alarm_active: 0→1`；`capture_start` 只拉高一个时钟周期，`capture_pulses` 因对应上升沿计数一次。
- 报警期间，`temp_event`、`admin` 和普通 `key_valid` 脉冲不会改变报警状态。只有 `clear: 0→1` 被采样后，`alarm_active: 1→0`、`state: 7→2`、`error_count: 4→0`。
- 解除后的下一次错误使计数重新 `0→1`，证明新的四次机会窗口已经开始。

## 实际功能

验证 `Err1/Err2/Err3`、第四次错误报警、拍照只触发一次，以及只有 KEY2 能解除报警并复位错误次数。
