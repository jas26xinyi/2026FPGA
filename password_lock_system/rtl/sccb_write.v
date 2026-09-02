`timescale 1ns/1ps

module sccb_write #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer SCCB_HZ  = 100_000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [15:0] reg_address,
    input  wire [7:0]  reg_value,
    output reg         scl,
    inout  wire        sda,
    output reg         busy,
    output reg         done,
    output reg         nack
);
    localparam integer DIVISOR = CLOCK_HZ/(SCCB_HZ*2);
    localparam integer DW = (DIVISOR <= 2) ? 1 : $clog2(DIVISOR);
    localparam [3:0] I_IDLE=0,I_START_A=1,I_START_B=2,I_BIT_LOW=3,
                     I_BIT_HIGH=4,I_ACK_LOW=5,I_ACK_HIGH=6,
                     I_STOP_LOW=7,I_STOP_HIGH=8,I_STOP_RELEASE=9;
    reg [3:0] state;
    reg [DW-1:0] divider;
    reg sda_low;
    reg [1:0] byte_index;
    reg [2:0] bit_index;
    reg [31:0] payload;
    wire tick = (divider == DIVISOR-1);
    wire tx_bit = payload[31 - byte_index*8 - bit_index];
    assign sda = sda_low ? 1'b0 : 1'bz;

    always @(posedge clk) begin
        if (rst) begin
            state<=I_IDLE; divider<=0; scl<=1; sda_low<=0; busy<=0;
            done<=0; nack<=0; byte_index<=0; bit_index<=0; payload<=0;
        end else begin
            done <= 1'b0;
            if (state == I_IDLE) divider <= 0;
            else if (tick) divider <= 0;
            else divider <= divider + 1'b1;

            if (state == I_IDLE && start) begin
                payload <= {8'h78,reg_address,reg_value};
                byte_index <= 0;
                bit_index <= 0;
                busy <= 1;
                nack <= 0;
                state <= I_START_A;
            end else if (tick) begin
                case (state)
                    I_START_A: begin scl<=1; sda_low<=0; state<=I_START_B; end
                    I_START_B: begin scl<=1; sda_low<=1; state<=I_BIT_LOW; end
                    I_BIT_LOW: begin scl<=0; sda_low<=~tx_bit; state<=I_BIT_HIGH; end
                    I_BIT_HIGH: begin
                        scl<=1;
                        if (bit_index==7) begin bit_index<=0; state<=I_ACK_LOW; end
                        else begin bit_index<=bit_index+1'b1; state<=I_BIT_LOW; end
                    end
                    I_ACK_LOW: begin scl<=0; sda_low<=0; state<=I_ACK_HIGH; end
                    I_ACK_HIGH: begin
                        scl<=1;
                        if (sda) nack<=1;
                        if (byte_index==3) state<=I_STOP_LOW;
                        else begin byte_index<=byte_index+1'b1; state<=I_BIT_LOW; end
                    end
                    I_STOP_LOW: begin scl<=0; sda_low<=1; state<=I_STOP_HIGH; end
                    I_STOP_HIGH: begin scl<=1; sda_low<=1; state<=I_STOP_RELEASE; end
                    I_STOP_RELEASE: begin
                        scl<=1; sda_low<=0; busy<=0; done<=1; state<=I_IDLE;
                    end
                    default: state<=I_IDLE;
                endcase
            end
        end
    end
endmodule
