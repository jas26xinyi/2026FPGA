`timescale 1ns/1ps

// 易失性 4 位临时密码发生器。LFSR 始终运行，按 KEY3 时才取样生成结果。
// 临时密码不会写入 Flash，复位或断电后 temporary_valid 清零，旧临时密码立即失效。
module temporary_password_generator (
    input  wire        clk,
    input  wire        rst,
    input  wire        generate_event,
    input  wire [15:0] stored_password,
    output reg  [15:0] temporary_password,
    output reg         temporary_valid
);
    reg [15:0] lfsr;
    reg [15:0] random_bcd_candidate;
    reg [15:0] candidate;
    reg [15:0] alternate1;
    reg [15:0] alternate2;

    // 按十进制 BCD 规则加 1（9999 后回到 0000），用于避开不能使用的候选值。
    function [15:0] next_decimal_password;
        input [15:0] value;
        reg [3:0] d3, d2, d1, d0;
        begin
            d3 = value[15:12];
            d2 = value[11:8];
            d1 = value[7:4];
            d0 = value[3:0];
            if (d0 != 4'd9) d0 = d0 + 1'b1;
            else begin
                d0 = 4'd0;
                if (d1 != 4'd9) d1 = d1 + 1'b1;
                else begin
                    d1 = 4'd0;
                    if (d2 != 4'd9) d2 = d2 + 1'b1;
                    else begin
                        d2 = 4'd0;
                        if (d3 != 4'd9) d3 = d3 + 1'b1;
                        else d3 = 4'd0;
                    end
                end
            end
            next_decimal_password = {d3, d2, d1, d0};
        end
    endfunction

    always @(*) begin
        candidate = random_bcd_candidate;
        alternate1 = next_decimal_password(candidate);
        alternate2 = next_decimal_password(alternate1);
    end

    always @(posedge clk) begin
        if (rst) begin
            lfsr               <= 16'h1D3F;
            random_bcd_candidate <= 16'h5831;
            temporary_password <= 16'h0000;
            temporary_valid    <= 1'b0;
        end else begin
            // 16 位非零种子的 LFSR：反馈多项式 x^16+x^14+x^13+x^11+1。
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            // 拒绝采样：仅接受 4 个半字节都在 0~9 的值，保证显示的是合法 BCD 且分布不受模运算偏置。
            if (lfsr[15:12] <= 9 && lfsr[11:8] <= 9 &&
                lfsr[7:4] <= 9 && lfsr[3:0] <= 9)
                random_bcd_candidate <= lfsr;
            if (generate_event) begin
                // 固定密码和上一次临时密码最多排除两个值，三个连续 BCD 候选必有一个可用。
                if (candidate != stored_password &&
                    (!temporary_valid || candidate != temporary_password))
                    temporary_password <= candidate;
                else if (alternate1 != stored_password &&
                         (!temporary_valid || alternate1 != temporary_password))
                    temporary_password <= alternate1;
                else
                    temporary_password <= alternate2;
                temporary_valid <= 1'b1;
            end
        end
    end
endmodule
