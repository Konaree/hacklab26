module auto_sleep_timer #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer INACTIVE_SEC = 60
)(
    input  logic clk,
    input  logic rst,
    input  logic enabled,
    input  logic key_activity,
    input  logic motion_pulse,
    output logic sleep_req
);
    localparam integer TICK_W = (CLK_HZ <= 1) ? 1 : $clog2(CLK_HZ);
    localparam integer SEC_W = (INACTIVE_SEC <= 1) ? 1 : $clog2(INACTIVE_SEC + 1);
    logic [TICK_W-1:0] cycle_count;
    logic [SEC_W-1:0] seconds_idle;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cycle_count  <= '0;
            seconds_idle <= '0;
            sleep_req    <= 1'b0;
        end else if (!enabled || motion_pulse || key_activity) begin
            cycle_count  <= '0;
            seconds_idle <= '0;
            sleep_req    <= 1'b0;
        end else if (!sleep_req) begin
            if (cycle_count == CLK_HZ-1) begin
                cycle_count <= '0;
                if (seconds_idle == INACTIVE_SEC-1) begin
                    seconds_idle <= INACTIVE_SEC;
                    sleep_req <= 1'b1;
                end else seconds_idle <= seconds_idle + 1'b1;
            end else cycle_count <= cycle_count + 1'b1;
        end
    end

endmodule
