`timescale 1ns/1ps

// Reliable, human-readable UART event link to a Raspberry Pi camera service.
// The message ALARM\n is repeated until the Pi replies ACK\n. The request is
// latched independently of alarm_active, so KEY2 cannot cancel an in-flight
// photo request.
module rpi_camera_link #(
    parameter integer CLOCK_HZ     = 50_000_000,
    parameter integer BAUD         = 115_200,
    parameter integer RETRY_CYCLES = 25_000_000
) (
    input  wire clk,
    input  wire rst,
    input  wire photo_trigger,
    input  wire uart_rx,
    output wire uart_tx,
    output reg  link_waiting
);
    reg tx_send;
    reg [7:0] tx_data;
    wire tx_busy,tx_done;
    wire [7:0] rx_data;
    wire rx_valid;
    reg [2:0] message_index;
    reg message_active;
    reg byte_issued;
    reg [31:0] retry_count;
    reg [2:0] ack_state;

    uart_tx_byte #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) u_tx(
        .clk(clk),.rst(rst),.send(tx_send),.data(tx_data),
        .tx(uart_tx),.busy(tx_busy),.done(tx_done));
    uart_rx_byte #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) u_rx(
        .clk(clk),.rst(rst),.rx(uart_rx),.data(rx_data),.valid(rx_valid));

    function [7:0] alarm_byte;
        input [2:0] index;
        begin
            case (index)
                3'd0: alarm_byte = "A";
                3'd1: alarm_byte = "L";
                3'd2: alarm_byte = "A";
                3'd3: alarm_byte = "R";
                3'd4: alarm_byte = "M";
                default: alarm_byte = 8'h0a;
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            tx_send        <= 1'b0;
            tx_data        <= 8'd0;
            message_index  <= 3'd0;
            message_active <= 1'b0;
            byte_issued    <= 1'b0;
            retry_count    <= 32'd0;
            ack_state      <= 3'd0;
            link_waiting   <= 1'b0;
        end else begin
            tx_send <= 1'b0;

            if (photo_trigger) begin
                link_waiting   <= 1'b1;
                message_active <= 1'b1;
                message_index  <= 3'd0;
                byte_issued    <= 1'b0;
                retry_count    <= 32'd0;
                ack_state      <= 3'd0;
            end

            if (rx_valid) begin
                case (ack_state)
                    3'd0: ack_state <= (rx_data == "A") ? 3'd1 : 3'd0;
                    3'd1: ack_state <= (rx_data == "C") ? 3'd2 :
                                           ((rx_data == "A") ? 3'd1 : 3'd0);
                    3'd2: ack_state <= (rx_data == "K") ? 3'd3 :
                                           ((rx_data == "A") ? 3'd1 : 3'd0);
                    3'd3: begin
                        ack_state <= (rx_data == 8'h0a) ? 3'd4 :
                                     ((rx_data == "A") ? 3'd1 : 3'd0);
                        if (rx_data == 8'h0a) begin
                            link_waiting <= 1'b0;
                            retry_count  <= 32'd0;
                        end
                    end
                    default: ack_state <= 3'd0;
                endcase
            end

            if (message_active) begin
                if (!byte_issued && !tx_busy) begin
                    tx_data     <= alarm_byte(message_index);
                    tx_send     <= 1'b1;
                    byte_issued <= 1'b1;
                end
                if (tx_done) begin
                    byte_issued <= 1'b0;
                    if (message_index == 3'd5) begin
                        message_active <= 1'b0;
                        message_index  <= 3'd0;
                        retry_count    <= 32'd0;
                    end else begin
                        message_index <= message_index + 1'b1;
                    end
                end
            end else if (link_waiting) begin
                if (retry_count >= RETRY_CYCLES-1) begin
                    retry_count    <= 32'd0;
                    message_active <= 1'b1;
                    message_index  <= 3'd0;
                    byte_issued    <= 1'b0;
                end else retry_count <= retry_count + 1'b1;
            end
        end
    end
endmodule
