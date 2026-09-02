`timescale 1ns/1ps

module sevenseg_display #(
    parameter integer CLOCK_HZ = 50_000_000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire [3:0]  state,
    input  wire [15:0] entry_digits,
    input  wire [2:0]  entry_count,
    input  wire [2:0]  error_count,
    input  wire        display_fault,
    output reg  [7:0]  seg_n,
    output reg  [7:0]  digit_sel
);
    localparam [3:0] ST_BOOT=0, ST_WAIT=1, ST_USER=2, ST_ERROR=3,
                     ST_OPEN=4, ST_ADMIN=5, ST_SAVE=6, ST_ALARM=7;
    localparam [4:0] CH_BLANK=5'h10, CH_P=5'h11, CH_A=5'h12, CH_S=5'h13,
                     CH_E=5'h14, CH_T=5'h15, CH_R=5'h16, CH_O=5'h17,
                     CH_N=5'h18, CH_L=5'h19, CH_F=5'h1A, CH_I=5'h1B,
                     CH_U=5'h1C;
    reg [18:0] refresh_count;
    reg [2:0] scan;
    reg [4:0] chars [0:7];
    integer i;

    function [7:0] encode;
        input [4:0] ch;
        begin
            case (ch)
                0: encode=8'b11000000; 1: encode=8'b11111001;
                2: encode=8'b10100100; 3: encode=8'b10110000;
                4: encode=8'b10011001; 5: encode=8'b10010010;
                6: encode=8'b10000010; 7: encode=8'b11111000;
                8: encode=8'b10000000; 9: encode=8'b10010000;
                CH_P: encode=8'b10001100; CH_A: encode=8'b10001000;
                CH_S: encode=8'b10010010; CH_E: encode=8'b10000110;
                CH_T: encode=8'b10000111; CH_R: encode=8'b10101111;
                CH_O: encode=8'b11000000; CH_N: encode=8'b10101011;
                CH_L: encode=8'b11000111; CH_F: encode=8'b10001110;
                CH_I: encode=8'b11111001;
                CH_U: encode=8'b11000001;
                default: encode=8'b11111111;
            endcase
        end
    endfunction

    always @(*) begin
        for (i=0; i<8; i=i+1) chars[i]=CH_BLANK;
        if (display_fault) begin
            chars[7]=CH_F; chars[6]=CH_E; chars[5]=CH_R; chars[4]=CH_R;
        end else case (state)
            ST_BOOT: begin chars[7]=CH_I; chars[6]=CH_N; chars[5]=CH_I; chars[4]=CH_T; end
            ST_WAIT: begin chars[7]=CH_P; chars[6]=CH_A; chars[5]=CH_S; chars[4]=CH_S; end
            ST_USER: begin chars[7]=CH_P; chars[6]=CH_A; chars[5]=CH_S; chars[4]=CH_S; end
            ST_ERROR: begin chars[7]=CH_E; chars[6]=CH_R; chars[5]=CH_R; chars[4]={2'b00,error_count}; end
            ST_OPEN: begin chars[7]=CH_O; chars[6]=CH_P; chars[5]=CH_E; chars[4]=CH_N; end
            ST_ADMIN: begin chars[7]=CH_S; chars[6]=CH_E; chars[5]=CH_T; chars[4]=CH_BLANK; end
            ST_SAVE: begin chars[7]=CH_S; chars[6]=CH_A; chars[5]=CH_U; chars[4]=CH_E; end
            ST_ALARM: begin chars[7]=CH_A; chars[6]=CH_L; chars[5]=CH_A; chars[4]=CH_R; end
            default: ;
        endcase
        if (entry_count > 0) chars[0] = entry_digits[3:0];
        if (entry_count > 1) chars[1] = entry_digits[7:4];
        if (entry_count > 2) chars[2] = entry_digits[11:8];
        if (entry_count > 3) chars[3] = entry_digits[15:12];
    end

    always @(posedge clk) begin
        if (rst) begin
            refresh_count <= 0;
            scan <= 0;
        end else if (refresh_count == CLOCK_HZ/8000-1) begin
            refresh_count <= 0;
            scan <= scan + 1'b1;
        end else refresh_count <= refresh_count + 1'b1;
    end

    always @(*) begin
        digit_sel = 8'b00000001 << scan;
        seg_n = encode(chars[scan]);
    end
endmodule
