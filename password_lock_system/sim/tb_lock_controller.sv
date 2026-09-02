`timescale 1ns/1ps
module tb_lock_controller;
    reg test_pass=0;
    reg clk=0,rst=1,init_done=0,flash_fault=0,sw1=0,admin=0,clear=0,key_valid=0;
    reg [3:0] key_code=0;
    reg [15:0] stored_password=16'h1234;
    reg save_done=0,save_success=0;
    wire save_request,capture_start,unlocked,alarm_active,display_fault;
    wire [15:0] save_password,entry_digits;
    wire [3:0] state;
    wire [2:0] entry_count,error_count;
    always #5 clk=~clk;
    lock_controller #(.CLOCK_HZ(1000),.LOCK_TIMEOUT_S(1),.OPEN_TIMEOUT_S(2),.ERROR_DISPLAY_MS(2)) dut(
        .clk(clk),.rst(rst),.flash_init_done(init_done),.stored_password(stored_password),
        .flash_fault(flash_fault),.sw1_event(sw1),.admin_event(admin),.alarm_clear_event(clear),
        .key_valid(key_valid),.key_code(key_code),.save_done(save_done),.save_success(save_success),
        .save_request(save_request),.save_password(save_password),.capture_start(capture_start),
        .unlocked(unlocked),.alarm_active(alarm_active),.state(state),.entry_digits(entry_digits),
        .entry_count(entry_count),.error_count(error_count),.display_fault(display_fault));
    task pulse(input integer which);
      begin @(negedge clk); if(which==0)sw1=1; if(which==1)admin=1; if(which==2)clear=1;
            @(negedge clk); sw1=0;admin=0;clear=0; end
    endtask
    task key(input [3:0] code);
      begin @(negedge clk);key_code=code;key_valid=1;@(negedge clk);key_valid=0; end
    endtask
    task digits(input [15:0] value);
      begin key(value[15:12]);key(value[11:8]);key(value[7:4]);key(value[3:0]); end
    endtask
    task check(input bit condition,input string message);
      if(!condition) $fatal(1,"FAIL: %s state=%0d",message,state);
    endtask
    integer n;
    initial begin
      repeat(4) @(negedge clk); rst=0; init_done=1; repeat(2) @(negedge clk);
      check(state==1,"boot to wait");
      pulse(0); digits(16'h1234); key(4'hA); repeat(2) @(negedge clk);
      check(unlocked,"correct password unlocks");
      key(4'hA); repeat(2) @(negedge clk); check(state==1,"A locks immediately");
      pulse(1); digits(16'h5678); key(4'hA);
      check(state==6 && save_password==16'h5678,"admin save request");
      stored_password=16'h5678; save_success=1; save_done=1;
      @(negedge clk);save_done=0;save_success=0;repeat(2)@(negedge clk);
      check(state==1,"save returns wait");
      pulse(0);
      for(n=0;n<4;n=n+1) begin
        digits(16'h1111);key(4'hA);repeat(4)@(negedge clk);
      end
      check(alarm_active,"fourth error alarms");
      pulse(1);repeat(2)@(negedge clk);check(alarm_active,"admin entry key cannot clear alarm");
      key(4'hA);repeat(2)@(negedge clk);check(alarm_active,"keypad cannot clear alarm");
      pulse(2);repeat(2)@(negedge clk);check(!alarm_active && state==1,"KEY2 clears alarm");
      pulse(0);repeat(1005)@(negedge clk);check(state==1,"locked input timeout");
      test_pass=1;$display("PASS tb_lock_controller");$finish;
    end
endmodule
