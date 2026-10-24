`timescale 1ns/1ps
// Demo player timer and animated progress. It pauses with the player state.
module music_timer (
    input wire clk,
    input wire rst,
    input wire run,
    input wire restart,
    input wire [1:0] track,
    input wire frame_start,
    output reg [7:0] elapsed_seconds,
    output reg [7:0] duration_seconds,
    output wire [9:0] progress_pixels
);
    localparam [25:0] STEP_0 = 26'd3007; // 600 px / 218 s / 60 fps, Q16
    localparam [25:0] STEP_1 = 26'd3524; // 600 px / 186 s / 60 fps, Q16
    localparam [25:0] STEP_2 = 26'd2697; // 600 px / 243 s / 60 fps, Q16

    reg [25:0] one_second_count;
    reg [25:0] progress_fraction;
    reg [25:0] progress_step;
    reg [1:0] previous_track;

    always @* begin
        case (track)
            2'd1: begin duration_seconds = 8'd186; progress_step = STEP_1; end
            2'd2: begin duration_seconds = 8'd243; progress_step = STEP_2; end
            default: begin duration_seconds = 8'd218; progress_step = STEP_0; end
        endcase
    end

    assign progress_pixels = (progress_fraction[25:16] > 10'd600)
                           ? 10'd600 : progress_fraction[25:16];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            one_second_count <= 0;
            elapsed_seconds <= 0;
            progress_fraction <= 0;
            previous_track <= 0;
        end else if (restart || track != previous_track) begin
            one_second_count <= 0;
            elapsed_seconds <= 0;
            progress_fraction <= 0;
            previous_track <= track;
        end else if (run) begin
            if (one_second_count == 26'd39_999_999) begin
                one_second_count <= 0;
                if (elapsed_seconds + 1'b1 >= duration_seconds) begin
                    elapsed_seconds <= 0;
                    progress_fraction <= 0;
                end else begin
                    elapsed_seconds <= elapsed_seconds + 1'b1;
                    if (frame_start) begin
                        if (progress_pixels >= 10'd600)
                            progress_fraction <= 0;
                        else
                            progress_fraction <= progress_fraction + progress_step;
                    end
                end
            end else begin
                one_second_count <= one_second_count + 1'b1;
                if (frame_start) begin
                    if (progress_pixels >= 10'd600)
                        progress_fraction <= 0;
                    else
                        progress_fraction <= progress_fraction + progress_step;
                end
            end
        end
    end
endmodule
