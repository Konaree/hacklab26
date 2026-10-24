// SPDX-License-Identifier: MIT
// Standalone Nexys A7-100T WAV player, 100 MHz domain, no vendor IP.
module nexys_sd_wav_top (
    input  logic       CLK100MHZ,
    input  logic       CPU_RESETN,
    input  logic       SD_DAT0,
    output logic       SD_RESET,
    output logic       SD_SCK,
    output logic       SD_CMD,
    output logic       SD_DAT3,
    output wire        AUD_PWM,
    output logic       AUD_SD,
    output logic [7:0] LED
);
    // A 32-bit fractional phase accumulator creates ~48 kHz sample ticks.
    localparam logic [31:0] SAMPLE_STEP = 32'd2_061_584;

    logic        sd_ready;
    logic        sd_busy;
    logic        sd_done;
    logic        sd_error;
    logic        read_req;
    logic [31:0] read_lba;
    logic [7:0]  sd_data;
    logic        sd_data_valid;
    logic [8:0]  sd_data_index;
    logic [7:0]  sd_error_code;

    logic [31:0] sample_phase;
    logic        sample_tick;
    logic [7:0]  pcm_sample;
    logic        playing;
    logic [7:0]  player_status;
    logic [7:0]  pwm_count;
    logic        pwm_bit;

    always_ff @(posedge CLK100MHZ or negedge CPU_RESETN) begin
        if (!CPU_RESETN) begin
            sample_phase <= 32'd0;
            sample_tick  <= 1'b0;
            pwm_count    <= 8'd0;
        end else begin
            {sample_tick, sample_phase} <= {1'b0, sample_phase} +
                                           {1'b0, SAMPLE_STEP};
            pwm_count <= pwm_count + 8'd1;
        end
    end

    sd_spi_sector sd_controller (
        .clk          (CLK100MHZ),
        .rst_n        (CPU_RESETN),
        .miso         (SD_DAT0),
        .sck          (SD_SCK),
        .mosi         (SD_CMD),
        .cs_n         (SD_DAT3),
        .sd_reset_n   (SD_RESET),
        .read_req     (read_req),
        .read_lba     (read_lba),
        .initialized  (sd_ready),
        .busy         (sd_busy),
        .sector_done  (sd_done),
        .error        (sd_error),
        .data         (sd_data),
        .data_valid   (sd_data_valid),
        .data_index   (sd_data_index),
        .error_code   (sd_error_code)
    );

    fat32_wav_player wav_player (
        .clk        (CLK100MHZ),
        .rst_n      (CPU_RESETN),
        .sd_ready   (sd_ready),
        .sd_busy    (sd_busy),
        .sd_done    (sd_done),
        .sd_error   (sd_error),
        .read_req   (read_req),
        .read_lba   (read_lba),
        .data       (sd_data),
        .data_valid (sd_data_valid),
        .data_index (sd_data_index),
        .sample_tick(sample_tick),
        .sample     (pcm_sample),
        .playing    (playing),
        .status     (player_status)
    );

    // Nexys A7 audio input requires an open-drain output (0 or high-Z).
    assign pwm_bit = (pwm_count < pcm_sample);
    assign AUD_PWM = pwm_bit ? 1'bz : 1'b0;
    assign AUD_SD  = playing;

    // LED[7] indicates SD failure; LED[6:0] mirrors player status.
    assign LED = {sd_error, player_status[6:0]};
endmodule
