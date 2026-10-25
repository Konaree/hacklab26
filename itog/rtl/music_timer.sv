module music_timer (
    input  logic        clk,
    input  logic        rst,
    input  logic [15:0] elapsed_in,
    input  logic [15:0] duration_in,
    input  logic [9:0]  progress_in,
    output logic [15:0] elapsed_seconds,
    output logic [15:0] duration_seconds,
    output logic [9:0]  progress_pixels
);
    (* ASYNC_REG = "TRUE" *) logic [15:0] elapsed_meta, elapsed_sync;
    (* ASYNC_REG = "TRUE" *) logic [15:0] duration_meta, duration_sync;
    (* ASYNC_REG = "TRUE" *) logic [9:0]  progress_meta, progress_sync;

    assign elapsed_seconds  = elapsed_sync;
    assign duration_seconds = duration_sync;
    assign progress_pixels  = progress_sync;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            elapsed_meta    <= 16'd0;
            duration_meta   <= 16'd0;
            progress_meta   <= 10'd0;
            elapsed_sync    <= 16'd0;
            duration_sync   <= 16'd0;
            progress_sync   <= 10'd0;
        end else begin
            elapsed_meta    <= elapsed_in;
            duration_meta   <= duration_in;
            progress_meta   <= progress_in;
            elapsed_sync    <= elapsed_meta;
            duration_sync   <= duration_meta;
            progress_sync   <= progress_meta;
        end
    end

endmodule
