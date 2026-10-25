module player_top (
    input  logic       CLK100MHZ,
    input  logic       CPU_RESETN,
    input  logic       PS2_CLK,
    input  logic       PS2_DATA,
    input  logic       SW0,
    input  logic       SD_DAT0,
    output logic       SD_RESET,
    output logic       SD_SCK,
    output logic       SD_CMD,
    output logic       SD_DAT3,
    output wire        AUD_PWM,
    output logic       AUD_SD,
    input  logic       ACL_MISO,
    output logic       ACL_MOSI,
    output logic       ACL_SCLK,
    output logic       ACL_CSN,
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic       VGA_HS,
    output logic       VGA_VS,
    output logic [15:0] LED,
    output logic       LED16_R, LED16_G, LED16_B,
    output logic       LED17_R, LED17_G, LED17_B,
    output logic       CA, CB, CC, CD, CE, CF, CG, DP,
    output logic [7:0] AN
);
    localparam logic [1:0] PLAYING = 2'd1;
    localparam logic [31:0] SAMPLE_STEP = 32'd2_061_584; // 48 kHz at 100 MHz

    (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe;
    \
    wire rst_n = reset_pipe[1];
    wire rst_100 = ~rst_n;
    logic clk_40mhz;
    logic clk_40_locked;
    wire rst_40 = rst_100 | ~clk_40_locked;

    always_ff @(posedge CLK100MHZ or negedge CPU_RESETN) begin
        if (!CPU_RESETN)
            reset_pipe <= 2'b00;
        else
            reset_pipe <= {reset_pipe[0], 1'b1};
    end

    vga_clk40 u_vga_clk40 (
        .clk_in1(CLK100MHZ),
        .reset(rst_100),
        .clk_out1(clk_40mhz),
        .locked(clk_40_locked)
    );

    logic [7:0] scan_code;
    logic       scan_valid;
    logic [1:0] song_id;
    logic [1:0] player_state;
    logic       restart_pulse;
    logic       sensor_ready, sleep_100, blank_40, motion_pulse;

    ps2_receiver ps2 (
        .clk(CLK100MHZ),
        .rst(rst_100),
        .ps2_clk(PS2_CLK),
        .ps2_data(PS2_DATA),
        .scan_code(scan_code),
        .scan_valid(scan_valid)
    );

    player_controller ctrl (
        .clk(CLK100MHZ),
        .rst(rst_100),
        .scan_code(scan_code),
        .scan_valid(scan_valid),
        .song_id(song_id),
        .player_state(player_state),
        .restart_pulse(restart_pulse)
    );

    logic           sd_ready, sd_busy, sd_done, sd_error;
    logic           sd_read_req;
    logic [31:0]    sd_read_lba;
    logic [7:0]     sd_data;
    logic           sd_data_valid;
    logic [8:0]     sd_data_index;
    logic [7:0]     sd_error_code;

    sd_spi_sector sd_controller (
        .clk(CLK100MHZ),
        .rst_n(rst_n),
        .miso(SD_DAT0),
        .sck(SD_SCK),
        .mosi(SD_CMD),
        .cs_n(SD_DAT3),
        .sd_reset_n(SD_RESET),
        .read_req(sd_read_req),
        .read_lba(sd_read_lba),
        .initialized(sd_ready),
        .busy(sd_busy),
        .sector_done(sd_done),
        .error(sd_error),
        .data(sd_data),
        .data_valid(sd_data_valid),
        .data_index(sd_data_index),
        .error_code(sd_error_code)
    );

    logic [31:0]    sample_phase;
    logic           sample_tick;
    logic [7:0]     pcm_sample;
    logic           wav_playing;
    logic [15:0]    wav_elapsed_seconds, wav_duration_seconds;
    logic [9:0]     wav_progress_pixels;
    logic [7:0]     wav_status;
    logic [15:0]    audio_leds;
    logic [7:0]     audio_level;
    logic           audio_level_valid;
    logic [31:0]    spectrum_levels;
    logic           amp_active;
    logic [7:0]     pwm_count;
    logic [7:0]     pwm_sample;

    always_ff @(posedge CLK100MHZ) begin
        if (!rst_n) begin
            sample_phase <= 32'd0;
            sample_tick  <= 1'b0;
            pwm_count    <= 8'd0;
        end else begin
            {sample_tick, sample_phase} <= {1'b0, sample_phase} +
                                           {1'b0, SAMPLE_STEP};
            pwm_count <= pwm_count + 8'd1;
        end
    end

    fat32_wav_player wav_player (
        .clk(CLK100MHZ),
        .rst_n(rst_n),
        .sd_ready(sd_ready),
        .sd_busy(sd_busy),
        .sd_done(sd_done),
        .sd_error(sd_error),
        .track_index(song_id),
        .play_enable((player_state == PLAYING) && !sleep_100),
        .restart(restart_pulse),
        .read_req(sd_read_req),
        .read_lba(sd_read_lba),
        .data(sd_data),
        .data_valid(sd_data_valid),
        .data_index(sd_data_index),
        .sample_tick(sample_tick),
        .sample(pcm_sample),
        .playing(wav_playing),
        .elapsed_seconds(wav_elapsed_seconds),
        .duration_seconds(wav_duration_seconds),
        .progress_pixels(wav_progress_pixels),
        .status(wav_status)
    );

    assign amp_active = (player_state == PLAYING) && wav_playing && !sleep_100;
    assign pwm_sample = amp_active ? pcm_sample : 8'h80;

    logic pwm_bit = (pwm_count < pwm_sample);

    assign AUD_PWM = pwm_bit ? 1'bz : 1'b0;
    assign AUD_SD = amp_active;

    audio_level_meter level_meter (
        .clk(CLK100MHZ),
        .rst(rst_100),
        .sample_tick(sample_tick),
        .active(amp_active),
        .sample(pcm_sample),
        .led(audio_leds),
        .level(audio_level),
        .level_valid(audio_level_valid)
    );

    assign LED = audio_leds;

    music_rgb rgb_visualizer (
        .clk(CLK100MHZ),
        .rst(rst_100),
        .active(amp_active),
        .level(audio_level),
        .level_valid(audio_level_valid),
        .LED16_R(LED16_R),
        .LED16_G(LED16_G),
        .LED16_B(LED16_B),
        .LED17_R(LED17_R),
        .LED17_G(LED17_G),
        .LED17_B(LED17_B)
    );

    audio_spectrum_meter spectrum_meter (
        .clk(CLK100MHZ),
        .rst(rst_100),
        .sample_tick(sample_tick),
        .active(amp_active),
        .sample(pcm_sample),
        .band_levels(spectrum_levels)
    );

    nexys_auto_sleep #(.CLK_HZ(100_000_000), .INACTIVE_SEC(60)) auto_sleep (
        .clk_100(CLK100MHZ), .clk_40(clk_40mhz), .rst_100(rst_100),
        .SW0(SW0), .key_activity(scan_valid), .ACL_MISO(ACL_MISO),
        .ACL_MOSI(ACL_MOSI), .ACL_SCLK(ACL_SCLK), .ACL_CSN(ACL_CSN),
        .sleep_100(sleep_100), .blank_40(blank_40),
        .sensor_ready(sensor_ready), .motion_pulse(motion_pulse)
    );

    (* ASYNC_REG = "TRUE" *) logic [1:0] song_meta, song_sync;
    (* ASYNC_REG = "TRUE" *) logic [31:0] spectrum_meta, spectrum_sync;

    logic [15:0]    elapsed_seconds, duration_seconds;
    logic [9:0]     progress_pixels;
    logic [10:0]    x;
    logic [9:0]     y;
    logic           visible, hsync, vsync;
    logic           visible_d, hsync_d, vsync_d;
    logic [11:0]    rgb_next;
    logic [6:0]     segments;
    logic           dp_n;

    always_ff @(posedge clk_40mhz or posedge rst_40) begin
        if (rst_40) begin
            song_meta <= 2'd0;
            song_sync <= 2'd0;
            spectrum_meta <= 32'd0;
            spectrum_sync <= 32'd0;
        end else begin
            song_meta <= song_id;
            song_sync <= song_meta;
            spectrum_meta <= spectrum_levels;
            spectrum_sync <= spectrum_meta;
        end
    end

    vga_adapter_timing timing (
        .clk(clk_40mhz),
        .rst(rst_40),
        .x(x),
        .y(y),
        .visible(visible),
        .hsync(hsync),
        .vsync(vsync)
    );

    music_timer timer_sync (
        .clk(clk_40mhz), .rst(rst_40),
        .elapsed_in(wav_elapsed_seconds), .duration_in(wav_duration_seconds),
        .progress_in(wav_progress_pixels), .elapsed_seconds(elapsed_seconds),
        .duration_seconds(duration_seconds), .progress_pixels(progress_pixels)
    );

    music_renderer renderer (
        .clk(clk_40mhz), .x(x), .y(y), .track(song_sync),
        .elapsed_seconds(elapsed_seconds), .duration_seconds(duration_seconds),
        .progress_pixels(progress_pixels), .spectrum_levels(spectrum_sync),
        .sleep_mode(blank_40), .rgb(rgb_next)
    );

    music_sevenseg timer_display (
        .clk(clk_40mhz), .rst(rst_40),
        .elapsed_seconds(elapsed_seconds), .duration_seconds(duration_seconds),
        .segments(segments), .dp(dp_n), .anodes(AN)
    );

    assign {CA, CB, CC, CD, CE, CF, CG} = segments;
    assign DP = dp_n;

    always_ff @(posedge clk_40mhz or posedge rst_40) begin
        if (rst_40) begin
            visible_d <= 1'b0;
            hsync_d <= 1'b1;
            vsync_d <= 1'b1;
        end else begin
            visible_d <= visible;
            hsync_d <= hsync;
            vsync_d <= vsync;
        end
    end

    always_ff @(posedge clk_40mhz or posedge rst_40) begin
        if (rst_40) begin
            {VGA_R, VGA_G, VGA_B} <= 12'h000;
            VGA_HS <= 1'b1;
            VGA_VS <= 1'b1;
        end else begin
            {VGA_R, VGA_G, VGA_B} <= visible_d ? rgb_next : 12'h000;
            VGA_HS <= hsync_d;
            VGA_VS <= vsync_d;
        end
    end

endmodule
