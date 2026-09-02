`timescale 1ns/1ps

module frame_capture_4 #(
    parameter integer FRAME_WORDS = 19200
) (
    input  wire        pclk,
    input  wire        rst,
    input  wire        capture_start,
    input  wire        abort_capture,
    input  wire        vsync,
    input  wire        href,
    input  wire [7:0]  pixel_data,
    output reg         write_enable,
    output reg  [1:0]  write_bank,
    output reg  [14:0] write_address,
    output reg  [15:0] write_data,
    output reg         busy,
    output reg         done,
    output reg         error
);
    reg vsync_d;
    reg [1:0] bank;
    reg [14:0] word_count;
    reg byte_phase;
    reg [7:0] first_byte;
    reg waiting_first_sync;
    reg frame_active;
    wire vsync_rise = vsync & ~vsync_d;
    wire vsync_fall = ~vsync & vsync_d;

    always @(posedge pclk) begin
        if (rst) begin
            vsync_d<=0; bank<=0; word_count<=0; byte_phase<=0;
            first_byte<=0; waiting_first_sync<=0; frame_active<=0;
            write_enable<=0; write_bank<=0; write_address<=0; write_data<=0;
            busy<=0; done<=0; error<=0;
        end else begin
            vsync_d<=vsync;
            write_enable<=0; done<=0; error<=0;
            if (capture_start && !busy) begin
                bank<=0; word_count<=0; byte_phase<=0;
                waiting_first_sync<=1; frame_active<=0; busy<=1;
            end
            if (abort_capture && busy) begin
                busy<=0; frame_active<=0; waiting_first_sync<=0; error<=1;
            end else if (busy) begin
                if (vsync_rise) begin
                    if (waiting_first_sync) begin
                        waiting_first_sync<=0;
                    end else if (frame_active) begin
                        frame_active<=0;
                        if (word_count==FRAME_WORDS && !byte_phase) begin
                            if (bank==3) begin busy<=0; done<=1; end
                            else bank<=bank+1'b1;
                        end
                    end
                end
                if (vsync_fall && !waiting_first_sync) begin
                    frame_active<=1;
                    word_count<=0;
                    byte_phase<=0;
                end
                if (frame_active && href && !vsync) begin
                    if (!byte_phase) begin
                        first_byte<=pixel_data;
                        byte_phase<=1;
                    end else begin
                        byte_phase<=0;
                        if (word_count<FRAME_WORDS) begin
                            write_enable<=1;
                            write_bank<=bank;
                            write_address<=word_count;
                            write_data<={pixel_data,first_byte};
                        end
                        word_count<=word_count+1'b1;
                    end
                end
            end
        end
    end
endmodule
