`timescale 1ns/1ps

module ov5640_initializer #(
    parameter integer CLOCK_HZ = 50_000_000
) (
    input  wire clk,
    input  wire rst,
    output wire sccb_scl,
    inout  wire sccb_sda,
    output reg  camera_pwdn,
    output reg  camera_reset_n,
    output reg  init_done,
    output reg  init_error
);
    localparam integer STARTUP_CYCLES = CLOCK_HZ/100; // 10 ms
    localparam integer RESET_DELAY_CYCLES = CLOCK_HZ/200; // 5 ms
    localparam [2:0] ST_POWER=0,ST_WRITE=1,ST_WAIT=2,ST_DELAY=3,ST_DONE=4,ST_FAIL=5;
    reg [2:0] state;
    reg [8:0] index;
    reg [1:0] retry_count;
    reg [31:0] delay_count;
    reg write_start;
    wire write_busy, write_done, write_nack;
    wire [15:0] rom_address;
    wire [7:0] rom_value;
    wire rom_last;

    ov5640_reg_table u_table(.index(index),.address(rom_address),.value(rom_value),.last(rom_last));
    sccb_write #(.CLOCK_HZ(CLOCK_HZ),.SCCB_HZ(100_000)) u_write(
        .clk(clk),.rst(rst),.start(write_start),.reg_address(rom_address),
        .reg_value(rom_value),.scl(sccb_scl),.sda(sccb_sda),
        .busy(write_busy),.done(write_done),.nack(write_nack)
    );

    always @(posedge clk) begin
        if (rst) begin
            state<=ST_POWER; index<=0; retry_count<=0; delay_count<=0;
            write_start<=0; camera_pwdn<=1; camera_reset_n<=0;
            init_done<=0; init_error<=0;
        end else begin
            write_start<=0;
            case(state)
                ST_POWER: begin
                    camera_pwdn<=0;
                    camera_reset_n<=1;
                    if (delay_count==STARTUP_CYCLES-1) begin delay_count<=0; state<=ST_WRITE; end
                    else delay_count<=delay_count+1'b1;
                end
                ST_WRITE: if (!write_busy) begin write_start<=1; state<=ST_WAIT; end
                ST_WAIT: if (write_done) begin
                    if (write_nack) begin
                        if (retry_count==2) state<=ST_FAIL;
                        else begin retry_count<=retry_count+1'b1; state<=ST_WRITE; end
                    end else begin
                        retry_count<=0;
                        if (rom_last) state<=ST_DONE;
                        else if (index==1) begin index<=index+1'b1; delay_count<=0; state<=ST_DELAY; end
                        else begin index<=index+1'b1; state<=ST_WRITE; end
                    end
                end
                ST_DELAY: begin
                    if (delay_count==RESET_DELAY_CYCLES-1) begin delay_count<=0; state<=ST_WRITE; end
                    else delay_count<=delay_count+1'b1;
                end
                ST_DONE: begin init_done<=1; init_error<=0; end
                ST_FAIL: begin init_done<=1; init_error<=1; end
                default: state<=ST_POWER;
            endcase
        end
    end
endmodule
