`timescale 1ns/1ps

module tb_basic_alarm_policy;
    localparam [3:0] ST_USER=4'd2, ST_ERROR=4'd3, ST_ALARM=4'd7;
    reg test_pass=0;
    reg clk=0,rst=1,init_done=0,sw1=0,admin=0,clear=0,key_valid=0,temp_event=0;
    reg [3:0] key_code=0;
    reg [7:0] scenario=0;
    wire capture_start,alarm_active;
    wire [3:0] state;
    wire [2:0] error_count;
    integer capture_pulses=0;

    always #5 clk=~clk;
    always @(posedge clk) if(capture_start) capture_pulses=capture_pulses+1;
    lock_controller #(.CLOCK_HZ(1000),.LOCK_TIMEOUT_S(1),.OPEN_TIMEOUT_S(2),.ERROR_DISPLAY_MS(2)) dut(
        .clk(clk),.rst(rst),.flash_init_done(init_done),.stored_password(16'h1234),
        .flash_fault(1'b0),.sw1_event(sw1),.admin_event(admin),.alarm_clear_event(clear),
        .temporary_event(temp_event),.temporary_password(16'h2468),.temporary_valid(1'b1),
        .key_valid(key_valid),.key_code(key_code),.save_done(1'b0),.save_success(1'b0),
        .save_request(),.save_password(),.capture_start(capture_start),.unlocked(),
        .alarm_active(alarm_active),.state(state),.entry_digits(),.entry_count(),
        .error_count(error_count),.display_fault());

    task pulse(input integer which); begin
        @(negedge clk);if(which==0)sw1=1;if(which==1)admin=1;if(which==2)clear=1;if(which==3)temp_event=1;
        @(negedge clk);sw1=0;admin=0;clear=0;temp_event=0;
    end endtask
    task key(input [3:0] code); begin @(negedge clk);key_code=code;key_valid=1;@(negedge clk);key_valid=0;end endtask
    task wrong_attempt; begin key(1);key(1);key(1);key(1);key(4'hA);end endtask
    task check(input bit ok,input string message); if(!ok)$fatal(1,"FAIL: %s",message); endtask
    integer n;

    initial begin
        scenario=1;repeat(4)@(negedge clk);rst=0;init_done=1;repeat(2)@(negedge clk);pulse(0);
        for(n=1;n<=3;n=n+1)begin
            scenario=n+1;wrong_attempt();#1;
            check(state==ST_ERROR && error_count==n,"Err1..Err3 sequence incorrect");
            repeat(4)@(negedge clk);check(state==ST_USER,"error display did not return to input");
        end
        scenario=5;wrong_attempt();repeat(2)@(negedge clk);
        check(state==ST_ALARM && alarm_active && error_count==4,"fourth error did not alarm");
        check(capture_pulses==1,"alarm did not emit exactly one photo trigger");
        scenario=6;pulse(3);pulse(1);key(4'hA);repeat(2)@(negedge clk);
        check(state==ST_ALARM,"non-KEY2 input bypassed alarm");
        scenario=7;pulse(2);repeat(2)@(negedge clk);
        check(state==ST_USER && !alarm_active && error_count==0,"KEY2 clear policy failed");
        scenario=8;wrong_attempt();#1;
        check(state==ST_ERROR && error_count==1,"post-alarm count did not restart at Err1");
        test_pass=1;$display("PASS tb_basic_alarm_policy");$finish;
    end
endmodule
