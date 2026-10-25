module adxl362_reader #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer SAMPLE_HZ = 50
)(
    input  logic clk,
    input  logic rst,
    input  logic ACL_MISO,
    output logic ACL_MOSI,
    output logic ACL_SCLK,
    output logic ACL_CSN,
    output logic sensor_ready,
    output logic sample_valid,
    output logic signed [7:0] ax,
    output logic signed [7:0] ay,
    output logic signed [7:0] az
);
    localparam integer BOOT_CYCLES = CLK_HZ / 100;   // 10 ms
    localparam integer SETTLE_CYCLES = CLK_HZ / 50; // 20 ms
    localparam integer POLL_CYCLES = CLK_HZ / SAMPLE_HZ;
    localparam integer TIMER_W = $clog2(CLK_HZ + 1);

    localparam [3:0] BOOT=4'd0, ID_START=4'd1, ID_WAIT=4'd2,
                     PWR_START=4'd3, PWR_WAIT=4'd4,
                     SETTLE=4'd5, POLL=4'd6,
                     XYZ_START=4'd7, XYZ_WAIT=4'd8;

    logic [3:0]         state;
    logic [TIMER_W-1:0] timer;
    logic               spi_start, spi_busy, spi_done;
    logic [39:0]        spi_tx, spi_rx;
    logic [5:0]         spi_nbits;

    spi_mode0_master #(.CLK_HZ(CLK_HZ), .SPI_HZ(2_000_000)) u_spi (
        .clk(clk),
        .rst(rst),
        .start(spi_start),
        .tx_word(spi_tx),
        .transfer_bits(spi_nbits),
        .rx_word(spi_rx),
        .busy(spi_busy),
        .done(spi_done),
        .spi_sclk(ACL_SCLK),
        .spi_mosi(ACL_MOSI),
        .spi_miso(ACL_MISO),
        .spi_csn(ACL_CSN)
    );

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= BOOT;
            timer <= '0;
            spi_start <= 1'b0;
            spi_tx <= '0;
            spi_nbits <= '0;
            sample_valid <= 1'b0;
            sensor_ready <= 1'b0;
            ax <= '0; ay <= '0; az <= '0;
        end else begin
            spi_start <= 1'b0;
            sample_valid <= 1'b0;
            case (state)
                BOOT: begin
                    sensor_ready <= 1'b0;
                    if (timer == BOOT_CYCLES - 1) begin
                        timer <= '0;
                        state <= ID_START;
                    end else timer <= timer + 1'b1;
                end
                ID_START: if (!spi_busy) begin
                    spi_tx <= {8'h0B, 8'h02, 8'h00, 16'h0000};
                    spi_nbits <= 6'd24;
                    spi_start <= 1'b1;
                    state <= ID_WAIT;
                end
                ID_WAIT: if (spi_done) begin
                    if (spi_rx[7:0] == 8'hF2) state <= PWR_START;
                    else begin
                        timer <= '0;
                        state <= BOOT;
                    end
                end
                PWR_START: if (!spi_busy) begin
                    spi_tx <= {8'h0A, 8'h2D, 8'h02, 16'h0000};
                    spi_nbits <= 6'd24;
                    spi_start <= 1'b1;
                    state <= PWR_WAIT;
                end
                PWR_WAIT: if (spi_done) begin
                    timer <= '0;
                    state <= SETTLE;
                end
                SETTLE: begin
                    if (timer == SETTLE_CYCLES - 1) begin
                        timer <= '0;
                        sensor_ready <= 1'b1;
                        state <= XYZ_START;
                    end else timer <= timer + 1'b1;
                end
                POLL: begin
                    if (timer == POLL_CYCLES - 1) begin
                        timer <= '0;
                        state <= XYZ_START;
                    end else timer <= timer + 1'b1;
                end
                XYZ_START: if (!spi_busy) begin
                    spi_tx <= {8'h0B, 8'h08, 24'h000000};
                    spi_nbits <= 6'd40;
                    spi_start <= 1'b1;
                    state <= XYZ_WAIT;
                end
                XYZ_WAIT: if (spi_done) begin
                    ax <= $signed(spi_rx[23:16]);
                    ay <= $signed(spi_rx[15:8]);
                    az <= $signed(spi_rx[7:0]);
                    sample_valid <= 1'b1;
                    timer <= '0;
                    state <= POLL;
                end
                default: state <= BOOT;
            endcase
        end
    end

endmodule
