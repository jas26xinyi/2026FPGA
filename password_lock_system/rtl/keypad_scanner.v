`timescale 1ns/1ps

// 4x4 keypad scanner. Columns are driven low one at a time. A key event is
// emitted once after five identical complete scans (20 ms at 1 ms/column).
// Any multi-key sample suppresses events until every key has been released.
module keypad_scanner #(
    parameter integer CLOCK_HZ       = 50_000_000,
    parameter integer COLUMN_TICK_HZ = 1_000,
    parameter integer DEBOUNCE_SCANS = 5
) (
    input  wire       clk,
    input  wire       rst,
    input  wire [3:0] row_n,
    output reg  [3:0] col_n,
    output reg        event_valid,
    output reg  [3:0] event_code
);
    wire column_tick;
    reg [1:0] column_index;
    reg [15:0] sampled_keys;
    reg [15:0] candidate;
    reg [3:0] stable_scans;
    reg armed;
    reg blocked_multi;
    reg [15:0] complete_sample;
    integer i;
    integer key_count;

    tick_enable #(.CLOCK_HZ(CLOCK_HZ), .TICK_HZ(COLUMN_TICK_HZ)) u_tick (
        .clk(clk), .rst(rst), .tick(column_tick)
    );

    function [3:0] decode_key;
        input [15:0] onehot;
        begin
            case (onehot)
                16'h0001: decode_key = 4'h1;
                16'h0002: decode_key = 4'h4;
                16'h0004: decode_key = 4'h7;
                16'h0008: decode_key = 4'hE;
                16'h0010: decode_key = 4'h2;
                16'h0020: decode_key = 4'h5;
                16'h0040: decode_key = 4'h8;
                16'h0080: decode_key = 4'h0;
                16'h0100: decode_key = 4'h3;
                16'h0200: decode_key = 4'h6;
                16'h0400: decode_key = 4'h9;
                16'h0800: decode_key = 4'hF;
                16'h1000: decode_key = 4'hA;
                16'h2000: decode_key = 4'hB;
                16'h4000: decode_key = 4'hC;
                16'h8000: decode_key = 4'hD;
                default:  decode_key = 4'hF;
            endcase
        end
    endfunction

    always @(*) begin
        col_n = 4'b1111;
        case (column_index)
            2'd0: col_n = 4'b1110;
            2'd1: col_n = 4'b1101;
            2'd2: col_n = 4'b1011;
            2'd3: col_n = 4'b0111;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            column_index <= 2'd0;
            sampled_keys <= 16'h0000;
            candidate     <= 16'h0000;
            stable_scans  <= 4'd0;
            armed         <= 1'b1;
            blocked_multi <= 1'b0;
            event_valid   <= 1'b0;
            event_code    <= 4'h0;
            complete_sample <= 16'h0000;
        end else begin
            event_valid <= 1'b0;
            if (column_tick) begin
                sampled_keys[column_index*4 + 0] <= ~row_n[0];
                sampled_keys[column_index*4 + 1] <= ~row_n[1];
                sampled_keys[column_index*4 + 2] <= ~row_n[2];
                sampled_keys[column_index*4 + 3] <= ~row_n[3];
                if (column_index == 2'd3) begin
                    complete_sample = sampled_keys;
                    complete_sample[12] = ~row_n[0];
                    complete_sample[13] = ~row_n[1];
                    complete_sample[14] = ~row_n[2];
                    complete_sample[15] = ~row_n[3];
                    key_count = 0;
                    for (i = 0; i < 16; i = i + 1)
                        key_count = key_count + complete_sample[i];

                    if (complete_sample == candidate) begin
                        if (stable_scans < DEBOUNCE_SCANS)
                            stable_scans <= stable_scans + 1'b1;
                    end else begin
                        candidate    <= complete_sample;
                        stable_scans <= 4'd1;
                    end

                    if ((stable_scans == DEBOUNCE_SCANS-1) &&
                        (complete_sample == candidate)) begin
                        if (key_count == 0) begin
                            armed         <= 1'b1;
                            blocked_multi <= 1'b0;
                        end else if (key_count > 1) begin
                            armed         <= 1'b0;
                            blocked_multi <= 1'b1;
                        end else if (armed && !blocked_multi) begin
                            event_valid <= 1'b1;
                            event_code  <= decode_key(complete_sample);
                            armed       <= 1'b0;
                        end
                    end
                    column_index <= 2'd0;
                end else begin
                    column_index <= column_index + 1'b1;
                end
            end
        end
    end
endmodule
