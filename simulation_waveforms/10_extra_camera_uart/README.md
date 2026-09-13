# 10 树莓派报警拍摄 UART 链路

![Vivado 仿真波形](tb_rpi_camera_link.png)

## 波形判读

- `photo_trigger: 0→1→0` 在 `clk` 上升沿被锁存，`link_waiting: 0→1`，随后 `uart_tx` 从空闲 `1→0` 产生起始位并发送 `ALARM\n`。
- 每个 UART 位保持固定的时钟周期数；`message_active` 和 `message_index` 标出当前发送状态与字节序号，`tx_starts` 统计发送起始位。
- `uart_rx` 依次接收 `ACK\n`，每个完整字符使 `rx_valid` 产生单周期 `0→1→0`，`rx_data` 给出字符；确认完成后 `link_waiting: 1→0`。
- 第二次触发不返回 ACK，重试计数达到边界后再次发送，因此 `tx_starts` 继续增加。

## 实际功能

验证 FPGA 报警请求、树莓派确认、确认后清除等待状态，以及链路无确认时自动重发。
