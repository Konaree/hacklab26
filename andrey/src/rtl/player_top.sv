`timescale 1ns/1ps
// Keyboard-controlled player using the project's VGA UI and elapsed-time display.
module player_top (
    input  logic       CLK100MHZ,
    input  logic       CPU_RESETN,
    input  logic       PS2_CLK,
    input  logic       PS2_DATA,
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic       VGA_HS,
    output logic       VGA_VS,
    output logic [7:0] LED,
    output logic       CA, CB, CC, CD, CE, CF, CG, DP,
    output logic [7:0] AN
);
    localparam logic [1:0] PLAYING = 2'd1;

    logic clk_40mhz;
    logic clk_40_locked;
    logic rst_100;
    logic rst_40;

    assign rst_100 = ~CPU_RESETN;
    assign rst_40  = rst_100 | ~clk_40_locked;

    vga_clk40 u_vga_clk40 (
        .clk_in1  (CLK100MHZ),
        .reset    (rst_100),
        .clk_out1 (clk_40mhz),
        .locked   (clk_40_locked)
    );

    logic [7:0] scan_code;
    logic scan_valid;
    logic [1:0] song_id;
    logic [1:0] player_state;
    logic restart_pulse;

    ps2_receiver ps2 (
        .clk(CLK100MHZ), .rst(rst_100),
        .ps2_clk(PS2_CLK), .ps2_data(PS2_DATA),
        .scan_code(scan_code), .scan_valid(scan_valid)
    );

    player_controller ctrl (
        .clk(CLK100MHZ), .rst(rst_100),
        .scan_code(scan_code), .scan_valid(scan_valid),
        .song_id(song_id), .player_state(player_state),
        .restart_pulse(restart_pulse)
    );

    // Synchronize the controller state into the 40 MHz video/timer domain.
    logic [1:0] song_meta, song_sync;
    logic [1:0] state_meta, state_sync;
    logic restart_toggle;
    logic restart_meta, restart_sync, restart_sync_d;
    wire restart_40 = restart_sync ^ restart_sync_d;

    always_ff @(posedge CLK100MHZ or posedge rst_100) begin
        if (rst_100) restart_toggle <= 1'b0;
        else if (restart_pulse) restart_toggle <= ~restart_toggle;
    end

    always_ff @(posedge clk_40mhz or posedge rst_40) begin
        if (rst_40) begin
            song_meta      <= 2'd0;
            song_sync      <= 2'd0;
            state_meta     <= 2'd0;
            state_sync     <= 2'd0;
            restart_meta   <= 1'b0;
            restart_sync   <= 1'b0;
            restart_sync_d <= 1'b0;
        end else begin
            song_meta      <= song_id;
            song_sync      <= song_meta;
            state_meta     <= player_state;
            state_sync     <= state_meta;
            restart_meta   <= restart_toggle;
            restart_sync   <= restart_meta;
            restart_sync_d <= restart_sync;
        end
    end

    logic [10:0] x;
    logic [9:0] y;
    logic visible, hsync, vsync;
    logic [7:0] elapsed_seconds, duration_seconds;
    logic [9:0] progress_pixels;
    logic [11:0] rgb_next;
    logic [6:0] segments;
    logic dp_n;
    wire frame_start = (x == 0 && y == 0);
    wire playing = (state_sync == PLAYING);

    vga_adapter_timing timing (
        .clk(clk_40mhz), .rst(rst_40),
        .x(x), .y(y), .visible(visible), .hsync(hsync), .vsync(vsync)
    );

    music_timer timer (
        .clk(clk_40mhz), .rst(rst_40), .run(playing),
        .restart(restart_40), .track(song_sync), .frame_start(frame_start),
        .elapsed_seconds(elapsed_seconds),
        .duration_seconds(duration_seconds), .progress_pixels(progress_pixels)
    );

    music_renderer renderer (
        .x(x), .y(y), .track(song_sync),
        .progress_pixels(progress_pixels), .rgb(rgb_next)
    );

    music_sevenseg timer_display (
        .clk(clk_40mhz), .rst(rst_40),
        .elapsed_seconds(elapsed_seconds), .duration_seconds(duration_seconds),
        .segments(segments), .dp(dp_n), .anodes(AN)
    );

    assign {CA, CB, CC, CD, CE, CF, CG} = segments;
    assign DP = dp_n;

    assign LED[0] = progress_pixels >= 10'd75;
    assign LED[1] = progress_pixels >= 10'd150;
    assign LED[2] = progress_pixels >= 10'd225;
    assign LED[3] = progress_pixels >= 10'd300;
    assign LED[4] = progress_pixels >= 10'd375;
    assign LED[5] = progress_pixels >= 10'd450;
    assign LED[6] = progress_pixels >= 10'd525;
    assign LED[7] = progress_pixels >= 10'd600;

    always_ff @(posedge clk_40mhz or posedge rst_40) begin
        if (rst_40) begin
            {VGA_R, VGA_G, VGA_B} <= 12'h000;
            VGA_HS <= 1'b1;
            VGA_VS <= 1'b1;
        end else begin
            {VGA_R, VGA_G, VGA_B} <= visible ? rgb_next : 12'h000;
            VGA_HS <= hsync;
            VGA_VS <= vsync;
        end
    end
endmodule
