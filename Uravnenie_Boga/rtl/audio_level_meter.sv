// SPDX-License-Identifier: MIT
// Eight LED envelope meter for unsigned 8-bit PCM audio.
module audio_level_meter (
    input  logic       clk,
    input  logic       rst,
    input  logic       sample_tick,
    input  logic       active,
    input  logic [7:0] sample,
    output logic [7:0] led
);
    logic [7:0] magnitude;
    logic [17:0] sum;
    logic [9:0] window_count;
    logic [7:0] average;

    always_comb begin
        magnitude = (sample >= 8'd128) ? sample - 8'd128 : 8'd128 - sample;
        led[0] = active && average >= 8'd3;
        led[1] = active && average >= 8'd6;
        led[2] = active && average >= 8'd10;
        led[3] = active && average >= 8'd15;
        led[4] = active && average >= 8'd22;
        led[5] = active && average >= 8'd32;
        led[6] = active && average >= 8'd46;
        led[7] = active && average >= 8'd64;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sum          <= 18'd0;
            window_count <= 10'd0;
            average      <= 8'd0;
        end else if (sample_tick) begin
            if (!active) begin
                sum          <= 18'd0;
                window_count <= 10'd0;
                average      <= 8'd0;
            end else if (window_count == 10'd1023) begin
                average      <= (sum + magnitude) >> 10;
                sum          <= 18'd0;
                window_count <= 10'd0;
            end else begin
                sum          <= sum + magnitude;
                window_count <= window_count + 10'd1;
            end
        end
    end
endmodule
