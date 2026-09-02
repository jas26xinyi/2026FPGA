`timescale 1ns/1ps

module tick_enable #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer TICK_HZ  = 1_000
) (
    input  wire clk,
    input  wire rst,
    output reg  tick
);
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
