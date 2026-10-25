module audio_spectrum_meter (
    input  logic        clk,
    input  logic        rst,
    input  logic        sample_tick,
    input  logic        active,
    input  logic [7:0]  sample,
    output logic [31:0] band_levels
);
    localparam integer LP_COUNT = 7;
    localparam integer BAND_COUNT = 8;
    localparam integer WINDOW_BITS = 10;

    logic signed [15:0] sample_integer;
    logic signed [15:0] sample_centered;
    logic signed [15:0] lowpass [0:LP_COUNT-1];
    logic signed [15:0] lowpass_next [0:LP_COUNT-1];
    logic signed [16:0] band_delta [0:BAND_COUNT-1];
    logic [16:0] band_magnitude [0:BAND_COUNT-1];
    logic [33:0] band_square [0:BAND_COUNT-1];
    logic [42:0] band_accum [0:BAND_COUNT-1];
    logic [9:0] window_count;
    integer comb_i;
    integer seq_i;

    function automatic logic [3:0] level_from_mean_square(input logic [15:0] value);
        begin
            if      (value < 16'd16)   level_from_mean_square = 4'd0;
            else if (value < 16'd64)   level_from_mean_square = 4'd1;
            else if (value < 16'd144)  level_from_mean_square = 4'd2;
            else if (value < 16'd256)  level_from_mean_square = 4'd3;
            else if (value < 16'd400)  level_from_mean_square = 4'd4;
            else if (value < 16'd625)  level_from_mean_square = 4'd5;
            else if (value < 16'd900)  level_from_mean_square = 4'd6;
            else if (value < 16'd1296) level_from_mean_square = 4'd7;
            else if (value < 16'd1764) level_from_mean_square = 4'd8;
            else if (value < 16'd2304) level_from_mean_square = 4'd9;
            else if (value < 16'd3025) level_from_mean_square = 4'd10;
            else if (value < 16'd3844) level_from_mean_square = 4'd11;
            else if (value < 16'd4900) level_from_mean_square = 4'd12;
            else if (value < 16'd6400) level_from_mean_square = 4'd13;
            else if (value < 16'd8100) level_from_mean_square = 4'd14;
            else                        level_from_mean_square = 4'd15;
        end
    endfunction

    always_comb begin
        sample_integer = $signed({1'b0, sample}) - 16'sd128;
        sample_centered = sample_integer <<< 8;
        band_delta[0] = {{1{lowpass[6][15]}}, lowpass[6]};
        for (comb_i = 1; comb_i < 7; comb_i = comb_i + 1)
            band_delta[comb_i] =
                $signed({lowpass[6-comb_i][15], lowpass[6-comb_i]}) -
                $signed({lowpass[7-comb_i][15], lowpass[7-comb_i]});
        band_delta[7] = $signed({sample_centered[15], sample_centered}) -
                         $signed({lowpass[0][15], lowpass[0]});
        for (comb_i = 0; comb_i < BAND_COUNT; comb_i = comb_i + 1) begin
            band_magnitude[comb_i] = band_delta[comb_i][16] ? -band_delta[comb_i] : band_delta[comb_i];
            band_square[comb_i] = {17'd0, band_magnitude[comb_i]} *
                                  {17'd0, band_magnitude[comb_i]};
        end
    end

    generate
        for (genvar g = 0; g < LP_COUNT; g = g + 1) begin : g_filter
            always_comb begin
                lowpass_next[g] = lowpass[g] +
                    (($signed({sample_centered[15], sample_centered}) -
                      $signed({lowpass[g][15], lowpass[g]})) >>> (g + 1));
            end
        end
    endgenerate

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            window_count <= 10'd0;
            band_levels <= 32'd0;
            for (seq_i = 0; seq_i < LP_COUNT; seq_i = seq_i + 1)
                lowpass[seq_i] <= 16'sd0;
            for (seq_i = 0; seq_i < BAND_COUNT; seq_i = seq_i + 1)
                band_accum[seq_i] <= 43'd0;
        end else if (sample_tick) begin
            if (!active) begin
                window_count <= 10'd0;
                band_levels <= 32'd0;
                for (seq_i = 0; seq_i < LP_COUNT; seq_i = seq_i + 1)
                    lowpass[seq_i] <= 16'sd0;
                for (seq_i = 0; seq_i < BAND_COUNT; seq_i = seq_i + 1)
                    band_accum[seq_i] <= 43'd0;
            end else begin
                for (seq_i = 0; seq_i < LP_COUNT; seq_i = seq_i + 1)
                    lowpass[seq_i] <= lowpass_next[seq_i];

                if (window_count == 10'd1023) begin
                    window_count <= 10'd0;
                    for (seq_i = 0; seq_i < BAND_COUNT; seq_i = seq_i + 1) begin
                        band_levels[seq_i*4 +: 4] <= level_from_mean_square(
                            (band_accum[seq_i] + band_square[seq_i]) >> (WINDOW_BITS + 16));
                        band_accum[seq_i] <= 43'd0;
                    end
                end else begin
                    window_count <= window_count + 10'd1;
                    for (seq_i = 0; seq_i < BAND_COUNT; seq_i = seq_i + 1)
                        band_accum[seq_i] <= band_accum[seq_i] + band_square[seq_i];
                end
            end
        end
    end

endmodule
