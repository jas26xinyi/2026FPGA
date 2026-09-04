`timescale 1ns/1ps

module clock_gen #(
    parameter integer ENABLE_CAMERA = 0
) (
    input  wire clk50,
    input  wire reset,
    output wire clk25,
    output wire clk125,
    output wire clk24,
    output wire locked
);
    wire fb_video, fb_video_buf, clk125_raw, clk25_raw, lock_video;
    wire fb_cam, fb_cam_buf, clk24_raw, lock_cam;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"), .CLKIN1_PERIOD(20.0),
        .DIVCLK_DIVIDE(1), .CLKFBOUT_MULT_F(20.0),
        .CLKOUT0_DIVIDE_F(8.0), .CLKOUT1_DIVIDE(40),
        .STARTUP_WAIT("FALSE")
    ) u_video_mmcm (
        .CLKIN1(clk50),.RST(reset),.PWRDWN(1'b0),
        .CLKFBIN(fb_video_buf),.CLKFBOUT(fb_video),.CLKFBOUTB(),
        .CLKOUT0(clk125_raw),.CLKOUT1(clk25_raw),
        .CLKOUT0B(),.CLKOUT1B(),.CLKOUT2(),.CLKOUT2B(),
        .CLKOUT3(),.CLKOUT3B(),.CLKOUT4(),.CLKOUT5(),.CLKOUT6(),
        .LOCKED(lock_video)
    );
    BUFG u_vfb(.I(fb_video),.O(fb_video_buf));
    BUFG u_125(.I(clk125_raw),.O(clk125));
    BUFG u_25(.I(clk25_raw),.O(clk25));

    generate
        if (ENABLE_CAMERA != 0) begin : g_camera_clock
            MMCME2_BASE #(
                .BANDWIDTH("OPTIMIZED"), .CLKIN1_PERIOD(20.0),
                .DIVCLK_DIVIDE(2), .CLKFBOUT_MULT_F(24.0),
                .CLKOUT0_DIVIDE_F(25.0), .STARTUP_WAIT("FALSE")
            ) u_camera_mmcm (
                .CLKIN1(clk50),.RST(reset),.PWRDWN(1'b0),
                .CLKFBIN(fb_cam_buf),.CLKFBOUT(fb_cam),.CLKFBOUTB(),
                .CLKOUT0(clk24_raw),.CLKOUT0B(),.CLKOUT1(),.CLKOUT1B(),
                .CLKOUT2(),.CLKOUT2B(),.CLKOUT3(),.CLKOUT3B(),
                .CLKOUT4(),.CLKOUT5(),.CLKOUT6(),.LOCKED(lock_cam)
            );
            BUFG u_cfb(.I(fb_cam),.O(fb_cam_buf));
            BUFG u_24(.I(clk24_raw),.O(clk24));
        end else begin : g_no_camera_clock
            assign fb_cam_buf = 1'b0;
            assign clk24_raw  = 1'b0;
            assign clk24      = 1'b0;
            assign lock_cam   = 1'b1;
        end
    endgenerate
    assign locked=lock_video & lock_cam;
endmodule
