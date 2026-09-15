`timescale 1ns/1ps

// 密码锁主控制器（有限状态机 FSM）。
// 组合逻辑只计算 next_state；时序逻辑在时钟沿更新状态、计时、输入缓存和单周期控制脉冲。
// state 编码同时送往数码管和测试平台，因此修改编码时必须同步修改显示/仿真中的状态定义。
module lock_controller #(
    parameter integer CLOCK_HZ         = 50_000_000,
    parameter integer LOCK_TIMEOUT_S   = 8,
    parameter integer OPEN_TIMEOUT_S   = 16,
    parameter integer ERROR_DISPLAY_MS = 1000
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        flash_init_done,
    input  wire [15:0] stored_password,
    input  wire        flash_fault,
    input  wire        sw1_event,
    input  wire        admin_event,
    input  wire        alarm_clear_event,
    input  wire        temporary_event,
    input  wire [15:0] temporary_password,
    input  wire        temporary_valid,
    input  wire        key_valid,
    input  wire [3:0]  key_code,
    input  wire        save_done,
    input  wire        save_success,
    output reg         save_request,
    output reg [15:0]  save_password,
    output reg         capture_start,
    output reg         unlocked,
    output reg         alarm_active,
    output reg [3:0]   state,
    output reg [15:0]  entry_digits,
    output reg [2:0]   entry_count,
    output reg [2:0]   error_count,
    output reg         display_fault
);
    // 状态含义：上电初始化、等待、用户输入、错误提示、开锁、管理员输入、保存、报警、临时密码。
    localparam [3:0] ST_BOOT  = 4'd0,
                     ST_WAIT  = 4'd1,
                     ST_USER  = 4'd2,
                     ST_ERROR = 4'd3,
                     ST_OPEN  = 4'd4,
                     ST_ADMIN = 4'd5,
                     ST_SAVE  = 4'd6,
                     ST_ALARM = 4'd7,
                     ST_TEMP  = 4'd8;
    localparam integer LOCK_TICKS  = CLOCK_HZ * LOCK_TIMEOUT_S;
    localparam integer OPEN_TICKS  = CLOCK_HZ * OPEN_TIMEOUT_S;
    localparam integer ERROR_TICKS = (CLOCK_HZ / 1000) * ERROR_DISPLAY_MS;
    localparam integer MAX_TICKS = (OPEN_TICKS > LOCK_TICKS) ? OPEN_TICKS : LOCK_TICKS;
    localparam integer MAX_TICKS2 = (MAX_TICKS > ERROR_TICKS) ? MAX_TICKS : ERROR_TICKS;
    localparam integer TW = (MAX_TICKS2 <= 2) ? 1 : $clog2(MAX_TICKS2 + 1);

    reg [3:0] next_state;
    reg [TW-1:0] timer_count;
    // 键盘码 0~9 是数字；A=确认，B=退格，C=取消。有效操作会重新开始超时计时。
    wire is_digit = (key_code <= 4'd9);
    wire activity = key_valid && (is_digit || key_code == 4'hA ||
                                  key_code == 4'hB || key_code == 4'hC);

    // 下一状态判定。错误计数表示已经发生的错误次数：第 4 次错误直接进入报警态。
    always @(*) begin
        next_state = state;
        case (state)
            ST_BOOT:  if (flash_init_done) next_state = ST_WAIT;
            ST_WAIT:  if (temporary_event) next_state = ST_TEMP;
                      else if (admin_event) next_state = ST_ADMIN;
                      else if (sw1_event) next_state = ST_USER;
            ST_USER:  if (key_valid && key_code == 4'hC) next_state = ST_WAIT;
                      else if ((timer_count >= LOCK_TICKS-1) && !activity) next_state = ST_WAIT;
                      else if (key_valid && key_code == 4'hA && entry_count == 3'd4) begin
                          if (entry_digits == stored_password ||
                              (temporary_valid && entry_digits == temporary_password))
                              next_state = ST_OPEN;
                          else if (error_count == 3'd3) next_state = ST_ALARM;
                          else next_state = ST_ERROR;
                      end
            ST_ERROR: if (timer_count >= ERROR_TICKS-1) next_state = ST_USER;
            ST_OPEN:  if ((key_valid && key_code == 4'hA) ||
                          (timer_count >= OPEN_TICKS-1)) next_state = ST_WAIT;
                      else if (admin_event) next_state = ST_ADMIN;
            ST_ADMIN: if (key_valid && key_code == 4'hC) next_state = ST_WAIT;
                      else if ((timer_count >= LOCK_TICKS-1) && !activity) next_state = ST_WAIT;
                      else if (key_valid && key_code == 4'hA && entry_count == 3'd4)
                          next_state = ST_SAVE;
            ST_SAVE:  if (save_done) next_state = ST_WAIT;
            // 临时密码重新生成的优先级最高，使新密码至少完整显示一个超时时间。
            ST_TEMP:  if (temporary_event) next_state = ST_TEMP;
                      else if (sw1_event) next_state = ST_USER;
                      else if (key_valid && (key_code == 4'hA || key_code == 4'hC))
                          next_state = ST_WAIT;
                      else if (timer_count >= LOCK_TICKS-1) next_state = ST_WAIT;
            // 报警态只能由 KEY2 的 alarm_clear_event 解除，解除后直接进入新的用户输入会话。
            ST_ALARM: if (alarm_clear_event) next_state = ST_USER;
            default: next_state = ST_BOOT;
        endcase
    end

    // 状态寄存器及动作逻辑。save_request、capture_start 默认每拍清零，故都是单周期脉冲。
    always @(posedge clk) begin
        if (rst) begin
            state          <= ST_BOOT;
            timer_count    <= {TW{1'b0}};
            entry_digits   <= 16'h0000;
            entry_count    <= 3'd0;
            error_count    <= 3'd0;
            save_request   <= 1'b0;
            save_password  <= 16'h1234;
            capture_start  <= 1'b0;
            display_fault  <= 1'b0;
        end else begin
            state         <= next_state;
            save_request  <= 1'b0;
            capture_start <= 1'b0;

            // 发生状态转移时统一清计时器，并执行相应“进入状态”动作。
            if (state != next_state) begin
                timer_count <= {TW{1'b0}};
                if (next_state == ST_USER || next_state == ST_ADMIN ||
                    next_state == ST_WAIT) begin
                    entry_digits <= 16'h0000;
                    entry_count  <= 3'd0;
                end
                if (next_state == ST_OPEN)
                    error_count <= 3'd0;
                if (next_state == ST_ERROR)
                    error_count <= error_count + 1'b1;
                if (next_state == ST_ALARM) begin
                    error_count   <= 3'd4;
                    capture_start <= 1'b1;
                end
                // 管理员解除报警后把错误次数清零，重新获得四次尝试机会。
                if (state == ST_ALARM && alarm_clear_event)
                    error_count <= 3'd0;
                // 进入保存态时锁存新密码，并向 Flash 模块发出一个时钟周期的写请求。
                if (next_state == ST_SAVE) begin
                    save_password <= entry_digits;
                    save_request  <= 1'b1;
                end
                if (state == ST_SAVE && next_state == ST_WAIT)
                    display_fault <= ~save_success;
            end else begin
                // 状态未改变时累计超时；数字/A/B/C 或重新生成临时密码会清零计时。
                if ((activity || temporary_event) &&
                    (state == ST_USER || state == ST_ADMIN || state == ST_OPEN || state == ST_TEMP))
                    timer_count <= {TW{1'b0}};
                else if (state == ST_USER || state == ST_ADMIN || state == ST_OPEN ||
                         state == ST_ERROR || state == ST_TEMP)
                    timer_count <= timer_count + 1'b1;

                // 4 位 BCD 输入左移追加；B 键右移删除最后一位。超过 4 位的数字被忽略。
                if ((state == ST_USER || state == ST_ADMIN) && key_valid) begin
                    if (is_digit && entry_count < 3'd4) begin
                        entry_digits <= {entry_digits[11:0], key_code};
                        entry_count  <= entry_count + 1'b1;
                    end else if (key_code == 4'hB && entry_count != 0) begin
                        entry_digits <= {4'h0, entry_digits[15:4]};
                        entry_count  <= entry_count - 1'b1;
                    end
                end
            end

            // 新操作可清除上次保存失败提示；Flash 当前故障则始终置位显示故障。
            if (display_fault && (sw1_event || admin_event || temporary_event))
                display_fault <= 1'b0;
            if (flash_fault)
                display_fault <= 1'b1;
        end
    end

    // 两个输出直接由状态译码，避免在各分支重复赋值。
    always @(*) begin
        unlocked     = (state == ST_OPEN);
        alarm_active = (state == ST_ALARM);
    end
endmodule
