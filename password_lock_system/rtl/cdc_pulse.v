`timescale 1ns/1ps

module cdc_pulse (
    input wire src_clk,
    input wire src_rst,
    input wire src_pulse,
    input wire dst_clk,
    input wire dst_rst,
    output reg dst_pulse
);
    reg toggle;
    (* ASYNC_REG = "TRUE" *) reg sync0, sync1;
    reg sync1_d;
    always @(posedge src_clk) begin
        if (src_rst) toggle<=0;
        else if (src_pulse) toggle<=~toggle;
    end
    always @(posedge dst_clk) begin
        if (dst_rst) begin sync0<=0; sync1<=0; sync1_d<=0; dst_pulse<=0; end
        else begin
            sync0<=toggle; sync1<=sync0; sync1_d<=sync1;
            dst_pulse<=sync1^sync1_d;
        end
    end
endmodule
