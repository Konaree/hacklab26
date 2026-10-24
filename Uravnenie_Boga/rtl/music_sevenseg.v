`timescale 1ns/1ps
// Eight active-low Nexys A7 digits. From left to right: elapsed MM:SS, duration MM:SS.
module music_sevenseg (
    input wire clk,
    input wire rst,
    input wire [15:0] elapsed_seconds,
    input wire [15:0] duration_seconds,
    output reg [6:0] segments,
    output reg dp,
    output reg [7:0] anodes
);
    reg [16:0] scan_count;
    reg [2:0] digit;
    reg [3:0] value;
    wire [7:0] elapsed_min = (elapsed_seconds / 16'd60) % 16'd100;
    wire [7:0] duration_min = (duration_seconds / 16'd60) % 16'd100;
    wire [5:0] elapsed_sec = elapsed_seconds % 16'd60;
    wire [5:0] duration_sec = duration_seconds % 16'd60;
    wire [3:0] elapsed_sec_tens = elapsed_sec / 10;
    wire [3:0] elapsed_sec_ones = elapsed_sec % 10;
    wire [3:0] elapsed_min_tens = elapsed_min / 10;
    wire [3:0] elapsed_min_ones = elapsed_min % 10;
    wire [3:0] duration_sec_tens = duration_sec / 10;
    wire [3:0] duration_sec_ones = duration_sec % 10;
    wire [3:0] duration_min_tens = duration_min / 10;
    wire [3:0] duration_min_ones = duration_min % 10;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_count <= 17'd0;
            digit <= 3'd0;
        end else if (scan_count == 17'd49_999) begin
            scan_count <= 17'd0;
            digit <= digit + 1'b1;
        end else scan_count <= scan_count + 1'b1;
    end

    always @* begin
        anodes = 8'hFF;
        dp = 1'b1;
        value = 4'd0;
        case (digit)
            // AN7..AN4 are the elapsed time; AN3..AN0 are track duration.
            3'd0: begin anodes=8'hFE; value=duration_sec_ones; end
            3'd1: begin anodes=8'hFD; value=duration_sec_tens; end
            3'd2: begin anodes=8'hFB; value=duration_min_ones; dp=1'b0; end
            3'd3: begin anodes=8'hF7; value=duration_min_tens; end
            3'd4: begin anodes=8'hEF; value=elapsed_sec_ones; end
            3'd5: begin anodes=8'hDF; value=elapsed_sec_tens; end
            3'd6: begin anodes=8'hBF; value=elapsed_min_ones; dp=1'b0; end
            3'd7: begin anodes=8'h7F; value=elapsed_min_tens; end
        endcase
        case (value)
            4'd0: segments=7'b0000001; 4'd1: segments=7'b1001111;
            4'd2: segments=7'b0010010; 4'd3: segments=7'b0000110;
            4'd4: segments=7'b1001100; 4'd5: segments=7'b0100100;
            4'd6: segments=7'b0100000; 4'd7: segments=7'b0001111;
            4'd8: segments=7'b0000000; 4'd9: segments=7'b0000100;
            default: segments=7'b1111111;
        endcase
    end
endmodule
