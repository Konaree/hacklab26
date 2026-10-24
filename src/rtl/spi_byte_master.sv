// SPDX-License-Identifier: MIT
// SPI mode 0 byte transfer. One synchronous 100 MHz clock domain.
// Each half-period is either 250 clocks (200 kHz) or 4 clocks (12.5 MHz).
module spi_byte_master (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       start,
    input  logic [7:0] tx_data,
    input  logic       slow_mode,
    input  logic       miso,
    output logic       sck,
    output logic       mosi,
    output logic       busy,
    output logic       done,
    output logic [7:0] rx_data
);
    localparam logic [7:0] SLOW_DIV = 8'd250;
    localparam logic [7:0] FAST_DIV = 8'd4;

    logic [7:0] half_period_count;
    logic [7:0] tx_shift;
    logic [7:0] rx_shift;
    logic [2:0] bit_count;
    logic       high_half;

    wire [7:0] period = slow_mode ? SLOW_DIV : FAST_DIV;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sck               <= 1'b0;
            mosi              <= 1'b1;
            busy              <= 1'b0;
            done              <= 1'b0;
            rx_data           <= 8'd0;
            half_period_count <= 8'd0;
            tx_shift          <= 8'd0;
            rx_shift          <= 8'd0;
            bit_count         <= 3'd0;
            high_half         <= 1'b0;
        end else begin
            done <= 1'b0;

            if (!busy) begin
                sck <= 1'b0;

                if (start) begin
                    busy              <= 1'b1;
                    half_period_count <= period - 8'd1;
                    bit_count         <= 3'd7;
                    tx_shift          <= tx_data;
                    rx_shift          <= 8'd0;
                    mosi              <= tx_data[7];
                    high_half         <= 1'b0;
                end
            end else if (half_period_count != 0) begin
                half_period_count <= half_period_count - 8'd1;
            end else begin
                half_period_count <= period - 8'd1;

                if (!high_half) begin
                    sck       <= 1'b1;
                    rx_shift  <= {rx_shift[6:0], miso};
                    high_half <= 1'b1;
                end else begin
                    sck       <= 1'b0;
                    high_half <= 1'b0;

                    if (bit_count == 0) begin
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        rx_data <= rx_shift;
                        mosi    <= 1'b1;
                    end else begin
                        bit_count <= bit_count - 3'd1;
                        tx_shift  <= {tx_shift[6:0], 1'b1};
                        mosi      <= tx_shift[6];
                    end
                end
            end
        end
    end
endmodule
