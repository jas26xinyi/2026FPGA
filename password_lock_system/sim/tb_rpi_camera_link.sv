`timescale 1ns/1ps

module tb_rpi_camera_link;
    localparam integer CLOCK_HZ = 800;
    localparam integer BAUD = 100;
    localparam integer CLKS_PER_BIT = 8;
    reg clk=0,rst=1,photo_trigger=0,uart_rx=1;
    wire uart_tx,link_waiting;
    integer tx_starts=0;
    reg test_pass=0;

    always #5 clk=~clk;
    always @(negedge uart_tx) tx_starts = tx_starts + 1;

    rpi_camera_link #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD),.RETRY_CYCLES(200)) dut(
        .clk(clk),.rst(rst),.photo_trigger(photo_trigger),.uart_rx(uart_rx),
        .uart_tx(uart_tx),.link_waiting(link_waiting));

    task send_uart_byte(input [7:0] value);
        integer i;
        begin
            uart_rx=0; repeat(CLKS_PER_BIT) @(posedge clk);
            for(i=0;i<8;i=i+1) begin
                uart_rx=value[i]; repeat(CLKS_PER_BIT) @(posedge clk);
            end
            uart_rx=1; repeat(CLKS_PER_BIT) @(posedge clk);
        end
    endtask

    initial begin
        repeat(5) @(posedge clk); rst=0;
        @(posedge clk); photo_trigger=1;
        @(posedge clk); photo_trigger=0;
        repeat(10) @(posedge clk);
        if(!link_waiting || tx_starts==0) $fatal(1,"alarm request did not start");

        send_uart_byte("A"); send_uart_byte("C");
        send_uart_byte("K"); send_uart_byte(8'h0a);
        repeat(20) @(posedge clk);
        if(link_waiting) $fatal(1,"ACK did not clear pending request");

        @(posedge clk); photo_trigger=1;
        @(posedge clk); photo_trigger=0;
        repeat(900) @(posedge clk);
        if(tx_starts < 3) $fatal(1,"unacknowledged request was not retried");

        test_pass=1;
        $display("PASS tb_rpi_camera_link");
        $finish;
    end
endmodule
