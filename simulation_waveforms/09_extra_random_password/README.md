# 09 随机临时密码生成

![Vivado 仿真波形](tb_temporary_password_generator.png)

## 波形判读

- 复位释放后 `temporary_valid=0`。每个 `generate_event: 0→1→0` 在 `clk` 上升沿被采样，LFSR 当前状态被转换为四位十进制数。
- 生成沿之后，`temporary_password` 更新且 `temporary_valid: 0→1`；后续生成事件直接替换旧值，`previous_password` 用于对照前一组结果。
- 波形中每个半字节均在 `0~9`，新值不等于 `stored_password`，也不与紧邻的上一临时密码重复。
- 再次复位时 `temporary_valid: 1→0`，旧临时密码立即失效。

## 实际功能

验证 KEY3 可生成四位十进制临时密码、避开固定密码、连续替换不重复，并在复位后失效。
