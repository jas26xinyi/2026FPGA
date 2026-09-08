`timescale 1ns/1ps

module tb_basic_admin_save;
    localparam [3:0] ST_WAIT=4'd1, ST_ADMIN=4'd5, ST_SAVE=4'd6;
    reg test_pass=0;
    reg clk=0,rst=1,init_done=0,admin=0,sw1=0,key_valid=0;
    reg save_done=0,save_success=0;
    reg [3:0] key_code=0;
    reg [7:0] scenario=0;
    wire save_request,display_fault;
    wire [15:0] save_password,entry_digits;
    wire [3:0] state;
    wire [2:0] entry_count;

    always #5 clk=~clk;
    lock_controller #(.CLOCK_HZ(1000),.LOCK_TIMEOUT_S(1),.OPEN_TIMEOUT_S(2),.ERROR_DISPLAY_MS(2)) dut(
        .clk(clk),.rst(rst),.flash_init_done(init_done),.stored_password(16'h1234),
        .flash_fault(1'b0),.sw1_event(sw1),.admin_event(admin),.alarm_clear_event(1'b0),
        .temporary_event(1'b0),.temporary_password(16'h0000),.temporary_valid(1'b0),
        .key_valid(key_valid),.key_code(key_code),.save_done(save_done),.save_success(save_success),
        .save_request(save_request),.save_password(save_password),.capture_start(),.unlocked(),
        .alarm_active(),.state(state),.entry_digits(entry_digits),.entry_count(entry_count),
        .error_count(),.display_fault(display_fault));

    task pulse_admin; begin @(negedge clk);admin=1;@(negedge clk);admin=0;end endtask
    task pulse_sw1; begin @(negedge clk);sw1=1;@(negedge clk);sw1=0;end endtask
    task key(input [3:0] code); begin @(negedge clk);key_code=code;key_valid=1;@(negedge clk);key_valid=0;end endtask
    task digits(input [15:0] value); begin key(value[15:12]);key(value[11:8]);key(value[7:4]);key(value[3:0]);end endtask
    task check(input bit ok,input string message); if(!ok)$fatal(1,"FAIL: %s",message); endtask

    initial begin
        scenario=1;repeat(4)@(negedge clk);rst=0;init_done=1;repeat(2)@(negedge clk);
        scenario=2;pulse_admin();check(state==ST_ADMIN,"KEY1 did not enter SET");
        digits(16'h5678);key(4'hA);#1;
        check(state==ST_SAVE && save_request && save_password==16'h5678,"save request incorrect");
        scenario=3;@(negedge clk);save_success=1;save_done=1;@(negedge clk);save_done=0;save_success=0;
        repeat(2)@(negedge clk);check(state==ST_WAIT && !display_fault,"successful save did not return PASS");

        scenario=4;pulse_admin();digits(16'h2468);key(4'hA);#1;
        check(state==ST_SAVE && save_password==16'h2468,"second save request incorrect");
        @(negedge clk);save_done=1;save_success=0;@(negedge clk);save_done=0;
        repeat(2)@(negedge clk);check(state==ST_WAIT && display_fault,"failed save did not show FErr");
        pulse_sw1();check(!display_fault,"new operation did not clear FErr");

        scenario=5;key(4'hC);repeat(2)@(negedge clk);pulse_admin();repeat(1005)@(negedge clk);
        check(state==ST_WAIT,"SET inactivity timeout failed");
        test_pass=1;$display("PASS tb_basic_admin_save");$finish;
    end
endmodule
