`timescale 1ns/1ps

module tb_basic_entry_timeout;
    localparam [3:0] ST_WAIT=4'd1, ST_USER=4'd2, ST_OPEN=4'd4;
    reg test_pass=0;
    reg clk=0,rst=1,init_done=0,sw1=0,key_valid=0;
    reg [3:0] key_code=0;
    reg [7:0] scenario=0;
    wire unlocked,alarm_active;
    wire [3:0] state;
    wire [15:0] entry_digits;
    wire [2:0] entry_count,error_count;

    always #5 clk=~clk;
    lock_controller #(.CLOCK_HZ(1000),.LOCK_TIMEOUT_S(1),.OPEN_TIMEOUT_S(2),.ERROR_DISPLAY_MS(2)) dut(
        .clk(clk),.rst(rst),.flash_init_done(init_done),.stored_password(16'h1234),
        .flash_fault(1'b0),.sw1_event(sw1),.admin_event(1'b0),.alarm_clear_event(1'b0),
        .temporary_event(1'b0),.temporary_password(16'h0000),.temporary_valid(1'b0),
        .key_valid(key_valid),.key_code(key_code),.save_done(1'b0),.save_success(1'b0),
        .save_request(),.save_password(),.capture_start(),.unlocked(unlocked),
        .alarm_active(alarm_active),.state(state),.entry_digits(entry_digits),
        .entry_count(entry_count),.error_count(error_count),.display_fault());

    task pulse_sw1; begin @(negedge clk);sw1=1;@(negedge clk);sw1=0;end endtask
    task key(input [3:0] code); begin
        @(negedge clk);key_code=code;key_valid=1;
        @(negedge clk);key_valid=0;
    end endtask
    task digits(input [15:0] value); begin
        key(value[15:12]);key(value[11:8]);key(value[7:4]);key(value[3:0]);
    end endtask
    task check(input bit ok,input string message); if(!ok)$fatal(1,"FAIL: %s",message); endtask

    initial begin
        scenario=1; repeat(4)@(negedge clk);rst=0;init_done=1;repeat(2)@(negedge clk);
        check(state==ST_WAIT,"boot/init did not reach PASS wait state");

        scenario=2; pulse_sw1();key(1);key(2);key(4'hA);
        check(state==ST_USER && entry_count==2,"incomplete confirm must be ignored");
        key(4'hB);check(entry_count==1 && entry_digits==16'h0001,"backspace failed");
        key(2);key(3);key(4);key(9);
        check(entry_count==4 && entry_digits==16'h1234,"four-digit limit failed");

        scenario=3;key(4'hA);repeat(2)@(negedge clk);
        check(state==ST_OPEN && unlocked,"1234 did not unlock");
        repeat(2005)@(negedge clk);
        check(state==ST_WAIT && !unlocked,"16-second-equivalent open timeout failed");

        scenario=4;pulse_sw1();repeat(1005)@(negedge clk);
        check(state==ST_WAIT,"8-second-equivalent input timeout failed");

        scenario=5;pulse_sw1();digits(16'h1234);key(4'hA);repeat(2)@(negedge clk);
        key(4'hA);repeat(2)@(negedge clk);
        check(state==ST_WAIT,"A did not lock immediately from OPEN");
        test_pass=1;$display("PASS tb_basic_entry_timeout");$finish;
    end
endmodule
