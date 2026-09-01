`timescale 1ns / 1ps
module hx75_hex_7seg(
    input [4:1] sw,                
    input [1:1] key,    
    output [7:0] seg_sel,        //8个数码管选通信号输出
    output reg [7:0] seg_led       //数码管信号输出：0(a),1(b),2(c),3(d),4(e),5(f),6(g),7(dp)
    );
	
	assign seg_sel = 8'b0000_0000;
	
	always @*                                                    
    begin
        case (sw)
            4'h0: seg_led [6:0] = 7'b1000000;
            4'h1: seg_led [6:0] = 7'b1111001;
            4'h2: seg_led [6:0] = 7'b0100100;
            4'h3: seg_led [6:0] = 7'b0110000;
            4'h4: seg_led [6:0] = 7'b0011001;
            4'h5: seg_led [6:0] = 7'b0010010;
            4'h6: seg_led [6:0] = 7'b0000010;
            4'h7: seg_led [6:0] = 7'b1111000;
            4'h8: seg_led [6:0] = 7'b0000000;
            4'h9: seg_led [6:0] = 7'b0010000;
            4'ha: seg_led [6:0] = 7'b0001000;
            4'hb: seg_led [6:0] = 7'b0000011;
            4'hc: seg_led [6:0] = 7'b0100111;
            4'hd: seg_led [6:0] = 7'b0100001;
            4'he: seg_led [6:0] = 7'b0000110;
            4'hf: seg_led [6:0] = 7'b0001110;
        endcase
		
        seg_led [7] = key;
       
	end
endmodule
