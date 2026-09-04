`timescale 1ns/1ps

module tb_temporary_password_generator;
    reg clk=0,rst=1,generate_event=0;
    reg [15:0] stored_password=16'h1234;
    wire [15:0] temporary_password;
    wire temporary_valid;
    reg [15:0] previous_password;
    reg test_pass=0;
    integer i;

    always #5 clk=~clk;
    temporary_password_generator dut(
        .clk(clk),.rst(rst),.generate_event(generate_event),
        .stored_password(stored_password),.temporary_password(temporary_password),
        .temporary_valid(temporary_valid));

    task generate_one;
      begin
        @(negedge clk);generate_event=1;
        @(negedge clk);generate_event=0;
        #1;
      end
    endtask

    task check_decimal;
      begin
        if(temporary_password[15:12]>9 || temporary_password[11:8]>9 ||
           temporary_password[7:4]>9 || temporary_password[3:0]>9)
          $fatal(1,"temporary password is not four decimal digits: %h",temporary_password);
      end
    endtask

    initial begin
      repeat(3)@(negedge clk);rst=0;repeat(3)@(negedge clk);
      if(temporary_valid) $fatal(1,"temporary password must be invalid after reset");
      generate_one();
      if(!temporary_valid) $fatal(1,"KEY3 did not validate temporary password");
      check_decimal();
      if(temporary_password==stored_password) $fatal(1,"temporary password equals fixed password");
      previous_password=temporary_password;
      for(i=0;i<32;i=i+1) begin
        repeat(i%3)@(negedge clk);
        generate_one();
        check_decimal();
        if(temporary_password==previous_password)
          $fatal(1,"replacement repeated previous temporary password");
        if(temporary_password==stored_password)
          $fatal(1,"replacement equals fixed password");
        previous_password=temporary_password;
      end
      rst=1;repeat(2)@(negedge clk);rst=0;#1;
      if(temporary_valid) $fatal(1,"reset did not invalidate temporary password");
      test_pass=1;$display("PASS tb_temporary_password_generator");$finish;
    end
endmodule
