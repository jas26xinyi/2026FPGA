`timescale 1ns/1ps

module debounce_event #(
    parameter integer CLOCK_HZ    = 50_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter         ACTIVE_LOW  = 1
) (
    input  wire clk,
    input  wire rst,
    input  wire async_in,
    output reg  level,
    output reg  rise_event
);
    localparam integer COUNT_MAX = (CLOCK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer CW = (COUNT_MAX <= 2) ? 1 : $clog2(COUNT_MAX);
    (* ASYNC_REG = "TRUE" *) reg sync0, sync1;
    reg [CW-1:0] stable_count;
    wire active_sample = ACTIVE_LOW ? ~sync1 : sync1;

    always @(posedge clk) begin
        if (rst) begin
            sync0       <= 1'b0;
            sync1       <= 1'b0;
            level       <= 1'b0;
            stable_count <= {CW{1'b0}};
            rise_event  <= 1'b0;
        end else begin
            sync0      <= async_in;
            sync1      <= sync0;
            rise_event <= 1'b0;
            if (active_sample == level) begin
                stable_count <= {CW{1'b0}};
            end else if (stable_count == COUNT_MAX-1) begin
                stable_count <= {CW{1'b0}};
                level        <= active_sample;
                if (active_sample)
                    rise_event <= 1'b1;
            end else begin
                stable_count <= stable_count + 1'b1;
            end
        end
    end
endmodule
