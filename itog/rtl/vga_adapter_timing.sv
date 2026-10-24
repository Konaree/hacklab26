`timescale 1ns/1ps
// VESA 800x600 at 60 Hz: 40 MHz, 1056 pixels/line, 628 lines/frame.
module vga_adapter_timing (
    input logic clk, input logic rst,
    output logic [10:0] x, output logic [9:0] y,
    output logic visible, output logic hsync, output logic vsync
);
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin x <= 0; y <= 0; end
        else if (x == 11'd1055) begin
            x <= 0;
            y <= (y == 10'd627) ? 10'd0 : y + 1'b1;
        end else x <= x + 1'b1;
    end
    assign visible = (x < 11'd800) && (y < 10'd600);
    assign hsync = (x >= 11'd840) && (x < 11'd968);
    assign vsync = (y >= 10'd601) && (y < 10'd605);
endmodule
