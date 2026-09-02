`timescale 1ns/1ps

module password_lock_top (
    input wire sys_clk,
    input wire [3:0] key_n,
    input wire [3:0] sw,
    input wire [3:0] keypad_row_n,
    output wire [3:0] keypad_col_n,
    output wire [7:0] seg_n,
    output wire [7:0] seg_sel,
    output wire [3:0] led,
    output wire buzzer_n,
    output wire flash_cs_n,
    output wire flash_sclk,
    output wire flash_mosi,
    input  wire flash_miso,
    output wire flash_wp_n,
    output wire flash_hold_n,
    output wire camera_xclk,
    output wire camera_pwdn,
    output wire camera_reset_n,
    output wire camera_scl,
    inout  wire camera_sda,
    input  wire camera_pclk,
    input  wire camera_vsync,
    input  wire camera_href,
    input  wire [7:0] camera_data,
    output wire hdmi_clk_p,
    output wire hdmi_clk_n,
    output wire [2:0] hdmi_data_p,
    output wire [2:0] hdmi_data_n
);
    wire clk25,clk125,clk24,clocks_locked;
    wire sys_rst,pclk_rst,pixel_rst;
    wire sw1_event,admin_event,alarm_clear_event;
    wire keypad_event;
    wire [3:0] keypad_code;
    wire flash_init_done,flash_fault,save_done,save_success;
    wire [15:0] stored_password,save_password,entry_digits;
    wire save_request,capture_start,unlocked,alarm_active,display_fault;
    wire [3:0] lock_state;
    wire [2:0] entry_count,error_count;
    wire camera_init_done,camera_init_error;
    wire cap_wr_en;
    wire [1:0] cap_wr_bank;
    wire [14:0] cap_wr_addr,video_rd_addr;
    wire [15:0] cap_wr_data,rd0,rd1,rd2,rd3;
    wire capture_busy,frames_valid,capture_error;
    wire [9:0] video_x,video_y;
    wire timing_active,timing_hsync,timing_vsync;
    wire [23:0] video_rgb,dvi_data;
    wire video_active,video_hsync,video_vsync;

    clock_gen u_clocks(.clk50(sys_clk),.reset(~key_n[3]),.clk25(clk25),
        .clk125(clk125),.clk24(clk24),.locked(clocks_locked));
    reset_sync u_sys_reset(.clk(sys_clk),.arst(~key_n[3]|~clocks_locked),.rst(sys_rst));
    reset_sync u_pclk_reset(.clk(camera_pclk),.arst(sys_rst),.rst(pclk_rst));
    reset_sync u_pixel_reset(.clk(clk25),.arst(sys_rst),.rst(pixel_rst));

    debounce_event #(.ACTIVE_LOW(0)) u_sw1(.clk(sys_clk),.rst(sys_rst),.async_in(sw[0]),.level(),.rise_event(sw1_event));
    debounce_event u_admin(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[0]),.level(),.rise_event(admin_event));
    debounce_event u_clear(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[1]),.level(),.rise_event(alarm_clear_event));
    keypad_scanner u_keypad(.clk(sys_clk),.rst(sys_rst),.row_n(keypad_row_n),
        .col_n(keypad_col_n),.event_valid(keypad_event),.event_code(keypad_code));

    w25q64_password_store u_password_store(
        .clk(sys_clk),.rst(sys_rst),.save_request(save_request),.save_password(save_password),
        .flash_miso(flash_miso),.flash_sclk(flash_sclk),.flash_mosi(flash_mosi),
        .flash_cs_n(flash_cs_n),.flash_wp_n(flash_wp_n),.flash_hold_n(flash_hold_n),
        .init_done(flash_init_done),.current_password(stored_password),
        .save_done(save_done),.save_success(save_success),.flash_fault(flash_fault));

    lock_controller u_lock(
        .clk(sys_clk),.rst(sys_rst),.flash_init_done(flash_init_done),
        .stored_password(stored_password),.flash_fault(flash_fault),
        .sw1_event(sw1_event),.admin_event(admin_event),.alarm_clear_event(alarm_clear_event),
        .key_valid(keypad_event),.key_code(keypad_code),.save_done(save_done),.save_success(save_success),
        .save_request(save_request),.save_password(save_password),.capture_start(capture_start),
        .unlocked(unlocked),.alarm_active(alarm_active),.state(lock_state),
        .entry_digits(entry_digits),.entry_count(entry_count),.error_count(error_count),
        .display_fault(display_fault));

    sevenseg_display u_display(.clk(sys_clk),.rst(sys_rst),.state(lock_state),
        .entry_digits(entry_digits),.entry_count(entry_count),.error_count(error_count),
        .display_fault(display_fault),.seg_n(seg_n),.digit_sel(seg_sel));
    assign led[0]=(lock_state==1);
    assign led[1]=(lock_state==2)||(lock_state==5);
    assign led[2]=unlocked;
    assign led[3]=alarm_active|flash_fault|camera_init_error|capture_error;
    assign buzzer_n=~alarm_active;

    assign camera_xclk=clk24;
    ov5640_initializer u_camera_init(.clk(sys_clk),.rst(sys_rst),.sccb_scl(camera_scl),
        .sccb_sda(camera_sda),.camera_pwdn(camera_pwdn),.camera_reset_n(camera_reset_n),
        .init_done(camera_init_done),.init_error(camera_init_error));
    capture_manager u_capture_manager(.sys_clk(sys_clk),.sys_rst(sys_rst),
        .pclk(camera_pclk),.pclk_rst(pclk_rst),.start(capture_start),
        .camera_init_error(camera_init_error),.vsync(camera_vsync),.href(camera_href),
        .pixel_data(camera_data),.wr_en(cap_wr_en),.wr_bank(cap_wr_bank),
        .wr_addr(cap_wr_addr),.wr_data(cap_wr_data),.busy(capture_busy),
        .frames_valid(frames_valid),.capture_error(capture_error));
    frame_buffer_4 u_buffers(.wr_clk(camera_pclk),.wr_en(cap_wr_en),.wr_bank(cap_wr_bank),
        .wr_addr(cap_wr_addr),.wr_data(cap_wr_data),.rd_clk(clk25),.rd_addr(video_rd_addr),
        .rd_data0(rd0),.rd_data1(rd1),.rd_data2(rd2),.rd_data3(rd3));

    video_timing_640x480 u_timing(.pixel_clk(clk25),.rst(pixel_rst),.x(video_x),.y(video_y),
        .active(timing_active),.hsync(timing_hsync),.vsync(timing_vsync));
    mosaic_renderer u_renderer(.pixel_clk(clk25),.rst(pixel_rst),.x(video_x),.y(video_y),
        .active(timing_active),.hsync(timing_hsync),.vsync(timing_vsync),
        .frames_valid(frames_valid),.camera_error(camera_init_error|capture_error),
        .read_address(video_rd_addr),.read_data0(rd0),.read_data1(rd1),
        .read_data2(rd2),.read_data3(rd3),.rgb(video_rgb),.video_active(video_active),
        .video_hsync(video_hsync),.video_vsync(video_vsync));

    // rgb2dvi expects the byte order R,B,G on vid_pData.
    assign dvi_data={video_rgb[23:16],video_rgb[7:0],video_rgb[15:8]};
    rgb2dvi #(.kGenerateSerialClk(0),.kRstActiveHigh(1)) u_dvi(
        .TMDS_Clk_p(hdmi_clk_p),.TMDS_Clk_n(hdmi_clk_n),
        .TMDS_Data_p(hdmi_data_p),.TMDS_Data_n(hdmi_data_n),
        .aRst(pixel_rst),.aRst_n(~pixel_rst),.vid_pData(dvi_data),
        .vid_pVDE(video_active),.vid_pHSync(video_hsync),.vid_pVSync(video_vsync),
        .PixelClk(clk25),.SerialClk(clk125));
endmodule
