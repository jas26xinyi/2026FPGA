`timescale 1ns/1ps

module video_timing_640x480 (
    input wire pixel_clk,
    input wire rst,
    output reg [9:0] x,
    output reg [9:0] y,
    output wire active,
    output wire hsync,
    output wire vsync
);
    localparam H_ACTIVE=640,H_FRONT=16,H_SYNC=96,H_BACK=48,H_TOTAL=800;
    localparam V_ACTIVE=480,V_FRONT=10,V_SYNC=2,V_BACK=33,V_TOTAL=525;
    always @(posedge pixel_clk) begin
        if (rst) begin x<=0; y<=0; end
        else if (x==H_TOTAL-1) begin
            x<=0;
            if (y==V_TOTAL-1) y<=0; else y<=y+1'b1;
        end else x<=x+1'b1;
    end
    assign active=(x<H_ACTIVE)&&(y<V_ACTIVE);
    assign hsync=~((x>=H_ACTIVE+H_FRONT)&&(x<H_ACTIVE+H_FRONT+H_SYNC));
    assign vsync=~((y>=V_ACTIVE+V_FRONT)&&(y<V_ACTIVE+V_FRONT+V_SYNC));
endmodule
