`timescale 1ns/1ps

module password_lock_top #(
    // The Raspberry Pi link is harmless when no Pi is connected: TX remains
    // idle high and RX has an external pull-up constraint. Set to 0 to remove
    // the UART protocol logic from synthesis.
    parameter integer ENABLE_RPI_CAMERA = 1
) (
    input  wire       sys_clk,
    input  wire [3:0] key_n,
    input  wire [3:0] sw,
    input  wire [3:0] keypad_row_n,
    output wire [3:0] keypad_col_n,
    output wire [7:0] seg_n,
    output wire [7:0] seg_sel,
    output wire [3:0] led,
    output wire       buzzer_n,
    output wire       flash_cs_n,
    output wire       flash_sclk,
    output wire       flash_mosi,
    input  wire       flash_miso,
    output wire       flash_wp_n,
    output wire       flash_hold_n,
    output wire       rpi_uart_tx,
    input  wire       rpi_uart_rx
);
    wire sys_rst;
    wire sw1_event,admin_event,alarm_clear_event,temporary_key_event;
    wire temporary_generate_event,temporary_valid;
    wire keypad_event;
    wire [3:0] keypad_code;
    wire flash_init_done,flash_fault,save_done,save_success;
    wire [15:0] stored_password,save_password,entry_digits,temporary_password;
    wire save_request,photo_trigger,unlocked,alarm_active,display_fault;
    wire alarm_indicator;
    wire [3:0] lock_state;
    wire [2:0] entry_count,error_count;
    wire rpi_link_waiting;

    reset_sync u_sys_reset(.clk(sys_clk),.arst(~key_n[3]),.rst(sys_rst));

    debounce_event #(.ACTIVE_LOW(0)) u_sw1(.clk(sys_clk),.rst(sys_rst),.async_in(sw[0]),.level(),.rise_event(sw1_event));
    debounce_event u_admin(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[0]),.level(),.rise_event(admin_event));
    debounce_event u_clear(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[1]),.level(),.rise_event(alarm_clear_event));
    debounce_event u_temporary(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[2]),.level(),.rise_event(temporary_key_event));
    keypad_scanner u_keypad(.clk(sys_clk),.rst(sys_rst|alarm_clear_event),.row_n(keypad_row_n),
        .col_n(keypad_col_n),.event_valid(keypad_event),.event_code(keypad_code));

    w25q64_password_store u_password_store(
        .clk(sys_clk),.rst(sys_rst),.save_request(save_request),.save_password(save_password),
        .flash_miso(flash_miso),.flash_sclk(flash_sclk),.flash_mosi(flash_mosi),
        .flash_cs_n(flash_cs_n),.flash_wp_n(flash_wp_n),.flash_hold_n(flash_hold_n),
        .init_done(flash_init_done),.current_password(stored_password),
        .save_done(save_done),.save_success(save_success),.flash_fault(flash_fault));

    // KEY3 is accepted only while waiting or already displaying a temporary
    // password. It cannot interrupt entry, saving, errors, or an alarm.
    assign temporary_generate_event = temporary_key_event &&
        (lock_state == 4'd1 || lock_state == 4'd8);
    temporary_password_generator u_temporary_password(
        .clk(sys_clk),.rst(sys_rst),.generate_event(temporary_generate_event),
        .stored_password(stored_password),.temporary_password(temporary_password),
        .temporary_valid(temporary_valid));

    lock_controller u_lock(
        .clk(sys_clk),.rst(sys_rst),.flash_init_done(flash_init_done),
        .stored_password(stored_password),.flash_fault(flash_fault),
        .sw1_event(sw1_event),.admin_event(admin_event),.alarm_clear_event(alarm_clear_event),
        .temporary_event(temporary_generate_event),.temporary_password(temporary_password),
        .temporary_valid(temporary_valid),
        .key_valid(keypad_event),.key_code(keypad_code),.save_done(save_done),.save_success(save_success),
        .save_request(save_request),.save_password(save_password),.capture_start(photo_trigger),
        .unlocked(unlocked),.alarm_active(alarm_active),.state(lock_state),
        .entry_digits(entry_digits),.entry_count(entry_count),.error_count(error_count),
        .display_fault(display_fault));

    sevenseg_display u_display(.clk(sys_clk),.rst(sys_rst),.state(lock_state),
        .entry_digits(entry_digits),.entry_count(entry_count),.error_count(error_count),
        .temporary_password(temporary_password),.display_fault(display_fault),
        .seg_n(seg_n),.digit_sel(seg_sel));
    assign led[0]=(lock_state==1);
    assign led[1]=(lock_state==2)||(lock_state==5);
    assign led[2]=unlocked;
    alarm_buzzer u_alarm_buzzer(.clk(sys_clk),.rst(sys_rst),.alarm_active(alarm_active),
        .buzzer_n(buzzer_n),.indicator(alarm_indicator));
    assign led[3]=alarm_active ? alarm_indicator : flash_fault;

    generate
        if (ENABLE_RPI_CAMERA != 0) begin : g_rpi_camera
            rpi_camera_link u_rpi_camera_link(
                .clk(sys_clk),.rst(sys_rst),.photo_trigger(photo_trigger),
                .uart_rx(rpi_uart_rx),.uart_tx(rpi_uart_tx),
                .link_waiting(rpi_link_waiting));
        end else begin : g_no_rpi_camera
            assign rpi_uart_tx = 1'b1;
            assign rpi_link_waiting = 1'b0;
        end
    endgenerate
endmodule
