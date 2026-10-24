module player_controller (
    input  logic       clk,
    input  logic       rst,
    input  logic [7:0] scan_code,
    input  logic       scan_valid,
    output logic [1:0] song_id,
    output logic [1:0] player_state,
    output logic       restart_pulse
);
    localparam logic [1:0] STOPPED = 2'd0;
    localparam logic [1:0] PLAYING = 2'd1;
    localparam logic [1:0] PAUSED  = 2'd2;

    logic [6:0] key_held;
    logic       break_prefix;
    logic       extended_prefix;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            song_id         <= 2'd0;
            player_state    <= STOPPED;
            restart_pulse   <= 1'b0;
            break_prefix    <= 1'b0;
            extended_prefix <= 1'b0;
            key_held        <= 7'd0;
        end else begin
            restart_pulse <= 1'b0;
            if (scan_valid) begin
                if (scan_code == 8'hE0) begin
                    extended_prefix <= 1'b1;
                end else if (scan_code == 8'hF0) begin
                    break_prefix <= 1'b1;
                end else begin
                    if (!extended_prefix) begin
                        case (scan_code)
                            8'h16: begin
                                if (break_prefix) key_held[0] <= 1'b0;
                                else if (!key_held[0]) begin
                                    key_held[0]     <= 1'b1;
                                    song_id         <= 2'd0;
                                    player_state    <= STOPPED;
                                    restart_pulse   <= 1'b1;
                                end
                            end
                            8'h1E: begin
                                if (break_prefix) key_held[1] <= 1'b0;
                                else if (!key_held[1]) begin
                                    key_held[1]     <= 1'b1;
                                    song_id         <= 2'd1;
                                    player_state    <= STOPPED;
                                    restart_pulse   <= 1'b1;
                                end
                            end
                            8'h26: begin
                                if (break_prefix) key_held[2] <= 1'b0;
                                else if (!key_held[2]) begin
                                    key_held[2]     <= 1'b1;
                                    song_id         <= 2'd2;
                                    player_state    <= STOPPED;
                                    restart_pulse   <= 1'b1;
                                end
                            end
                            8'h31: begin
                                if (break_prefix) key_held[3] <= 1'b0;
                                else if (!key_held[3]) begin
                                    key_held[3]     <= 1'b1;
                                    song_id         <= (song_id == 2'd2) ? 2'd0 : song_id + 2'd1;
                                    player_state    <= STOPPED;
                                    restart_pulse   <= 1'b1;
                                end
                            end
                            8'h32: begin
                                if (break_prefix) key_held[4] <= 1'b0;
                                else if (!key_held[4]) begin
                                    key_held[4]     <= 1'b1;
                                    song_id         <= (song_id == 2'd0) ? 2'd2 : song_id - 2'd1;
                                    player_state    <= STOPPED;
                                    restart_pulse   <= 1'b1;
                                end
                            end
                            8'h29: begin
                                if (break_prefix) key_held[5] <= 1'b0;
                                else if (!key_held[5]) begin
                                    key_held[5] <= 1'b1;
                                    if (player_state == PLAYING)
                                        player_state <= PAUSED;
                                    else
                                        player_state <= PLAYING;
                                end
                            end
                            8'h1B: begin 
                                if (break_prefix) key_held[6] <= 1'b0;
                                else if (!key_held[6]) begin
                                    key_held[6]     <= 1'b1;
                                    player_state    <= STOPPED;
                                    restart_pulse   <= 1'b1;
                                end
                            end
                            default: ;
                        endcase
                    end
                    break_prefix    <= 1'b0;
                    extended_prefix <= 1'b0;
                end
            end
        end
    end
    
endmodule
