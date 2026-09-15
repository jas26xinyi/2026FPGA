`timescale 1ns/1ps
// 蜂鸣器自检：将系统频率缩小到 40 Hz，加速观察响铃载波、静音间隔和立即关闭行为。
module tb_alarm_buzzer;
    reg test_pass=0;
    reg clk=0,rst=1,alarm_active=0;
    wire buzzer_n,indicator;
    always #5 clk=~clk;

    // 仿真参数只为缩短运行时间；实机参数仍由顶层实例采用模块默认值。
    alarm_buzzer #(.CLOCK_HZ(40),.BEEP_HZ(2),.TONE_HZ(5)) dut(
        .clk(clk),.rst(rst),.alarm_active(alarm_active),
        .buzzer_n(buzzer_n),.indicator(indicator));

    task check(input bit condition,input string message);
      if(!condition) $fatal(1,"FAIL: %s buzzer_n=%b indicator=%b",message,buzzer_n,indicator);
    endtask

    // test_pass=1 且出现 PASS 文本表示所有断言均通过；$fatal 会让失败测试立即退出。
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
