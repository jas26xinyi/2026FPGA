`timescale 1ns/1ps

module capture_manager #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer TIMEOUT_S = 2
) (
    input wire sys_clk,
    input wire sys_rst,
    input wire pclk,
    input wire pclk_rst,
    input wire start,
    input wire camera_init_error,
    input wire vsync,
    input wire href,
    input wire [7:0] pixel_data,
    output wire wr_en,
    output wire [1:0] wr_bank,
    output wire [14:0] wr_addr,
    output wire [15:0] wr_data,
    output reg busy,
    output reg frames_valid,
    output reg capture_error
);
    localparam integer TIMEOUT_CYCLES=CLOCK_HZ*TIMEOUT_S;
    reg [31:0] timeout_count;
    reg abort_sys;
    wire start_pclk, abort_pclk;
    wire cap_busy_pclk, done_pclk, error_pclk;
    wire done_sys, error_sys;
    cdc_pulse u_start(.src_clk(sys_clk),.src_rst(sys_rst),.src_pulse(start),
        .dst_clk(pclk),.dst_rst(pclk_rst),.dst_pulse(start_pclk));
    cdc_pulse u_abort(.src_clk(sys_clk),.src_rst(sys_rst),.src_pulse(abort_sys),
        .dst_clk(pclk),.dst_rst(pclk_rst),.dst_pulse(abort_pclk));
    cdc_pulse u_done(.src_clk(pclk),.src_rst(pclk_rst),.src_pulse(done_pclk),
        .dst_clk(sys_clk),.dst_rst(sys_rst),.dst_pulse(done_sys));
    cdc_pulse u_error(.src_clk(pclk),.src_rst(pclk_rst),.src_pulse(error_pclk),
        .dst_clk(sys_clk),.dst_rst(sys_rst),.dst_pulse(error_sys));

    frame_capture_4 u_capture(
        .pclk(pclk),.rst(pclk_rst),.capture_start(start_pclk),.abort_capture(abort_pclk),
        .vsync(vsync),.href(href),.pixel_data(pixel_data),
        .write_enable(wr_en),.write_bank(wr_bank),.write_address(wr_addr),
        .write_data(wr_data),.busy(cap_busy_pclk),.done(done_pclk),.error(error_pclk)
    );
    always @(posedge sys_clk) begin
        if(sys_rst) begin busy<=0; frames_valid<=0; capture_error<=0; timeout_count<=0; abort_sys<=0; end
        else begin
            abort_sys<=0;
            if(start) begin
                busy<=1; frames_valid<=0; capture_error<=camera_init_error; timeout_count<=0;
                if(camera_init_error) busy<=0;
            end else if(busy) begin
                if(done_sys) begin busy<=0; frames_valid<=1; capture_error<=0; end
                else if(error_sys) begin busy<=0; capture_error<=1; end
                else if(timeout_count==TIMEOUT_CYCLES-1) begin
                    busy<=0; capture_error<=1; abort_sys<=1;
                end else timeout_count<=timeout_count+1'b1;
            end
        end
    end
endmodule
