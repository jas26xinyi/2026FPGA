`timescale 1ns/1ps

module tb_sevenseg_display;
    reg clk=0, rst=1;
    reg [3:0] state=1;
    reg [15:0] entry_digits=16'h0000;
    reg [2:0] entry_count=0, error_count=0;
    reg display_fault=0;
    reg [15:0] temporary_password=16'h2468;
    wire [7:0] seg_n, digit_sel;
    reg test_pass=0;

    sevenseg_display #(.CLOCK_HZ(8000)) dut(
        .clk(clk),.rst(rst),.state(state),.entry_digits(entry_digits),
        .entry_count(entry_count),.error_count(error_count),
        .temporary_password(temporary_password),.display_fault(display_fault),
        .seg_n(seg_n),.digit_sel(digit_sel));

    always #5 clk=~clk;

    function integer count_zeroes;
        input [7:0] value;
        integer i;
        begin
            count_zeroes=0;
            for(i=0;i<8;i=i+1)
                if(value[i]===1'b0) count_zeroes=count_zeroes+1;
        end
    endfunction

    initial begin
        repeat(2) @(posedge clk);
        rst=0;
        @(negedge clk);
        if(count_zeroes(digit_sel)!=1) $fatal(1,"digit select must be one-hot active-low");
        @(negedge clk);
        if(count_zeroes(digit_sel)!=1) $fatal(1,"digit scan enabled multiple digits");
        state=8;#1;
        if(dut.chars[3]!==4'd2 || dut.chars[2]!==4'd4 ||
           dut.chars[1]!==4'd6 || dut.chars[0]!==4'd8)
            $fatal(1,"temporary password digits are not displayed");
        test_pass=1;
        $display("PASS tb_sevenseg_display");
        $finish;
    end
endmodule
