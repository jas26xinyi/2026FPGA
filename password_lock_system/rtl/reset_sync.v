`timescale 1ns/1ps

// 复位同步器：arst 置位时异步立即复位；arst 释放后经过三级寄存器同步退出。
// “异步置位、同步释放”可保证全系统快速进入复位且不会在时钟边沿附近杂乱退出。
module reset_sync (
    input  wire clk,
    input  wire arst,
    output wire rst
);
    // ASYNC_REG 属性帮助布局工具把同步寄存器放得更近，降低亚稳态风险。
    (* ASYNC_REG = "TRUE" *) reg [2:0] sync_ff;
    always @(posedge clk or posedge arst) begin
        if (arst)
            sync_ff <= 3'b111;
        else
            sync_ff <= {sync_ff[1:0], 1'b0};
    end
    assign rst = sync_ff[2];
endmodule
