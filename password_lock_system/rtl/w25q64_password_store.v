`timescale 1ns/1ps

// Two-sector, power-loss-tolerant password journal for the board's user W25Q64.
// Record bytes: magic[4], generation[4], password[2], inverse[2], CRC16[2],
// commit marker[2]. Password only changes after a verified readback.
module w25q64_password_store #(
    parameter integer CLOCK_HZ = 50_000_000,
    parameter integer SPI_HALF_DIV = 2,
    parameter integer CS_HIGH_CYCLES = 4,
    parameter integer ERASE_TIMEOUT_CYCLES = CLOCK_HZ,
    parameter integer PROGRAM_TIMEOUT_CYCLES = CLOCK_HZ/50
) (
    input  wire        clk,
    input  wire        rst,
    input  wire        save_request,
    input  wire [15:0] save_password,
    input  wire        flash_miso,
    output wire        flash_sclk,
    output wire        flash_mosi,
    output reg         flash_cs_n,
    output wire        flash_wp_n,
    output wire        flash_hold_n,
    output reg         init_done,
    output reg [15:0]  current_password,
    output reg         save_done,
    output reg         save_success,
    output reg         flash_fault
);
    localparam [31:0] MAGIC = 32'h504C4B31;
    localparam [15:0] COMMIT = 16'hA55A;
    localparam [5:0] S_ID=0, S_READ_A=1, S_READ_B=2, S_SELECT=3, S_IDLE=4,
                     S_WREN_ERASE=5, S_ERASE=6, S_POLL_ERASE=7,
                     S_WREN_PROGRAM=8, S_PROGRAM=9, S_POLL_PROGRAM=10,
                     S_VERIFY=11, S_FINISH=12, S_FAIL=13;

    reg [5:0] state;
    reg [5:0] byte_index;
    reg [31:0] timeout_count;
    localparam integer CGW = (CS_HIGH_CYCLES <= 2) ? 1 : $clog2(CS_HIGH_CYCLES + 1);
    reg [CGW-1:0] cs_high_count;
    reg awaiting_byte;
    reg launch_pending;
    reg spi_start;
    reg [7:0] spi_tx;
    wire [7:0] spi_rx;
    wire spi_busy, spi_done;
    reg [127:0] record_a, record_b, verify_record, new_record;
    reg [31:0] generation;
    reg active_bank;
    reg target_bank;
    reg id_valid;
    reg [23:0] jedec_id;
    reg [15:0] requested_password;
    wire valid_a = record_valid(record_a);
    wire valid_b = record_valid(record_b);
    wire valid_verify = record_valid(verify_record);
    wire [23:0] target_address = target_bank ? 24'h001000 : 24'h000000;

    assign flash_wp_n   = 1'b1;
    assign flash_hold_n = 1'b1;

    spi_byte_master #(.HALF_DIV(SPI_HALF_DIV)) u_spi (
        .clk(clk), .rst(rst), .start(spi_start), .tx_data(spi_tx),
        .miso(flash_miso), .sclk(flash_sclk), .mosi(flash_mosi),
        .rx_data(spi_rx), .busy(spi_busy), .done(spi_done)
    );

    function [15:0] crc16_96;
        input [95:0] data;
        integer i;
        reg [15:0] crc;
        begin
            crc = 16'hFFFF;
            for (i=95; i>=0; i=i-1) begin
                if (crc[15] ^ data[i])
                    crc = {crc[14:0],1'b0} ^ 16'h1021;
                else
                    crc = {crc[14:0],1'b0};
            end
            crc16_96 = crc;
        end
    endfunction

    function bcd_valid;
        input [15:0] value;
        begin
            bcd_valid = (value[15:12] <= 9) && (value[11:8] <= 9) &&
                        (value[7:4] <= 9) && (value[3:0] <= 9);
        end
    endfunction

    function record_valid;
        input [127:0] record;
        begin
            record_valid = (record[127:96] == MAGIC) &&
                           bcd_valid(record[63:48]) &&
                           (record[47:32] == ~record[63:48]) &&
                           (record[31:16] == crc16_96(record[127:32])) &&
                           (record[15:0] == COMMIT);
        end
    endfunction

    function [7:0] record_byte;
        input [127:0] record;
        input [4:0] index;
        begin
            case (index)
                0: record_byte=record[127:120]; 1: record_byte=record[119:112];
                2: record_byte=record[111:104]; 3: record_byte=record[103:96];
                4: record_byte=record[95:88];   5: record_byte=record[87:80];
                6: record_byte=record[79:72];   7: record_byte=record[71:64];
                8: record_byte=record[63:56];   9: record_byte=record[55:48];
                10:record_byte=record[47:40];  11: record_byte=record[39:32];
                12:record_byte=record[31:24];  13: record_byte=record[23:16];
                14:record_byte=record[15:8];   default: record_byte=record[7:0];
            endcase
        end
    endfunction

    function [7:0] transaction_byte;
        input [5:0] st;
        input [5:0] index;
        begin
            transaction_byte = 8'h00;
            case (st)
                S_ID: transaction_byte = (index == 0) ? 8'h9F : 8'h00;
                S_READ_A, S_READ_B, S_VERIFY: begin
                    case (index)
                        0: transaction_byte=8'h03;
                        1: transaction_byte=(st==S_READ_B || (st==S_VERIFY && target_bank)) ? 8'h00 : 8'h00;
                        2: transaction_byte=(st==S_READ_B || (st==S_VERIFY && target_bank)) ? 8'h10 : 8'h00;
                        3: transaction_byte=8'h00;
                        default: transaction_byte=8'h00;
                    endcase
                end
                S_WREN_ERASE, S_WREN_PROGRAM: transaction_byte=8'h06;
                S_ERASE: begin
                    case(index)
                        0: transaction_byte=8'h20;
                        1: transaction_byte=target_address[23:16];
                        2: transaction_byte=target_address[15:8];
                        default: transaction_byte=target_address[7:0];
                    endcase
                end
                S_PROGRAM: begin
                    case(index)
                        0: transaction_byte=8'h02;
                        1: transaction_byte=target_address[23:16];
                        2: transaction_byte=target_address[15:8];
                        3: transaction_byte=target_address[7:0];
                        default: transaction_byte=record_byte(new_record,index-4);
                    endcase
                end
                S_POLL_ERASE, S_POLL_PROGRAM:
                    transaction_byte=(index==0) ? 8'h05 : 8'h00;
                default: transaction_byte=8'h00;
            endcase
        end
    endfunction

    task finish_transaction;
        begin
            flash_cs_n <= 1'b1;
            byte_index <= 0;
            awaiting_byte <= 1'b0;
            launch_pending <= 1'b0;
            cs_high_count <= CS_HIGH_CYCLES;
        end
    endtask

    always @(posedge clk) begin
        if (rst) begin
            state <= S_ID;
            byte_index <= 0;
            timeout_count <= 0;
            cs_high_count <= CS_HIGH_CYCLES;
            awaiting_byte <= 0;
            launch_pending <= 0;
            spi_start <= 0;
            spi_tx <= 0;
            flash_cs_n <= 1;
            init_done <= 0;
            current_password <= 16'h1234;
            save_done <= 0;
            save_success <= 0;
            flash_fault <= 0;
            record_a <= 0; record_b <= 0; verify_record <= 0; new_record <= 0;
            generation <= 0;
            active_bank <= 0; target_bank <= 1;
            id_valid <= 0; jedec_id <= 0;
            requested_password <= 16'h1234;
        end else begin
            spi_start <= 1'b0;
            save_done <= 1'b0;

            if (cs_high_count != 0)
                cs_high_count <= cs_high_count - 1'b1;

            if ((state == S_POLL_ERASE && timeout_count < ERASE_TIMEOUT_CYCLES) ||
                (state == S_POLL_PROGRAM && timeout_count < PROGRAM_TIMEOUT_CYCLES))
                timeout_count <= timeout_count + 1'b1;

            if (launch_pending && !spi_busy) begin
                spi_start <= 1'b1;
                awaiting_byte <= 1'b1;
                launch_pending <= 1'b0;
            end else if (!awaiting_byte && !launch_pending && !spi_busy &&
                cs_high_count == 0 &&
                state != S_SELECT && state != S_IDLE &&
                state != S_FINISH && state != S_FAIL) begin
                if (flash_cs_n)
                    flash_cs_n <= 1'b0;
                spi_tx <= transaction_byte(state, byte_index);
                launch_pending <= 1'b1;
            end

            if (spi_done && awaiting_byte) begin
                awaiting_byte <= 1'b0;
                case (state)
                    S_ID: begin
                        if (byte_index > 0)
                            jedec_id <= {jedec_id[15:0],spi_rx};
                        if (byte_index == 3) begin
                            finish_transaction;
                            id_valid <= ({jedec_id[15:0],spi_rx} != 24'h000000) &&
                                        ({jedec_id[15:0],spi_rx} != 24'hFFFFFF);
                            state <= S_READ_A;
                        end else byte_index <= byte_index + 1'b1;
                    end
                    S_READ_A: begin
                        if (byte_index >= 4)
                            record_a <= {record_a[119:0],spi_rx};
                        if (byte_index == 19) begin finish_transaction; state <= S_READ_B; end
                        else byte_index <= byte_index + 1'b1;
                    end
                    S_READ_B: begin
                        if (byte_index >= 4)
                            record_b <= {record_b[119:0],spi_rx};
                        if (byte_index == 19) begin finish_transaction; state <= S_SELECT; end
                        else byte_index <= byte_index + 1'b1;
                    end
                    S_WREN_ERASE: begin finish_transaction; state <= S_ERASE; end
                    S_ERASE: begin
                        if (byte_index == 3) begin
                            finish_transaction; state <= S_POLL_ERASE; timeout_count <= 0;
                        end else byte_index <= byte_index + 1'b1;
                    end
                    S_POLL_ERASE: begin
                        if (byte_index == 1) begin
                            finish_transaction;
                            if (!spi_rx[0]) state <= S_WREN_PROGRAM;
                            else if (timeout_count >= ERASE_TIMEOUT_CYCLES-1) state <= S_FAIL;
                        end else byte_index <= byte_index + 1'b1;
                    end
                    S_WREN_PROGRAM: begin finish_transaction; state <= S_PROGRAM; end
                    S_PROGRAM: begin
                        if (byte_index == 19) begin
                            finish_transaction; state <= S_POLL_PROGRAM; timeout_count <= 0;
                        end else byte_index <= byte_index + 1'b1;
                    end
                    S_POLL_PROGRAM: begin
                        if (byte_index == 1) begin
                            finish_transaction;
                            if (!spi_rx[0]) state <= S_VERIFY;
                            else if (timeout_count >= PROGRAM_TIMEOUT_CYCLES-1) state <= S_FAIL;
                        end else byte_index <= byte_index + 1'b1;
                    end
                    S_VERIFY: begin
                        if (byte_index >= 4)
                            verify_record <= {verify_record[119:0],spi_rx};
                        if (byte_index == 19) begin finish_transaction; state <= S_FINISH; end
                        else byte_index <= byte_index + 1'b1;
                    end
                    default: ;
                endcase
            end

            case (state)
                S_SELECT: begin
                    flash_cs_n <= 1'b1;
                    flash_fault <= ~id_valid;
                    if (valid_a && valid_b) begin
                        if (record_b[95:64] > record_a[95:64]) begin
                            current_password <= record_b[63:48]; generation <= record_b[95:64]; active_bank <= 1;
                        end else begin
                            current_password <= record_a[63:48]; generation <= record_a[95:64]; active_bank <= 0;
                        end
                    end else if (valid_a) begin
                        current_password <= record_a[63:48]; generation <= record_a[95:64]; active_bank <= 0;
                    end else if (valid_b) begin
                        current_password <= record_b[63:48]; generation <= record_b[95:64]; active_bank <= 1;
                    end else begin
                        current_password <= 16'h1234; generation <= 0; active_bank <= 0;
                    end
                    init_done <= 1'b1;
                    state <= S_IDLE;
                end
                S_IDLE: begin
                    flash_cs_n <= 1'b1;
                    if (save_request) begin
                        requested_password <= save_password;
                        target_bank <= ~active_bank;
                        new_record[127:32] <= {MAGIC,generation+1'b1,save_password,~save_password};
                        new_record[31:16] <= crc16_96({MAGIC,generation+1'b1,save_password,~save_password});
                        new_record[15:0] <= COMMIT;
                        verify_record <= 0;
                        timeout_count <= 0;
                        save_success <= 0;
                        flash_fault <= 0;
                        state <= S_WREN_ERASE;
                    end
                end
                S_FINISH: begin
                    flash_cs_n <= 1'b1;
                    if (valid_verify && verify_record == new_record) begin
                        current_password <= requested_password;
                        generation <= generation + 1'b1;
                        active_bank <= target_bank;
                        save_success <= 1'b1;
                        flash_fault <= 1'b0;
                    end else begin
                        save_success <= 1'b0;
                        flash_fault <= 1'b1;
                    end
                    save_done <= 1'b1;
                    state <= S_IDLE;
                end
                S_FAIL: begin
                    finish_transaction;
                    save_success <= 1'b0;
                    save_done <= 1'b1;
                    flash_fault <= 1'b1;
                    state <= S_IDLE;
                end
                default: ;
            endcase
        end
    end
endmodule
