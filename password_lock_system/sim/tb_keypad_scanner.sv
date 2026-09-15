`timescale 1ns/1ps
// 矩阵键盘测试：验证长按只触发一次、多键抑制，以及 16 个物理位置到键码的完整映射。
module tb_keypad_scanner;
    reg test_pass=0;
    reg clk=0,rst=1;
    reg [15:0] pressed_keys=0;
    reg [3:0] expected_code=0;
    reg [7:0] scenario=0;
    reg [3:0] row_n;
    wire [3:0] col_n;
    wire event_valid;
    wire [3:0] event_code;
    integer events=0;
    integer i;

    always #5 clk=~clk;
    // 根据 DUT 当前拉低的列，从 pressed_keys 模型生成低有效行输入，等效于真实按键闭合。
    always @(*) begin
        case(col_n)
            4'b1110: row_n=~pressed_keys[3:0];
            4'b1101: row_n=~pressed_keys[7:4];
            4'b1011: row_n=~pressed_keys[11:8];
            4'b0111: row_n=~pressed_keys[15:12];
            default: row_n=4'b1111;
        endcase
    end

    // 缩短消抖到 2 个完整扫描周期以加速仿真，不改变扫描算法。
    keypad_scanner #(.CLOCK_HZ(4000),.COLUMN_TICK_HZ(1000),.DEBOUNCE_SCANS(2)) dut(
       .clk(clk),.rst(rst),.row_n(row_n),.col_n(col_n),
       .event_valid(event_valid),.event_code(event_code));

    always @(posedge clk) if(event_valid) begin
        if(event_code!==expected_code)
            $fatal(1,"wrong key code expected=%h actual=%h scenario=%0d",expected_code,event_code,scenario);
        events=events+1;
    end

    function [3:0] expected_for_bit(input integer bit_index);
        case(bit_index)
             0:expected_for_bit=4'h1;  1:expected_for_bit=4'h4;
             2:expected_for_bit=4'h7;  3:expected_for_bit=4'hE;
             4:expected_for_bit=4'h2;  5:expected_for_bit=4'h5;
             6:expected_for_bit=4'h8;  7:expected_for_bit=4'h0;
             8:expected_for_bit=4'h3;  9:expected_for_bit=4'h6;
            10:expected_for_bit=4'h9; 11:expected_for_bit=4'hF;
            12:expected_for_bit=4'hA; 13:expected_for_bit=4'hB;
            14:expected_for_bit=4'hC; default:expected_for_bit=4'hD;
        endcase
    endfunction

    task release_all; begin pressed_keys=0;repeat(80)@(negedge clk);end endtask

    // events 是累计事件数：多键阶段前后不应增加，逐键测试时每个位置恰好增加一次。
    initial begin
        repeat(4)@(negedge clk);rst=0;

        scenario=1;expected_code=4'hA;pressed_keys=16'h1000;
        repeat(200)@(negedge clk);
        if(events!=1)$fatal(1,"long press generated %0d events",events);
        release_all();

        scenario=2;pressed_keys=16'h0021;
        repeat(120)@(negedge clk);
        if(events!=1)$fatal(1,"multi-key sample generated an event");
        release_all();

        for(i=0;i<16;i=i+1) begin
            scenario=8'd16+i;
            expected_code=expected_for_bit(i);
            pressed_keys=16'h0001<<i;
            repeat(80)@(negedge clk);
            release_all();
            if(events!=i+2)$fatal(1,"key %0d event missing events=%0d",i,events);
        end
        test_pass=1;$display("PASS tb_keypad_scanner");$finish;
    end
endmodule
