// Audio envelope meter for unsigned 8-bit PCM samples (silence = 128).
// 1024-sample windows at 48 kHz -> ~21.3 ms between level updates.
module audio_level_meter (
    input  logic        clk,
    input  logic        rst,
    input  logic        sample_tick,
    input  logic        active,
    input  logic [7:0]  sample,
    output logic [15:0] led,
    output logic [7:0]  level,
    output logic        level_valid
);
    logic [7:0]  magnitude;
    logic [17:0] sum;
    logic [9:0]  window_count;

    always_comb begin
        magnitude = (sample >= 8'd128) ? (sample - 8'd128) : (8'd128 - sample);
        // 16 increasing thresholds: height of the volume bar is driven by PCM.
        led[0]  = active && level >= 8'd2;
        led[1]  = active && level >= 8'd4;
        led[2]  = active && level >= 8'd6;
        led[3]  = active && level >= 8'd8;
        led[4]  = active && level >= 8'd10;
        led[5]  = active && level >= 8'd12;
        led[6]  = active && level >= 8'd15;
        led[7]  = active && level >= 8'd18;
        led[8]  = active && level >= 8'd22;
        led[9]  = active && level >= 8'd26;
        led[10] = active && level >= 8'd31;
        led[11] = active && level >= 8'd37;
        led[12] = active && level >= 8'd44;
        led[13] = active && level >= 8'd52;
        led[14] = active && level >= 8'd62;
        led[15] = active && level >= 8'd74;
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sum          <= '0;
            window_count <= '0;
            level        <= '0;
            level_valid  <= 1'b0;
        end else begin
            level_valid <= 1'b0;
            if (!active) begin
                sum          <= '0;
                window_count <= '0;
                level        <= '0;
            end else if (sample_tick) begin
                if (window_count == 10'd1023) begin
                    level        <= (sum + {10'd0, magnitude}) >> 10;
                    level_valid  <= 1'b1;
                    sum          <= '0;
                    window_count <= '0;
                end else begin
                    sum          <= sum + {10'd0, magnitude};
                    window_count <= window_count + 10'd1;
                end
            end
        end
    end
endmodule
