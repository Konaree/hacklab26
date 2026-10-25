module spi_mode0_master #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer SPI_HZ = 2_000_000
)(
    input  logic        clk,
    input  logic        rst,
    input  logic        start,
    input  logic [39:0] tx_word,
    input  logic [5:0]  transfer_bits,
    output logic [39:0] rx_word,
    output logic        busy,
    output logic        done,
    output logic        spi_sclk,
    output logic        spi_mosi,
    input  logic        spi_miso,
    output logic        spi_csn
);
    localparam integer HALF_DIV = CLK_HZ / (SPI_HZ * 2);
    localparam integer DIV_W = (HALF_DIV <= 1) ? 1 : $clog2(HALF_DIV);
    localparam [2:0] ST_IDLE=3'd0, ST_LOW=3'd1,
                     ST_HIGH=3'd2, ST_END=3'd3;
    logic [2:0] state;
    logic [DIV_W-1:0] div_cnt;
    logic [5:0] bits_left;
    logic [39:0] tx_shift, rx_shift;

    assign busy = (state != ST_IDLE);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= ST_IDLE;
            div_cnt <= '0;
            bits_left <= '0;
            tx_shift <= '0;
            rx_shift <= '0;
            rx_word <= '0;
            done <= 1'b0;
            spi_sclk <= 1'b0;
            spi_mosi <= 1'b0;
            spi_csn <= 1'b1;
        end else begin
            done <= 1'b0;
            case (state)
                ST_IDLE: begin
                    spi_csn <= 1'b1;
                    spi_sclk <= 1'b0;
                    if (start && transfer_bits != 0 && transfer_bits <= 40) begin
                        tx_shift <= tx_word;
                        rx_shift <= '0;
                        bits_left <= transfer_bits;
                        spi_mosi <= tx_word[39];
                        spi_csn <= 1'b0;
                        div_cnt <= '0;
                        state <= ST_LOW;
                    end
                end
                ST_LOW: begin
                    if (div_cnt == HALF_DIV-1) begin
                        div_cnt <= '0;
                        spi_sclk <= 1'b1;
                        rx_shift <= {rx_shift[38:0], spi_miso};
                        state <= ST_HIGH;
                    end else div_cnt <= div_cnt + 1'b1;
                end
                ST_HIGH: begin
                    if (div_cnt == HALF_DIV-1) begin
                        div_cnt <= '0;
                        spi_sclk <= 1'b0;
                        if (bits_left == 1) begin
                            state <= ST_END;
                        end else begin
                            bits_left <= bits_left - 1'b1;
                            tx_shift <= {tx_shift[38:0], 1'b0};
                            spi_mosi <= tx_shift[38];
                            state <= ST_LOW;
                        end
                    end else div_cnt <= div_cnt + 1'b1;
                end
                ST_END: begin
                    if (div_cnt == HALF_DIV-1) begin
                        div_cnt <= '0;
                        spi_csn <= 1'b1;
                        rx_word <= rx_shift;
                        done <= 1'b1;
                        state <= ST_IDLE;
                    end else div_cnt <= div_cnt + 1'b1;
                end
                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
