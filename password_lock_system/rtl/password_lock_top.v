`timescale 1ns/1ps

// 密码锁系统顶层：只负责连接各功能模块，不在这里直接实现业务状态机。
// 外部输入经同步/消抖后变成单周期事件，交给 lock_controller 决定状态；
// 状态、输入数字和故障信息再送往数码管、LED、蜂鸣器及树莓派通信模块。
module password_lock_top #(
    // 设为 1：综合树莓派拍照通信；设为 0：删除 UART 协议逻辑并让 TX 保持空闲高电平。
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
    // sys_rst 为同步释放的系统复位；*_event 均为消抖后仅持续一个 clk 的事件脉冲。
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

    // KEY4 为低有效复位键：按下时异步复位，松开后按 sys_clk 同步退出复位。
    reset_sync u_sys_reset(.clk(sys_clk),.arst(~key_n[3]),.rst(sys_rst));

    // SW1 为高有效用户输入启动；KEY1/KEY2/KEY3 为低有效机械按键。
    debounce_event #(.ACTIVE_LOW(0)) u_sw1(.clk(sys_clk),.rst(sys_rst),.async_in(sw[0]),.level(),.rise_event(sw1_event));
    debounce_event u_admin(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[0]),.level(),.rise_event(admin_event));
    debounce_event u_clear(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[1]),.level(),.rise_event(alarm_clear_event));
    debounce_event u_temporary(.clk(sys_clk),.rst(sys_rst),.async_in(key_n[2]),.level(),.rise_event(temporary_key_event));
    // 解除报警时同时清空键盘扫描器的按键保持状态，避免旧按键被误识别为新输入。
    keypad_scanner u_keypad(.clk(sys_clk),.rst(sys_rst|alarm_clear_event),.row_n(keypad_row_n),
        .col_n(keypad_col_n),.event_valid(keypad_event),.event_code(keypad_code));

    // W25Q64 保存永久密码：上电读出 stored_password，管理员保存时执行双扇区更新。
    w25q64_password_store u_password_store(
        .clk(sys_clk),.rst(sys_rst),.save_request(save_request),.save_password(save_password),
        .flash_miso(flash_miso),.flash_sclk(flash_sclk),.flash_mosi(flash_mosi),
        .flash_cs_n(flash_cs_n),.flash_wp_n(flash_wp_n),.flash_hold_n(flash_hold_n),
        .init_done(flash_init_done),.current_password(stored_password),
        .save_done(save_done),.save_success(save_success),.flash_fault(flash_fault));

    // KEY3 只在等待态(1)或临时密码显示态(8)生效，不能打断输入、保存、错误或报警流程。
    assign temporary_generate_event = temporary_key_event &&
        (lock_state == 4'd1 || lock_state == 4'd8);
    temporary_password_generator u_temporary_password(
        .clk(sys_clk),.rst(sys_rst),.generate_event(temporary_generate_event),
        .stored_password(stored_password),.temporary_password(temporary_password),
        .temporary_valid(temporary_valid));

    // 系统业务核心：比较密码、统计错误次数、产生保存请求和拍照触发。
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

    // 显示模块根据状态选择 PASS/OPEN/ALARM/TEMP 等内容，并动态扫描 8 位数码管。
    sevenseg_display u_display(.clk(sys_clk),.rst(sys_rst),.state(lock_state),
        .entry_digits(entry_digits),.entry_count(entry_count),.error_count(error_count),
        .temporary_password(temporary_password),.display_fault(display_fault),
        .seg_n(seg_n),.digit_sel(seg_sel));
    // LED0=等待，LED1=用户/管理员输入，LED2=已开锁，LED3=报警节拍或 Flash 故障。
    assign led[0]=(lock_state==1);
    assign led[1]=(lock_state==2)||(lock_state==5);
    assign led[2]=unlocked;
    alarm_buzzer u_alarm_buzzer(.clk(sys_clk),.rst(sys_rst),.alarm_active(alarm_active),
        .buzzer_n(buzzer_n),.indicator(alarm_indicator));
    assign led[3]=alarm_active ? alarm_indicator : flash_fault;

    // 可综合条件生成：关闭树莓派功能时不实例化 UART，仅给端口确定的安全电平。
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
