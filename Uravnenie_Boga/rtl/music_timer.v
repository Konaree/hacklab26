`timescale 1ns/1ps
// Two-stage transfer of playback-derived time/progress into the VGA clock domain.
module music_timer (
    input  wire       clk,
    input  wire       rst,
    input  wire [15:0] elapsed_in,
    input  wire [15:0] duration_in,
    input  wire [9:0]  progress_in,
    output reg  [15:0] elapsed_seconds,
    output reg  [15:0] duration_seconds,
    output reg  [9:0]  progress_pixels
);
    (* ASYNC_REG = "TRUE" *) reg [15:0] elapsed_meta, duration_meta;
    (* ASYNC_REG = "TRUE" *) reg [9:0] progress_meta;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            elapsed_meta     <= 16'd0;
            duration_meta    <= 16'd0;
            progress_meta    <= 10'd0;
            elapsed_seconds  <= 16'd0;
            duration_seconds <= 16'd0;
            progress_pixels  <= 10'd0;
        end else begin
            elapsed_meta     <= elapsed_in;
            elapsed_seconds  <= elapsed_meta;
            duration_meta    <= duration_in;
            duration_seconds <= duration_meta;
            progress_meta    <= progress_in;
            progress_pixels  <= progress_meta;
        end
    end
endmodule
