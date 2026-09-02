`timescale 1ns/1ps
module tb_frame_capture;
    reg test_pass=0;
    reg pclk=0,rst=1,start=0,abort=0,vsync=0,href=0; reg [7:0] data=0;
    wire we,busy,done,error;wire[1:0]bank;wire[14:0]addr;wire[15:0]wdata;
    integer writes=0; integer expected_bank=0;
    always #5 pclk=~pclk;
    frame_capture_4 #(.FRAME_WORDS(4)) dut(.pclk(pclk),.rst(rst),.capture_start(start),
      .abort_capture(abort),.vsync(vsync),.href(href),.pixel_data(data),.write_enable(we),
      .write_bank(bank),.write_address(addr),.write_data(wdata),.busy(busy),.done(done),.error(error));
    always @(posedge pclk) if(we) begin
      if(bank!==expected_bank[1:0])$fatal(1,"bank mismatch");
      if(addr!==(writes%4))$fatal(1,"address mismatch %0d",addr);
      writes=writes+1;
    end
    task sync_start; begin vsync=1;repeat(2)@(negedge pclk);vsync=0;repeat(2)@(negedge pclk);end endtask
    task frame(input integer words); integer i; begin
      href=1;for(i=0;i<words*2;i=i+1)begin data=i;@(negedge pclk);end href=0;
      repeat(2)@(negedge pclk);vsync=1;repeat(2)@(negedge pclk);vsync=0;repeat(2)@(negedge pclk);
    end endtask
    initial begin
      repeat(3)@(negedge pclk);rst=0;start=1;@(negedge pclk);start=0;
      sync_start();
      frame(3); // bad frame, retry bank 0
      writes=0; expected_bank=0; frame(4);
      expected_bank=1;frame(4);expected_bank=2;frame(4);expected_bank=3;frame(4);
      repeat(3)@(negedge pclk);if(!done && busy)$fatal(1,"capture did not finish");
      if(writes!=16)$fatal(1,"expected 16 retained-frame writes, got %0d",writes);
      test_pass=1;$display("PASS tb_frame_capture");$finish;
    end
endmodule
