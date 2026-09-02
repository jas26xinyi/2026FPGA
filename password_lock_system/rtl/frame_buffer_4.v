`timescale 1ns/1ps

module dual_clock_segment_ram (
    input wire wr_clk,input wire wr_en,input wire [10:0] wr_addr,input wire [15:0] wr_data,
    input wire rd_clk,input wire [10:0] rd_addr,output reg [15:0] rd_data
);
    (* ram_style="block" *) reg [15:0] memory[0:2047];
    always @(posedge wr_clk) if(wr_en) memory[wr_addr]<=wr_data;
    always @(posedge rd_clk) rd_data<=memory[rd_addr];
endmodule

module dual_clock_frame_ram #(
    parameter integer FRAME_WORDS = 19200
) (
    input wire wr_clk,input wire wr_en,input wire [14:0] wr_addr,input wire [15:0] wr_data,
    input wire rd_clk,input wire [14:0] rd_addr,output reg [15:0] rd_data
);
    // A 19,200-word frame is ten independent 2Kx16 BRAM segments.
    wire [15:0] q0,q1,q2,q3,q4,q5,q6,q7,q8,q9;
    reg [3:0] rd_segment;
    dual_clock_segment_ram s0(wr_clk,wr_en&&(wr_addr[14:11]==0),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q0);
    dual_clock_segment_ram s1(wr_clk,wr_en&&(wr_addr[14:11]==1),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q1);
    dual_clock_segment_ram s2(wr_clk,wr_en&&(wr_addr[14:11]==2),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q2);
    dual_clock_segment_ram s3(wr_clk,wr_en&&(wr_addr[14:11]==3),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q3);
    dual_clock_segment_ram s4(wr_clk,wr_en&&(wr_addr[14:11]==4),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q4);
    dual_clock_segment_ram s5(wr_clk,wr_en&&(wr_addr[14:11]==5),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q5);
    dual_clock_segment_ram s6(wr_clk,wr_en&&(wr_addr[14:11]==6),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q6);
    dual_clock_segment_ram s7(wr_clk,wr_en&&(wr_addr[14:11]==7),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q7);
    dual_clock_segment_ram s8(wr_clk,wr_en&&(wr_addr[14:11]==8),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q8);
    dual_clock_segment_ram s9(wr_clk,wr_en&&(wr_addr[14:11]==9),wr_addr[10:0],wr_data,rd_clk,rd_addr[10:0],q9);
    always @(posedge rd_clk) rd_segment<=rd_addr[14:11];
    always @(*) case(rd_segment)
        0:rd_data=q0;1:rd_data=q1;2:rd_data=q2;3:rd_data=q3;4:rd_data=q4;
        5:rd_data=q5;6:rd_data=q6;7:rd_data=q7;8:rd_data=q8;9:rd_data=q9;
        default:rd_data=16'h0000;
    endcase
endmodule

module frame_buffer_4 #(
    parameter integer FRAME_WORDS = 19200
) (
    input  wire        wr_clk,
    input  wire        wr_en,
    input  wire [1:0]  wr_bank,
    input  wire [14:0] wr_addr,
    input  wire [15:0] wr_data,
    input  wire        rd_clk,
    input  wire [14:0] rd_addr,
    output wire [15:0] rd_data0,
    output wire [15:0] rd_data1,
    output wire [15:0] rd_data2,
    output wire [15:0] rd_data3
);
    dual_clock_frame_ram #(.FRAME_WORDS(FRAME_WORDS)) u_bank0(
        .wr_clk(wr_clk),.wr_en(wr_en && wr_bank==0),.wr_addr(wr_addr),.wr_data(wr_data),
        .rd_clk(rd_clk),.rd_addr(rd_addr),.rd_data(rd_data0));
    dual_clock_frame_ram #(.FRAME_WORDS(FRAME_WORDS)) u_bank1(
        .wr_clk(wr_clk),.wr_en(wr_en && wr_bank==1),.wr_addr(wr_addr),.wr_data(wr_data),
        .rd_clk(rd_clk),.rd_addr(rd_addr),.rd_data(rd_data1));
    dual_clock_frame_ram #(.FRAME_WORDS(FRAME_WORDS)) u_bank2(
        .wr_clk(wr_clk),.wr_en(wr_en && wr_bank==2),.wr_addr(wr_addr),.wr_data(wr_data),
        .rd_clk(rd_clk),.rd_addr(rd_addr),.rd_data(rd_data2));
    dual_clock_frame_ram #(.FRAME_WORDS(FRAME_WORDS)) u_bank3(
        .wr_clk(wr_clk),.wr_en(wr_en && wr_bank==3),.wr_addr(wr_addr),.wr_data(wr_data),
        .rd_clk(rd_clk),.rd_addr(rd_addr),.rd_data(rd_data3));
endmodule
