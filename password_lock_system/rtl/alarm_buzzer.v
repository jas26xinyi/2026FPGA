`timescale 1ns/1ps

// 报警蜂鸣器：用低频断续节拍包络 2 kHz 音频方波，同时输出同节拍 LED 指示。
// 实板已验证蜂鸣器为高电平有效；端口名 buzzer_n 仅为兼容旧工程命名，不表示低有效。
module alarm_buzzer #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer BEEP_HZ  = 2,
    parameter integer TONE_HZ  = 2_000
) (
    input  wire clk,
    input  wire rst,
    input  wire alarm_active,
    output wire buzzer_n,
    output wire indicator
);
    // 半周期计数值决定节拍与音调；修改 BEEP_HZ/TONE_HZ 即可改变报警听感。
    localparam integer BEEP_HALF_TICKS = CLOCK_HZ / (2 * BEEP_HZ);
    localparam integer TONE_HALF_TICKS = CLOCK_HZ / (2 * TONE_HZ);
    localparam integer BW = (BEEP_HALF_TICKS <= 2) ? 1 : $clog2(BEEP_HALF_TICKS);
    localparam integer TW = (TONE_HALF_TICKS <= 2) ? 1 : $clog2(TONE_HALF_TICKS);

    reg [BW-1:0] beep_count;
    reg [TW-1:0] tone_count;
    reg beep_on;
    reg tone_phase;

    always @(posedge clk) begin
        if (rst || !alarm_active) begin
            beep_count <= {BW{1'b0}};
            tone_count <= {TW{1'b0}};
            beep_on    <= 1'b1;
            tone_phase <= 1'b1;
        end else begin
            // beep_on 每半个低频周期翻转，形成“响一段、停一段”的断续报警。
            if (beep_count == BEEP_HALF_TICKS-1) begin
                beep_count <= {BW{1'b0}};
                beep_on    <= ~beep_on;
            end else begin
                beep_count <= beep_count + 1'b1;
            end

            // 静音阶段复位音频相位；响铃阶段按 TONE_HZ 连续翻转输出。
            if (!beep_on) begin
                tone_count <= {TW{1'b0}};
                tone_phase <= 1'b1;
            end else if (tone_count == TONE_HALF_TICKS-1) begin
                tone_count <= {TW{1'b0}};
                tone_phase <= ~tone_phase;
            end else begin
                tone_count <= tone_count + 1'b1;
            end
        end
    end

    // 未报警或节拍静音时输出低电平；indicator 可直接驱动报警 LED。
    assign buzzer_n = (alarm_active && beep_on) ? tone_phase : 1'b0;
    assign indicator = alarm_active && beep_on;
endmodule
