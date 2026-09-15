`timescale 1ns/1ps

// 数码管测试：验证低有效位选始终 one-hot，并核对每个状态的文字及输入/临时密码数字。
module tb_sevenseg_display;
    localparam [4:0] CH_BLANK=5'h10, CH_P=5'h11, CH_A=5'h12, CH_S=5'h13,
                     CH_E=5'h14, CH_T=5'h15, CH_R=5'h16, CH_O=5'h17,
                     CH_N=5'h18, CH_L=5'h19, CH_F=5'h1A, CH_I=5'h1B,
                     CH_U=5'h1C, CH_M=5'h1D;
    reg clk=0,rst=1;
    reg [3:0] state=0;
    reg [15:0] entry_digits=16'h1234;
    reg [2:0] entry_count=0,error_count=3;
    reg display_fault=0;
    reg [15:0] temporary_password=16'h2468;
    reg [7:0] scenario=0;
    wire [7:0] seg_n,digit_sel;
    reg test_pass=0;
    integer i;

    sevenseg_display #(.CLOCK_HZ(8000)) dut(
        .clk(clk),.rst(rst),.state(state),.entry_digits(entry_digits),
        .entry_count(entry_count),.error_count(error_count),
        .temporary_password(temporary_password),.display_fault(display_fault),
        .seg_n(seg_n),.digit_sel(digit_sel));

    always #5 clk=~clk;

    // 低有效位选中 0 的数量必须恒为 1，防止多位同时点亮造成串光。
    function integer count_zeroes(input [7:0] value);
        integer bit_index;
        begin
            count_zeroes=0;
            for(bit_index=0;bit_index<8;bit_index=bit_index+1)
                if(value[bit_index]===1'b0)count_zeroes=count_zeroes+1;
        end
    endfunction

    // 直接检查 DUT 内部字符缓存，比只看复用后的瞬时 seg_n 更适合验证完整单词。
    task check_word(input [4:0] c7,input [4:0] c6,input [4:0] c5,input [4:0] c4);
        if(dut.chars[7]!==c7 || dut.chars[6]!==c6 || dut.chars[5]!==c5 || dut.chars[4]!==c4)
            $fatal(1,"status word mismatch state=%0d",state);
    endtask

    // scenario=1~10 对应 INIT/PASS/输入/Err/OPEN/SET/SAVE/ALAR/TEMP/FErr。
    initial begin
        repeat(2)@(posedge clk);rst=0;
        for(i=0;i<16;i=i+1)begin
            @(negedge clk);
            if(count_zeroes(digit_sel)!=1)$fatal(1,"digit select is not one-hot active-low");
        end

        scenario=1;state=0;#1;check_word(CH_I,CH_N,CH_I,CH_T);
        scenario=2;state=1;#1;check_word(CH_P,CH_A,CH_S,CH_S);
        scenario=3;state=2;entry_count=4;#1;check_word(CH_P,CH_A,CH_S,CH_S);
        if(dut.chars[3]!==1 || dut.chars[2]!==2 || dut.chars[1]!==3 || dut.chars[0]!==4)
            $fatal(1,"entered password digits are not displayed");
        scenario=4;entry_count=0;state=3;#1;check_word(CH_E,CH_R,CH_R,5'd3);
        scenario=5;state=4;#1;check_word(CH_O,CH_P,CH_E,CH_N);
        scenario=6;state=5;#1;check_word(CH_S,CH_E,CH_T,CH_BLANK);
        scenario=7;state=6;#1;check_word(CH_S,CH_A,CH_U,CH_E);
        scenario=8;state=7;#1;check_word(CH_A,CH_L,CH_A,CH_R);
        scenario=9;state=8;#1;check_word(CH_T,CH_E,CH_M,CH_P);
        if(dut.chars[3]!==2 || dut.chars[2]!==4 || dut.chars[1]!==6 || dut.chars[0]!==8)
            $fatal(1,"temporary password digits are not displayed");
        scenario=10;display_fault=1;#1;check_word(CH_F,CH_E,CH_R,CH_R);
        test_pass=1;$display("PASS tb_sevenseg_display");$finish;
    end
endmodule
