`timescale 1ns/1ps

// SPI mode-0 byte engine. With HALF_DIV=2 and a 50 MHz input the SCLK is
// 12.5 MHz. Chip-select is intentionally controlled by the transaction FSM.
module spi_byte_master #(
    parameter integer HALF_DIV = 2
) (
    input  wire       clk,
    input  wire       rst,
    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire       miso,
    output reg        sclk,
    output reg        mosi,
    output reg  [7:0] rx_data,
    output reg        busy,
    output reg        done
);
    localparam integer DW = (HALF_DIV <= 2) ? 1 : $clog2(HALF_DIV);
    reg [DW-1:0] div_count;
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [3:0] edge_count;

    always @(posedge clk) begin
        if (rst) begin
            sclk      <= 1'b0;
            mosi      <= 1'b0;
            rx_data   <= 8'h00;
            busy      <= 1'b0;
            done      <= 1'b0;
            div_count <= {DW{1'b0}};
            tx_shift  <= 8'h00;
            rx_shift  <= 8'h00;
            edge_count <= 4'd0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                sclk <= 1'b0;
                if (start) begin
                    busy       <= 1'b1;
                    tx_shift   <= tx_data;
                    rx_shift   <= 8'h00;
                    mosi       <= tx_data[7];
                    edge_count <= 4'd0;
                    div_count  <= {DW{1'b0}};
                end
            end else if (div_count == HALF_DIV-1) begin
                div_count <= {DW{1'b0}};
                if (!sclk) begin
                    sclk <= 1'b1;
                    rx_shift <= {rx_shift[6:0], miso};
                    edge_count <= edge_count + 1'b1;
                end else begin
                    sclk <= 1'b0;
                    if (edge_count == 4'd8) begin
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        rx_data <= rx_shift;
                        mosi    <= 1'b0;
                    end else begin
                        tx_shift <= {tx_shift[6:0], 1'b0};
                        mosi     <= tx_shift[6];
                    end
                end
            end else begin
                div_count <= div_count + 1'b1;
            end
        end
    end
endmodule
