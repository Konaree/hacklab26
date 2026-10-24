`timescale 1ns/1ps
// Eight active-low Nexys A7 digits. Each group is minutes then seconds: MM.SS.
module music_sevenseg (
    input wire clk, input wire rst,
    input wire [7:0] elapsed_seconds,
    input wire [7:0] duration_seconds,
    output reg [6:0] segments,
    output reg dp,
    output reg [7:0] anodes
);
    reg [16:0] scan_count;
    reg [2:0] digit;
    reg [3:0] value;
    reg [7:0] elapsed_min, duration_min;
    reg [5:0] elapsed_sec, duration_sec;
    wire [3:0] elapsed_sec_tens = elapsed_sec / 10;
    wire [3:0] elapsed_sec_ones = elapsed_sec % 10;
    wire [3:0] elapsed_min_tens = elapsed_min / 10;
    wire [3:0] elapsed_min_ones = elapsed_min % 10;
    wire [3:0] duration_sec_tens = duration_sec / 10;
    wire [3:0] duration_sec_ones = duration_sec % 10;
    wire [3:0] duration_min_tens = duration_min / 10;
    wire [3:0] duration_min_ones = duration_min % 10;

    always @* begin
        elapsed_sec = elapsed_seconds % 60;
        elapsed_min = elapsed_seconds / 60;
        duration_sec = duration_seconds % 60;
        duration_min = duration_seconds / 60;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin scan_count <= 0; digit <= 0; end
        else if (scan_count == 17'd49_999) begin
            scan_count <= 0;
            digit <= digit + 1'b1;
        end else scan_count <= scan_count + 1'b1;
    end

    always @* begin
        anodes = 8'hFF;
        dp = 1'b1;
        value = 4'd0;
        case (digit)
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
            0: segments=7'b0000001; 1: segments=7'b1001111;
            2: segments=7'b0010010; 3: segments=7'b0000110;
            4: segments=7'b1001100; 5: segments=7'b0100100;
            6: segments=7'b0100000; 7: segments=7'b0001111;
            8: segments=7'b0000000; 9: segments=7'b0000100;
            default: segments=7'b1111111;
        endcase
    end
endmodule
