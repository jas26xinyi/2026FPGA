`timescale 1ns/1ps

module mosaic_renderer (
    input  wire        pixel_clk,
    input  wire        rst,
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire        active,
    input  wire        hsync,
    input  wire        vsync,
    input  wire        frames_valid,
    input  wire        camera_error,
    output reg  [14:0] read_address,
    input  wire [15:0] read_data0,
    input  wire [15:0] read_data1,
    input  wire [15:0] read_data2,
    input  wire [15:0] read_data3,
    output reg  [23:0] rgb,
    output reg         video_active,
    output reg         video_hsync,
    output reg         video_vsync
);
    reg [1:0] bank_d;
    reg active_d, hsync_d, vsync_d;
    reg [9:0] x_d;
    reg frames_valid_d, camera_error_d;
    reg [15:0] selected_pixel;
    wire [7:0] source_x = (x>=320) ? ((x-320)>>1) : (x>>1);
    wire [6:0] source_y = (y>=240) ? ((y-240)>>1) : (y>>1);
    wire [14:0] source_address = (source_y<<7)+(source_y<<5)+source_x;

    always @(posedge pixel_clk) begin
        if (rst) begin
            read_address<=0; bank_d<=0; active_d<=0; hsync_d<=1; vsync_d<=1;
            x_d<=0; frames_valid_d<=0; camera_error_d<=0;
        end else begin
            read_address<=source_address;
            bank_d<={y>=240,x>=320};
            active_d<=active; hsync_d<=hsync; vsync_d<=vsync; x_d<=x;
            frames_valid_d<=frames_valid; camera_error_d<=camera_error;
        end
    end
    always @(*) begin
        case(bank_d)
            0:selected_pixel=read_data0; 1:selected_pixel=read_data1;
            2:selected_pixel=read_data2; default:selected_pixel=read_data3;
        endcase
        video_active=active_d; video_hsync=hsync_d; video_vsync=vsync_d;
        if (!active_d) rgb=24'h000000;
        else if (camera_error_d) rgb=((x_d[5]^x_d[4])?24'h800000:24'hFF0000);
        else if (!frames_valid_d) begin
            case(x_d[9:7])
                0:rgb=24'hFFFFFF; 1:rgb=24'hFFFF00; 2:rgb=24'h00FFFF;
                3:rgb=24'h00FF00; 4:rgb=24'hFF00FF; 5:rgb=24'hFF0000;
                6:rgb=24'h0000FF; default:rgb=24'h000000;
            endcase
        end else begin
            rgb={selected_pixel[15:11],selected_pixel[15:13],
                 selected_pixel[10:5],selected_pixel[10:9],
                 selected_pixel[4:0],selected_pixel[4:2]};
        end
    end
endmodule
