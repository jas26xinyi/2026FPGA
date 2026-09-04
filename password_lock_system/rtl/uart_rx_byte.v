`timescale 1ns/1ps

module uart_rx_byte #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer BAUD     = 115_200
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       rx,
    output reg  [7:0] data,
    output reg        valid
);
    localparam integer CLKS_PER_BIT = (CLOCK_HZ + (BAUD/2)) / BAUD;
    localparam integer HALF_BIT     = CLKS_PER_BIT / 2;
    localparam integer CW = (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);
    localparam [1:0] RX_IDLE=2'd0,RX_START=2'd1,RX_DATA=2'd2,RX_STOP=2'd3;

    reg rx_meta,rx_sync;
    reg [1:0] state;
    reg [CW-1:0] clock_count;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
        if (rst) begin
            state       <= RX_IDLE;
            clock_count <= {CW{1'b0}};
            bit_index   <= 3'd0;
            shift       <= 8'd0;
            data        <= 8'd0;
            valid       <= 1'b0;
            rx_meta     <= 1'b1;
            rx_sync     <= 1'b1;
        end else begin
            valid <= 1'b0;
            case (state)
                RX_IDLE: if (!rx_sync) begin
                    clock_count <= HALF_BIT;
                    state <= RX_START;
                end
                RX_START: if (clock_count != 0)
                    clock_count <= clock_count - 1'b1;
                else if (!rx_sync) begin
                    clock_count <= CLKS_PER_BIT-1;
                    bit_index <= 3'd0;
                    state <= RX_DATA;
                end else state <= RX_IDLE;
                RX_DATA: if (clock_count != 0)
                    clock_count <= clock_count - 1'b1;
                else begin
                    shift[bit_index] <= rx_sync;
                    clock_count <= CLKS_PER_BIT-1;
                    if (bit_index == 3'd7) state <= RX_STOP;
                    else bit_index <= bit_index + 1'b1;
                end
                RX_STOP: if (clock_count != 0)
                    clock_count <= clock_count - 1'b1;
                else begin
                    if (rx_sync) begin
                        data  <= shift;
                        valid <= 1'b1;
                    end
                    state <= RX_IDLE;
                end
                default: state <= RX_IDLE;
            endcase
        end
    end
endmodule
