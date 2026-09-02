`timescale 1ns/1ps
module tb_flash_journal;
 reg test_pass=0;
 reg clk=0,rst=1,save=0;reg[15:0]new_password=0;
 wire sclk,mosi,miso,cs,wp,hold,init_done,save_done,save_ok,fault;wire[15:0]password;
 always #5 clk=~clk;
 w25q64_password_store #(.CLOCK_HZ(1000),.SPI_HALF_DIV(2),.ERASE_TIMEOUT_CYCLES(2000),.PROGRAM_TIMEOUT_CYCLES(1000)) dut(
  .clk(clk),.rst(rst),.save_request(save),.save_password(new_password),.flash_miso(miso),
  .flash_sclk(sclk),.flash_mosi(mosi),.flash_cs_n(cs),.flash_wp_n(wp),.flash_hold_n(hold),
  .init_done(init_done),.current_password(password),.save_done(save_done),.save_success(save_ok),.flash_fault(fault));
 w25q64_model flash(.cs_n(cs),.sclk(sclk),.mosi(mosi),.miso(miso));
 task do_save(input[15:0]p);begin new_password=p;save=1;@(negedge clk);save=0;wait(save_done);@(negedge clk);
   if(!save_ok)begin $display("new=%h verify=%h mem=%h%h%h%h",dut.new_record,dut.verify_record,
      flash.mem[4096],flash.mem[4097],flash.mem[4110],flash.mem[4111]);$fatal(1,"save %h failed",p);end
   if(password!==p)$fatal(1,"save not activated");end endtask
 task reboot;begin rst=1;repeat(4)@(negedge clk);rst=0;wait(init_done);repeat(2)@(negedge clk);end endtask
 initial begin
   repeat(4)@(negedge clk);rst=0;wait(init_done);@(negedge clk);
   if(password!==16'h1234)$fatal(1,"default wrong");
   do_save(16'h5678);do_save(16'h2468);reboot();
   if(password!==16'h2468)$fatal(1,"highest generation not selected: %h",password);
   // The second update targets sector 0. Corrupt its commit marker to model
   // interrupted programming; sector 1 must remain a valid older copy.
   flash.mem[15]=8'h00;reboot();
   if(password!==16'h5678)$fatal(1,"did not recover older valid record: %h",password);
   test_pass=1;$display("PASS tb_flash_journal");$finish;
 end
endmodule
