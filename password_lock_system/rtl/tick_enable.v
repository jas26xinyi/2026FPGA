`timescale 1ns/1ps

// 通用分频使能脉冲发生器：每 DIVISOR 个 clk 输出一个周期宽的 tick。
// tick 只作为时序逻辑的 clock-enable 使用，不生成新的时钟域。
module tick_enable #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer TICK_HZ  = 1_000
) (
    input  wire clk,
    input  wire rst,
    output reg  tick
);
    // 要求 CLOCK_HZ 能满足目标频率精度；当前键盘参数 50 MHz/1 kHz 可整除。
    localparam integer DIVISOR = CLOCK_HZ / TICK_HZ;
    localparam integer WIDTH = (DIVISOR <= 2) ? 1 : $clog2(DIVISOR);
    reg [WIDTH-1:0] count;

    always @(posedge clk) begin
        if (rst) begin
            count <= {WIDTH{1'b0}};
            tick  <= 1'b0;
        end else if (count == DIVISOR-1) begin
            count <= {WIDTH{1'b0}};
            tick  <= 1'b1;
        end else begin
            count <= count + 1'b1;
            tick  <= 1'b0;
        end
    end
endmodule
