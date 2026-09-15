`timescale 1ns/1ps

// FPGA 到树莓派的可靠、可读 UART 事件链路。
// 协议：FPGA 发送 ASCII "ALARM\n"，树莓派收到完整命令后立即回复 "ACK\n"。
// 未收到 ACK 时每 RETRY_CYCLES 个系统时钟重发一次；默认 50 MHz 下约为 500 ms。
// 拍照请求被 link_waiting 独立锁存，因此解除蜂鸣报警不会取消尚未确认的拍照请求。
module rpi_camera_link #(
    parameter integer CLOCK_HZ     = 50_000_000,
    parameter integer BAUD         = 115_200,
    parameter integer RETRY_CYCLES = 25_000_000
) (
    input  wire clk,
    input  wire rst,
    input  wire photo_trigger,
    input  wire uart_rx,
    output wire uart_tx,
    output reg  link_waiting
);
    // message_index 指向 ALARM\n 的当前字节；ack_state 用于逐字节匹配 ACK\n。
    reg tx_send;
    reg [7:0] tx_data;
    wire tx_busy,tx_done;
    wire [7:0] rx_data;
    wire rx_valid;
    reg [2:0] message_index;
    reg message_active;
    reg byte_issued;
    reg [31:0] retry_count;
    reg [2:0] ack_state;

    uart_tx_byte #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) u_tx(
        .clk(clk),.rst(rst),.send(tx_send),.data(tx_data),
        .tx(uart_tx),.busy(tx_busy),.done(tx_done));
    uart_rx_byte #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) u_rx(
        .clk(clk),.rst(rst),.rx(uart_rx),.data(rx_data),.valid(rx_valid));

    // 将消息下标映射为待发送的 ASCII 字节，下标 5 对应换行符 0x0A。
    function [7:0] alarm_byte;
        input [2:0] index;
        begin
            case (index)
                3'd0: alarm_byte = "A";
                3'd1: alarm_byte = "L";
                3'd2: alarm_byte = "A";
                3'd3: alarm_byte = "R";
                3'd4: alarm_byte = "M";
                default: alarm_byte = 8'h0a;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            tx_send        <= 1'b0;
            tx_data        <= 8'd0;
            message_index  <= 3'd0;
            message_active <= 1'b0;
            byte_issued    <= 1'b0;
            retry_count    <= 32'd0;
            ack_state      <= 3'd0;
            link_waiting   <= 1'b0;
        end else begin
            tx_send <= 1'b0;

            // photo_trigger 来自第 4 次密码错误进入报警态时产生的单周期脉冲。
            if (photo_trigger) begin
                link_waiting   <= 1'b1;
                message_active <= 1'b1;
                message_index  <= 3'd0;
                byte_issued    <= 1'b0;
                retry_count    <= 32'd0;
                ack_state      <= 3'd0;
            end

            // 接收端允许从任意字节重新寻找 'A'，避免噪声或错位导致永久失步。
            if (rx_valid) begin
                case (ack_state)
                    3'd0: ack_state <= (rx_data == "A") ? 3'd1 : 3'd0;
                    3'd1: ack_state <= (rx_data == "C") ? 3'd2 :
                                           ((rx_data == "A") ? 3'd1 : 3'd0);
                    3'd2: ack_state <= (rx_data == "K") ? 3'd3 :
                                           ((rx_data == "A") ? 3'd1 : 3'd0);
                    3'd3: begin
                        ack_state <= (rx_data == 8'h0a) ? 3'd4 :
                                     ((rx_data == "A") ? 3'd1 : 3'd0);
                        if (rx_data == 8'h0a) begin
                            link_waiting <= 1'b0;
                            retry_count  <= 32'd0;
                        end
                    end
                    default: ack_state <= 3'd0;
                endcase
            end

            // 每个字节只向 UART 发送器发一次 send 脉冲，等待 tx_done 后再发下一字节。
            if (message_active) begin
                if (!byte_issued && !tx_busy) begin
                    tx_data     <= alarm_byte(message_index);
                    tx_send     <= 1'b1;
                    byte_issued <= 1'b1;
                end
                if (tx_done) begin
                    byte_issued <= 1'b0;
                    if (message_index == 3'd5) begin
                        message_active <= 1'b0;
                        message_index  <= 3'd0;
                        retry_count    <= 32'd0;
                    end else begin
                        message_index <= message_index + 1'b1;
                    end
                end
            // 一帧发完后等待 ACK；超时则从 'A' 开始重发完整命令。
            end else if (link_waiting) begin
                if (retry_count >= RETRY_CYCLES-1) begin
                    retry_count    <= 32'd0;
                    message_active <= 1'b1;
                    message_index  <= 3'd0;
                    byte_issued    <= 1'b0;
                end else retry_count <= retry_count + 1'b1;
            end
        end
    end
endmodule
