`timescale 1ns/1ps

module reset_sync (
    input  wire clk,
    input  wire arst,
    output wire rst
);
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync_ff;
    always @(posedge clk or posedge arst) begin
        if (arst)
            sync_ff <= 3'b111;
        else
            sync_ff <= {sync_ff[1:0], 1'b0};
    end
    assign rst = sync_ff[2];
endmodule
