`timescale 1ns/1ps

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
