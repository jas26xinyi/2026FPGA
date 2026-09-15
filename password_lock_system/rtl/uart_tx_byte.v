`timescale 1ns/1ps

// UART 8N1 单字节发送器：1 位起始(0)、8 位数据 LSB 先发、无校验、1 位停止(1)。
// send 仅在 busy=0 时采纳；done 在完整 10 位帧发送结束时脉冲一个 clk。
module uart_tx_byte #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer BAUD     = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       send,
    input  wire [7:0] data,
    output reg        tx,
    output reg        busy,
    output reg        done
);
    // 加 BAUD/2 后做整数除法，相当于对每比特时钟数四舍五入。
    localparam integer CLKS_PER_BIT = (CLOCK_HZ + (BAUD/2)) / BAUD;
    localparam integer CW = (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);
    reg [CW-1:0] clock_count;
    reg [3:0] bit_index;
    reg [9:0] frame;

    always @(posedge clk) begin
        if (rst) begin
            tx          <= 1'b1;
            busy        <= 1'b0;
            done        <= 1'b0;
            clock_count <= {CW{1'b0}};
            bit_index   <= 4'd0;
            frame       <= 10'h3ff;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                tx <= 1'b1;
                if (send) begin
                    // frame[0] 是起始位，frame[1] 起依次为 data[0]~data[7]，最后为停止位。
                    frame       <= {1'b1,data,1'b0};
                    tx          <= 1'b0;
                    busy        <= 1'b1;
                    clock_count <= CLKS_PER_BIT-1;
                    bit_index   <= 4'd0;
                end
            end else if (clock_count != 0) begin
                clock_count <= clock_count - 1'b1;
            end else if (bit_index == 4'd9) begin
                tx   <= 1'b1;
                busy <= 1'b0;
                done <= 1'b1;
            end else begin
                bit_index   <= bit_index + 1'b1;
                tx          <= frame[bit_index+1'b1];
                clock_count <= CLKS_PER_BIT-1;
            end
        end
    end
endmodule
