module nexys_auto_sleep #(
    parameter integer CLK_HZ = 100_000_000,
    parameter integer INACTIVE_SEC = 10,
    parameter integer MOTION_THRESHOLD = 6
)(
    input  logic clk_100,
    input  logic clk_40,
    input  logic rst_100,
    input  logic SW0,
    input  logic key_activity,
    input  logic ACL_MISO,
    output logic ACL_MOSI,
    output logic ACL_SCLK,
    output logic ACL_CSN,
    output logic sleep_100,
    output logic blank_40,
    output logic sensor_ready,
    output logic motion_pulse
);
    (* ASYNC_REG="TRUE" *) logic sw_meta, sw_sync;
    (* ASYNC_REG="TRUE" *) logic blank_meta, blank_sync;

    logic sample_valid;
    logic signed [7:0] ax, ay, az;
    logic raw_sleep;

    always_ff @(posedge clk_100 or posedge rst_100) begin
        if (rst_100) begin
            sw_meta <= 1'b0;
            sw_sync <= 1'b0;
        end else begin
            sw_meta <= SW0;
            sw_sync <= sw_meta;
        end
    end

    adxl362_reader #(.CLK_HZ(CLK_HZ)) accel (
        .clk(clk_100),
        .rst(rst_100),
        .ACL_MISO(ACL_MISO),
        .ACL_MOSI(ACL_MOSI),
        .ACL_SCLK(ACL_SCLK),
        .ACL_CSN(ACL_CSN),
        .sensor_ready(sensor_ready),
        .sample_valid(sample_valid),
        .ax(ax), .ay(ay), .az(az)
    );

    motion_detector #(.MOTION_THRESHOLD(MOTION_THRESHOLD)) motion (
        .clk(clk_100),
        .rst(rst_100),
        .sample_valid(sample_valid),
        .ax(ax), .ay(ay), .az(az),
        .motion_pulse(motion_pulse)
    );

    auto_sleep_timer #(.CLK_HZ(CLK_HZ), .INACTIVE_SEC(INACTIVE_SEC)) idle (
        .clk(clk_100),
        .rst(rst_100),
        .enabled(sw_sync && sensor_ready),
        .key_activity(key_activity),
        .motion_pulse(motion_pulse),
        .sleep_req(raw_sleep)
    );
    assign sleep_100 = raw_sleep && sw_sync && SW0 && sensor_ready;

    always_ff @(posedge clk_40 or posedge rst_100) begin
        if (rst_100) begin
            blank_meta <= 1'b0;
            blank_sync <= 1'b0;
        end else begin
            blank_meta <= sleep_100;
            blank_sync <= blank_meta;
        end
    end

    assign blank_40 = blank_sync;

endmodule
