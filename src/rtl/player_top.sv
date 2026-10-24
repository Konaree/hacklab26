module player_top (
    input  logic       CLK100MHZ,
    input  logic       CPU_RESETN,
    input  logic       PS2_CLK,
    input  logic       PS2_DATA,
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic       VGA_HS,
    output logic       VGA_VS,
    output logic [5:0] LED
);
    logic  clk_40mhz;
    logic  clk_40_locked;
    logic  rst_100 = ~CPU_RESETN;
    logic  rst_40  = ~CPU_RESETN | ~clk_40_locked;

    vga_clk40 u_vga_clk40 (
        .clk_in1  (CLK100MHZ),
        .reset    (rst_100),
        .clk_out1 (clk_40mhz),
        .locked   (clk_40_locked)
    );

    logic [7:0] scan_code;
    logic       scan_valid;
    logic [1:0] song_id;
    logic [1:0] player_state;
    logic       restart_pulse;

    ps2_receiver ps2 (
        .clk(CLK100MHZ), 
        .rst(rst_100),
        .ps2_clk(PS2_CLK), 
        .ps2_data(PS2_DATA),
        .scan_code(scan_code), 
        .scan_valid(scan_valid)
    );

    player_controller ctrl (
        .clk(CLK100MHZ), 
        .rst(rst_100),
        .scan_code(scan_code), 
        .scan_valid(scan_valid),
        .song_id(song_id), 
        .player_state(player_state),
        .restart_pulse(restart_pulse)
    );

    vga_player video (
        .clk_40mhz(clk_40mhz), 
        .rst(rst_40),
        .song_id(song_id), 
        .player_state(player_state),
        .VGA_R(VGA_R), 
        .VGA_G(VGA_G), 
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), 
        .VGA_VS(VGA_VS)
    );

    assign LED[0] = song_id == 2'd0;
    assign LED[1] = song_id == 2'd1;
    assign LED[2] = song_id == 2'd2;
    assign LED[3] = player_state == 2'd1;
    assign LED[4] = player_state == 2'd2;
    assign LED[5] = player_state == 2'd0;
    
endmodule
