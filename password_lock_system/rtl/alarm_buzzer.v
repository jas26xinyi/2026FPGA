`timescale 1ns/1ps

// On this hardware revision the onboard buzzer was verified as high-active.
// The top-level port retains its legacy buzzer_n name for project/interface
// compatibility. A slow interrupted cadence is combined with an audio carrier.
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
            if (beep_count == BEEP_HALF_TICKS-1) begin
                beep_count <= {BW{1'b0}};
                beep_on    <= ~beep_on;
            end else begin
                beep_count <= beep_count + 1'b1;
            end

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

    // Actual-board verification overrides the old manual: P20 is high-active.
    // Idle and the quiet half of the cadence are therefore driven low.
    assign buzzer_n = (alarm_active && beep_on) ? tone_phase : 1'b0;
    assign indicator = alarm_active && beep_on;
endmodule
