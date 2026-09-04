`timescale 1ns/1ps

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
    wire is_digit = (key_code <= 4'd9);
    wire activity = key_valid && (is_digit || key_code == 4'hA ||
                                  key_code == 4'hB || key_code == 4'hC);

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
            // A replacement request wins over timeout or simultaneous input,
            // so the new password always remains visible for a full interval.
            ST_TEMP:  if (temporary_event) next_state = ST_TEMP;
                      else if (sw1_event) next_state = ST_USER;
                      else if (key_valid && (key_code == 4'hA || key_code == 4'hC))
                          next_state = ST_WAIT;
                      else if (timer_count >= LOCK_TICKS-1) next_state = ST_WAIT;
            // KEY2 completes the administrator's alarm handling and starts a
            // clean input session.  No SW1 toggle is required afterward.
            ST_ALARM: if (alarm_clear_event) next_state = ST_USER;
            default: next_state = ST_BOOT;
        endcase
    end

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
                // An acknowledged alarm starts a new four-attempt window.
                // Without this reset the three-bit counter would display
                // Err5..Err7 and wrap, which is not a valid attempt policy.
                if (state == ST_ALARM && alarm_clear_event)
                    error_count <= 3'd0;
                if (next_state == ST_SAVE) begin
                    save_password <= entry_digits;
                    save_request  <= 1'b1;
                end
                if (state == ST_SAVE && next_state == ST_WAIT)
                    display_fault <= ~save_success;
            end else begin
                if ((activity || temporary_event) &&
                    (state == ST_USER || state == ST_ADMIN || state == ST_OPEN || state == ST_TEMP))
                    timer_count <= {TW{1'b0}};
                else if (state == ST_USER || state == ST_ADMIN || state == ST_OPEN ||
                         state == ST_ERROR || state == ST_TEMP)
                    timer_count <= timer_count + 1'b1;

                if ((state == ST_USER || state == ST_ADMIN) && key_valid) begin
                    if (is_digit && entry_count < 3'd4) begin
                        entry_digits <= {entry_digits[11:0], key_code};
                        entry_count  <= entry_count + 1'b1;
                    end else if (key_code == 4'hB && entry_count != 0) begin
                        entry_digits <= {4'h0, entry_digits[15:4]};
                        entry_count  <= entry_count - 1'b1;
                    end
                end
                if (display_fault && (sw1_event || admin_event || temporary_event))
                    display_fault <= 1'b0;
                if (flash_fault)
                    display_fault <= 1'b1;
            end
        end
    end

    always @(*) begin
        unlocked     = (state == ST_OPEN);
        alarm_active = (state == ST_ALARM);
    end
endmodule
