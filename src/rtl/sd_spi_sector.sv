module sd_spi_sector (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        miso,
    output logic        sck,
    output logic        mosi,
    output logic        cs_n,
    output logic        sd_reset_n,
    input  logic        read_req,
    input  logic [31:0] read_lba,
    output logic        initialized,
    output logic        busy,
    output logic        sector_done,
    output logic        error,
    output logic [7:0]  data,
    output logic        data_valid,
    output logic [8:0]  data_index,
    output logic [7:0]  error_code
);
    typedef enum logic [3:0] {
        ST_POWER,
        ST_DUMMY,
        ST_ISSUE,
        ST_SEND,
        ST_GET_R1,
        ST_GET_EXTRA,
        ST_AFTER_CMD,
        ST_WAIT_TOKEN,
        ST_READ_DATA,
        ST_READ_CRC,
        ST_FINISH,
        ST_READY,
        ST_FAULT
    } state_t;

    state_t state;

    logic       spi_start;
    logic       spi_done;
    logic       spi_busy;
    logic [7:0] spi_tx;
    logic [7:0] spi_rx;
    logic       spi_pending;
    logic       slow_mode;

    logic [5:0]  command;
    logic [31:0] command_arg;
    logic [7:0]  command_crc;
    logic [2:0]  command_pos;
    logic [7:0]  response_r1;
    logic [2:0]  extra_remaining;
    logic [31:0] response_extra;

    logic [3:0]  dummy_remaining;
    logic [19:0] token_timeout;
    logic [6:0]  r1_timeout;
    logic [12:0] init_attempts;
    logic [20:0] power_delay;
    logic [8:0]  byte_index;
    logic [1:0]  crc_remaining;

    assign spi_start = !spi_busy && !spi_pending && (
        state == ST_DUMMY     ||
        state == ST_SEND      ||
        state == ST_GET_R1    ||
        state == ST_GET_EXTRA ||
        state == ST_WAIT_TOKEN||
        state == ST_READ_DATA ||
        state == ST_READ_CRC
    );

    spi_byte_master spi (
        .clk       (clk),
        .rst_n     (rst_n),
        .start     (spi_start),
        .tx_data   (spi_tx),
        .slow_mode (slow_mode),
        .miso      (miso),
        .sck       (sck),
        .mosi      (mosi),
        .busy      (spi_busy),
        .done      (spi_done),
        .rx_data   (spi_rx)
    );

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state           <= ST_POWER;
            cs_n            <= 1'b1;
            sd_reset_n      <= 1'b0;
            initialized     <= 1'b0;
            busy            <= 1'b1;
            sector_done     <= 1'b0;
            error           <= 1'b0;
            error_code      <= 8'd0;
            data            <= 8'd0;
            data_valid      <= 1'b0;
            data_index      <= 9'd0;
            spi_pending     <= 1'b0;
            slow_mode       <= 1'b1;
            spi_tx          <= 8'hFF;
            command         <= 6'd0;
            command_arg     <= 32'd0;
            command_crc     <= 8'h95;
            command_pos     <= 3'd0;
            response_r1     <= 8'd0;
            extra_remaining <= 3'd0;
            response_extra  <= 32'd0;
            dummy_remaining <= 4'd0;
            token_timeout   <= 20'd0;
            r1_timeout      <= 7'd0;
            init_attempts   <= 13'd0;
            power_delay     <= 21'd0;
            byte_index      <= 9'd0;
            crc_remaining   <= 2'd0;
        end else begin
            sector_done <= 1'b0;
            data_valid  <= 1'b0;

            if (spi_start) begin
                spi_pending <= 1'b1;
            end
            if (spi_done) begin
                spi_pending <= 1'b0;
            end

            case (state)
                ST_POWER: begin
                    cs_n <= 1'b1;
                    if (power_delay == 21'd2_000_000) begin
                        power_delay     <= 21'd0;
                        dummy_remaining <= 4'd0;
                        spi_tx          <= 8'hFF;
                        state           <= ST_DUMMY;
                    end else begin
                        power_delay <= power_delay + 21'd1;
                    end
                end

                ST_DUMMY: if (spi_done) begin
                    if (dummy_remaining == 4'd9) begin
                        command     <= 6'd0;
                        command_arg <= 32'd0;
                        command_crc <= 8'h95;
                        command_pos <= 3'd0;
                        cs_n        <= 1'b0;
                        spi_tx      <= 8'h40;
                        state       <= ST_SEND;
                    end else begin
                        dummy_remaining <= dummy_remaining + 4'd1;
                    end
                end

                ST_ISSUE: begin
                    cs_n       <= 1'b0;
                    command_pos<= 3'd0;
                    spi_tx     <= {2'b01, command};
                    r1_timeout <= 7'd0;
                    state      <= ST_SEND;
                end

                ST_SEND: if (spi_done) begin
                    if (command_pos == 3'd5) begin
                        command_pos <= 3'd0;
                        spi_tx      <= 8'hFF;
                        state       <= ST_GET_R1;
                    end else begin
                        command_pos <= command_pos + 3'd1;
                        case (command_pos)
                            3'd0: spi_tx <= command_arg[31:24];
                            3'd1: spi_tx <= command_arg[23:16];
                            3'd2: spi_tx <= command_arg[15:8];
                            3'd3: spi_tx <= command_arg[7:0];
                            3'd4: spi_tx <= command_crc;
                            default: spi_tx <= 8'hFF;
                        endcase
                    end
                end

                ST_GET_R1: if (spi_done) begin
                    if (!spi_rx[7]) begin
                        response_r1 <= spi_rx;
                        if (command == 6'd8 || command == 6'd58) begin
                            extra_remaining <= 3'd4;
                            response_extra  <= 32'd0;
                            state           <= ST_GET_EXTRA;
                        end else begin
                            state <= ST_AFTER_CMD;
                        end
                    end else if (r1_timeout == 7'd100) begin
                        error      <= 1'b1;
                        error_code <= 8'h01;
                        state      <= ST_FAULT;
                    end else begin
                        r1_timeout <= r1_timeout + 7'd1;
                    end
                end

                ST_GET_EXTRA: if (spi_done) begin
                    response_extra <= {response_extra[23:0], spi_rx};
                    if (extra_remaining == 3'd1) begin
                        state <= ST_AFTER_CMD;
                    end
                    extra_remaining <= extra_remaining - 3'd1;
                end

                ST_AFTER_CMD: begin
                    case (command)
                        6'd0: begin
                            if (response_r1 == 8'h01) begin
                                command     <= 6'd8;
                                command_arg <= 32'h0000_01AA;
                                command_crc <= 8'h87;
                                state       <= ST_ISSUE;
                            end else begin
                                error_code <= 8'h10;
                                state      <= ST_FAULT;
                            end
                        end

                        6'd8: begin
                            if (response_r1 == 8'h01 && response_extra[11:0] == 12'h1AA) begin
                                command     <= 6'd55;
                                command_arg <= 32'd0;
                                command_crc <= 8'h01;
                                state       <= ST_ISSUE;
                            end else begin
                                error_code <= 8'h11;
                                state      <= ST_FAULT;
                            end
                        end

                        6'd55: begin
                            if (response_r1 <= 8'h01) begin
                                command     <= 6'd41;
                                command_arg <= 32'h4000_0000;
                                command_crc <= 8'h01;
                                state       <= ST_ISSUE;
                            end else begin
                                error_code <= 8'h12;
                                state      <= ST_FAULT;
                            end
                        end

                        6'd41: begin
                            if (response_r1 == 8'h00) begin
                                command     <= 6'd58;
                                command_arg <= 32'd0;
                                command_crc <= 8'h01;
                                state       <= ST_ISSUE;
                            end else if (response_r1 == 8'h01 && init_attempts < 13'd5000) begin
                                init_attempts <= init_attempts + 13'd1;
                                command       <= 6'd55;
                                command_arg   <= 32'd0;
                                command_crc   <= 8'h01;
                                state         <= ST_ISSUE;
                            end else begin
                                error_code <= 8'h13;
                                state      <= ST_FAULT;
                            end
                        end

                        6'd58: begin
                            if (response_r1 == 8'h00 && response_extra[30]) begin
                                initialized <= 1'b1;
                                slow_mode   <= 1'b0;
                                cs_n        <= 1'b1;
                                busy        <= 1'b0;
                                state       <= ST_READY;
                            end else begin
                                error_code <= 8'h14;
                                state      <= ST_FAULT;
                            end
                        end

                        6'd17: begin
                            if (response_r1 == 8'h00) begin
                                token_timeout <= 20'd0;
                                state         <= ST_WAIT_TOKEN;
                            end else begin
                                error_code <= 8'h17;
                                state      <= ST_FAULT;
                            end
                        end

                        default: begin
                            error_code <= 8'hFF;
                            state      <= ST_FAULT;
                        end
                    endcase
                end

                ST_READY: if (read_req) begin
                    command     <= 6'd17;
                    command_arg <= read_lba;
                    command_crc <= 8'h01;
                    busy        <= 1'b1;
                    state       <= ST_ISSUE;
                end

                ST_WAIT_TOKEN: if (spi_done) begin
                    if (spi_rx == 8'hFE) begin
                        byte_index <= 9'd0;
                        state      <= ST_READ_DATA;
                    end else if (token_timeout == 20'd200_000) begin
                        error_code <= 8'h20;
                        state      <= ST_FAULT;
                    end else begin
                        token_timeout <= token_timeout + 20'd1;
                    end
                end

                ST_READ_DATA: if (spi_done) begin
                    data       <= spi_rx;
                    data_index <= byte_index;
                    data_valid <= 1'b1;

                    if (byte_index == 9'd511) begin
                        crc_remaining <= 2'd2;
                        state         <= ST_READ_CRC;
                    end else begin
                        byte_index <= byte_index + 9'd1;
                    end
                end

                ST_READ_CRC: if (spi_done) begin
                    if (crc_remaining == 2'd1) begin
                        state <= ST_FINISH;
                    end else begin
                        crc_remaining <= crc_remaining - 2'd1;
                    end
                end

                ST_FINISH: begin
                    cs_n        <= 1'b1;
                    sector_done <= 1'b1;
                    busy        <= 1'b0;
                    state       <= ST_READY;
                end

                ST_FAULT: begin
                    error <= 1'b1;
                    cs_n  <= 1'b1;
                    busy  <= 1'b0;
                end

                default: state <= ST_FAULT;
            endcase
        end
    end

endmodule
