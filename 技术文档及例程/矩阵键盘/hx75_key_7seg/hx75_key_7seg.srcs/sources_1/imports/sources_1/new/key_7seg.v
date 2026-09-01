`timescale 1ns / 1ps


module hx75_key_7seg(
	input sys_clk,  //50MHZ
	input [3:0] row,  //行
	output [3:0] col,   //列
	output [7:0] seg_sel,    //4个数码管选通信号输出  
	output  [7:0]  seg_led   //段码输出，正电平
    );
	
	wire[3:0] key_value;
	wire key_valid;
	
	key44 U1
	(
		.clk(sys_clk),  //50MHZ
		.reset(1'b0),
		.row(row),  //行
		.col(col),   //列
		.key_valid(key_valid),
		.key_value(key_value)  //键值
	);
	
	hx75_hex_7seg U2( 
		.sw(key_value),  // key
		.key(~key_valid),  //Dot
		.seg_sel(seg_sel),
		.seg_led(seg_led)  
    );	
endmodule
