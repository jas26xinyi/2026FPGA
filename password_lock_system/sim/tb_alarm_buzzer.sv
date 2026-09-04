`timescale 1ns/1ps
module tb_alarm_buzzer;
    reg test_pass=0;
    reg clk=0,rst=1,alarm_active=0;
    wire buzzer_n,indicator;
    always #5 clk=~clk;

    alarm_buzzer #(.CLOCK_HZ(40),.BEEP_HZ(2),.TONE_HZ(5)) dut(
        .clk(clk),.rst(rst),.alarm_active(alarm_active),
        .buzzer_n(buzzer_n),.indicator(indicator));

    task check(input bit condition,input string message);
      if(!condition) $fatal(1,"FAIL: %s buzzer_n=%b indicator=%b",message,buzzer_n,indicator);
    endtask

    initial begin
      repeat(2) @(negedge clk);rst=0;repeat(2)@(negedge clk);
      check(!buzzer_n && !indicator,"idle output is safe and silent");
      alarm_active=1;#1;
      check(buzzer_n && indicator,"alarm begins with an enabled high phase");
      repeat(4) @(posedge clk);#1;
      check(!buzzer_n && indicator,"audible phase contains an audio carrier");
      repeat(6) @(posedge clk);#1;
      check(!buzzer_n && !indicator,"alarm cadence reaches silent phase");
      repeat(10) @(posedge clk);#1;
      check(buzzer_n && indicator,"alarm cadence repeats audible phase");
      alarm_active=0;#1;
      check(!buzzer_n && !indicator,"clearing alarm silences output immediately");
      test_pass=1;$display("PASS tb_alarm_buzzer");$finish;
    end
endmodule
