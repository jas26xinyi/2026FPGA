`timescale 1ns/1ps
module tb_mosaic_renderer;
 reg test_pass=0;
 reg clk=0,rst=1;reg[9:0]x=0,y=0;reg active=1,hs=1,vs=1,valid=1,camerr=0;
 wire[14:0]addr;wire[23:0]rgb;wire va,vh,vv;
 always #5 clk=~clk;
 mosaic_renderer dut(.pixel_clk(clk),.rst(rst),.x(x),.y(y),.active(active),.hsync(hs),.vsync(vs),
 .frames_valid(valid),.camera_error(camerr),.read_address(addr),.read_data0(16'hF800),
 .read_data1(16'h07E0),.read_data2(16'h001F),.read_data3(16'hFFFF),.rgb(rgb),
 .video_active(va),.video_hsync(vh),.video_vsync(vv));
 initial begin repeat(3)@(negedge clk);rst=0;x=10;y=20;repeat(2)@(negedge clk);
   if(addr!=1605)$fatal(1,"address mapping %0d",addr);
   x=330;y=20;repeat(2)@(negedge clk);if(rgb!==24'h00FF00)$fatal(1,"bank1 RGB %h",rgb);
   x=10;y=250;repeat(2)@(negedge clk);if(rgb!==24'h0000FF)$fatal(1,"bank2 RGB %h",rgb);
   x=330;y=250;repeat(2)@(negedge clk);if(rgb!==24'hFFFFFF)$fatal(1,"bank3 RGB %h",rgb);
   camerr=1;repeat(2)@(negedge clk);if(rgb[23:16]<8'h80)$fatal(1,"error field not red");
   test_pass=1;$display("PASS tb_mosaic_renderer");$finish;end
endmodule
