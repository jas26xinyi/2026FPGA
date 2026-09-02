`timescale 1ns/1ps
module tb_flash_default_fail;
 reg test_pass=0;
 reg clk=0,rst=1,save=0;wire sclk,mosi,cs,wp,hold,init_done,save_done,save_ok,fault;wire[15:0]password;
 always #5 clk=~clk;
 w25q64_password_store #(.CLOCK_HZ(1000),.SPI_HALF_DIV(1),.ERASE_TIMEOUT_CYCLES(100),.PROGRAM_TIMEOUT_CYCLES(50)) dut(
  .clk(clk),.rst(rst),.save_request(save),.save_password(16'h5678),.flash_miso(1'b1),
  .flash_sclk(sclk),.flash_mosi(mosi),.flash_cs_n(cs),.flash_wp_n(wp),.flash_hold_n(hold),
  .init_done(init_done),.current_password(password),.save_done(save_done),.save_success(save_ok),.flash_fault(fault));
 initial begin repeat(4)@(negedge clk);rst=0;wait(init_done);@(negedge clk);
   if(password!==16'h1234)$fatal(1,"empty flash default %h",password);
   save=1;@(negedge clk);save=0;wait(save_done);@(negedge clk);
   if(save_ok)$fatal(1,"all-ones MISO must not verify save");
   if(password!==16'h1234)$fatal(1,"failed save changed password");
   test_pass=1;$display("PASS tb_flash_default_fail");$finish;end
endmodule
