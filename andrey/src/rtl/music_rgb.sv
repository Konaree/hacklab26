// Two RGB LEDs on Nexys A7, synchronized to real PCM envelope level.
// LED16: blue -> cyan/green -> yellow/orange -> red as volume rises,
//        and PWM brightness tracks volume.
// LED17: brief white flashes on sharp increases in the audio envelope.
// LEDs are active high. No additional audio filtering/FFT is needed.
module music_rgb (
    input  logic       clk,
    input  logic       rst,
    input  logic       active,
    input  logic [7:0] level,
    input  logic       level_valid,
    output logic       LED16_R,
    output logic       LED16_G,
    output logic       LED16_B,
    output logic       LED17_R,
    output logic       LED17_G,
    output logic       LED17_B
);
    logic [7:0] divider;
    logic [7:0] pwm_count;
    logic [7:0] brightness;
    logic [7:0] last_level;
    logic [3:0] flash_windows;
    logic [3:0] cooldown_windows;
    logic [7:0] red_duty, green_duty, blue_duty;
    logic [7:0] flash_duty;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            divider         <= '0;
            pwm_count       <= '0;
            last_level      <= '0;
            flash_windows   <= '0;
            cooldown_windows<= '0;
        end else begin
            divider <= divider + 8'd1;
            if (divider == 8'hFF)
                pwm_count <= pwm_count + 8'd1;

            if (!active) begin
                last_level       <= '0;
                flash_windows    <= '0;
                cooldown_windows <= '0;
            end else if (level_valid) begin
                last_level <= level;
                if (flash_windows != 0)
                    flash_windows <= flash_windows - 4'd1;
                if (cooldown_windows != 0)
                    cooldown_windows <= cooldown_windows - 4'd1;
                // Beat-like transient, not a claim of true tempo detection.
                if (level >= 8'd20 &&
                    {1'b0, level} > ({1'b0, last_level} + 9'd10) &&
                    cooldown_windows == 0) begin
                    flash_windows    <= 4'd5;
                    cooldown_windows <= 4'd8;
                end
            end
        end
    end

    always_comb begin
        // Saturating level-to-brightness gain. Fully off at silence/pause.
        if (!active || level < 8'd2)
            brightness = 8'd0;
        else if (level >= 8'd64)
            brightness = 8'hFF;
        else
            brightness = {level[5:0], 2'b00};

        red_duty   = 8'd0;
        green_duty = 8'd0;
        blue_duty  = 8'd0;
        if (level < 8'd12) begin
            blue_duty = brightness;
        end else if (level < 8'd32) begin
            green_duty = brightness;
            blue_duty  = brightness >> 1;
        end else if (level < 8'd56) begin
            red_duty   = brightness >> 1;
            green_duty = brightness;
        end else begin
            red_duty   = brightness;
            green_duty = brightness >> 3;
        end

        flash_duty = (active && flash_windows != 0) ? 8'hFF : 8'd0;

        LED16_R = active && (pwm_count < red_duty);
        LED16_G = active && (pwm_count < green_duty);
        LED16_B = active && (pwm_count < blue_duty);
        LED17_R = active && (pwm_count < flash_duty);
        LED17_G = active && (pwm_count < flash_duty);
        LED17_B = active && (pwm_count < flash_duty);
    end
endmodule
