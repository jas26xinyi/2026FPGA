`timescale 1ns/1ps
module tb_keypad_scanner;
    reg test_pass=0;
    reg clk=0,rst=1,pressed=0;
    wire [3:0] col_n;
    wire [3:0] row_n=(pressed && col_n==4'b0111)?4'b1110:4'b1111;
    wire event_valid; wire [3:0] event_code;
    integer events=0;
    always #5 clk=~clk;
    keypad_scanner #(.CLOCK_HZ(4000),.COLUMN_TICK_HZ(1000),.DEBOUNCE_SCANS(2)) dut(
       .clk(clk),.rst(rst),.row_n(row_n),.col_n(col_n),.event_valid(event_valid),.event_code(event_code));
    always @(posedge clk) if(event_valid) begin
      if(event_code!==4'hA) $fatal(1,"wrong key code %h",event_code);
      events=events+1;
    end
    initial begin
      repeat(4)@(negedge clk);rst=0;pressed=1;
      repeat(100)@(negedge clk);if(events!=1)$fatal(1,"long press generated %0d events",events);
      pressed=0;repeat(80)@(negedge clk);pressed=1;repeat(80)@(negedge clk);
      if(events!=2)$fatal(1,"second press not armed events=%0d",events);
      test_pass=1;$display("PASS tb_keypad_scanner");$finish;
    end
endmodule
