module motion_detector #(
    parameter integer MOTION_THRESHOLD = 6
)(
    input logic clk,
    input logic rst,
    input logic sample_valid,
    input logic signed [7:0] ax, ay, az,
    output logic motion_pulse
);
    logic have_prev;
    logic signed [7:0] prev_x, prev_y, prev_z;
    logic signed [8:0] dx, dy, dz;
    logic [8:0] abs_x, abs_y, abs_z;
    logic [10:0] change_sum;

    function automatic [8:0] abs9(input logic signed [8:0] x);
        begin
            abs9 = (x < 0) ? $unsigned(-x) : $unsigned(x);
        end
    endfunction

    always_comb begin
        dx = $signed({ax[7], ax}) - $signed({prev_x[7], prev_x});
        dy = $signed({ay[7], ay}) - $signed({prev_y[7], prev_y});
        dz = $signed({az[7], az}) - $signed({prev_z[7], prev_z});
        abs_x = abs9(dx);
        abs_y = abs9(dy);
        abs_z = abs9(dz);
        change_sum = {2'b00, abs_x} + {2'b00, abs_y} + {2'b00, abs_z};
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            have_prev <= 1'b0;
            prev_x <= '0; prev_y <= '0; prev_z <= '0;
            motion_pulse <= 1'b0;
        end else begin
            motion_pulse <= 1'b0;
            if (sample_valid) begin
                if (have_prev && change_sum >= MOTION_THRESHOLD)
                    motion_pulse <= 1'b1;
                have_prev <= 1'b1;
                prev_x <= ax;
                prev_y <= ay;
                prev_z <= az;
            end
        end
    end

endmodule
