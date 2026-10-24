`timescale 1ns/1ps
// Eight active-low Nexys A7 digits. Each group displays MM:SS.
module music_sevenseg (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] elapsed_seconds,
    input  logic [15:0] duration_seconds,
    output logic [6:0]  segments,
    output logic        dp,
    output logic [7:0]  anodes
);
    logic [16:0] scan_count;
    logic [2:0] digit;
    logic [3:0] value;
    logic [5:0] elapsed_sec, duration_sec;
    logic [6:0] elapsed_min, duration_min;
    logic [15:0] elapsed_min_raw, duration_min_raw;
    logic [3:0] elapsed_sec_tens, elapsed_sec_ones;
    logic [3:0] elapsed_min_tens, elapsed_min_ones;
    logic [3:0] duration_sec_tens, duration_sec_ones;
    logic [3:0] duration_min_tens, duration_min_ones;

    always_comb begin
        elapsed_sec      = elapsed_seconds % 16'd60;
        duration_sec     = duration_seconds % 16'd60;
        elapsed_min_raw  = elapsed_seconds / 16'd60;
        duration_min_raw = duration_seconds / 16'd60;
        elapsed_min      = (elapsed_min_raw > 16'd99) ? 7'd99 : elapsed_min_raw[6:0];
        duration_min     = (duration_min_raw > 16'd99) ? 7'd99 : duration_min_raw[6:0];

        elapsed_sec_tens  = elapsed_sec / 6'd10;
        elapsed_sec_ones  = elapsed_sec % 6'd10;
        elapsed_min_tens  = elapsed_min / 7'd10;
        elapsed_min_ones  = elapsed_min % 7'd10;
        duration_sec_tens = duration_sec / 6'd10;
        duration_sec_ones = duration_sec % 6'd10;
        duration_min_tens = duration_min / 7'd10;
        duration_min_ones = duration_min % 7'd10;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            scan_count <= 17'd0;
            digit      <= 3'd0;
        end else if (scan_count == 17'd49_999) begin
            scan_count <= 17'd0;
            digit      <= digit + 1'b1;
        end else begin
            scan_count <= scan_count + 1'b1;
        end
    end

    always_comb begin
        anodes   = 8'hFF;
        dp       = 1'b1;
        value    = 4'd0;
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
            4'd0: segments=7'b0000001;
            4'd1: segments=7'b1001111;
            4'd2: segments=7'b0010010;
            4'd3: segments=7'b0000110;
            4'd4: segments=7'b1001100;
            4'd5: segments=7'b0100100;
            4'd6: segments=7'b0100000;
            4'd7: segments=7'b0001111;
            4'd8: segments=7'b0000000;
            4'd9: segments=7'b0000100;
            default: segments=7'b1111111;
        endcase
    end
endmodule
