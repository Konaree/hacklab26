`timescale 1ns / 1ps

// Smoke test of FAT32/WAV parsing and streaming, independent of physical SD.
// Run this TB as simulation top in Vivado xsim (not synthesis).
module tb_fat32_wav_player;
    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic        rst_n;
    logic        sd_ready;
    logic        sd_busy;
    logic        sd_done;
    logic        sd_error;
    logic        read_req;
    logic [31:0] read_lba;
    logic [7:0]  data;
    logic        data_valid;
    logic [8:0]  data_index;
    logic        sample_tick;
    logic [7:0]  sample;
    logic        playing;
    logic [7:0]  status;

    int unsigned sample_timer;
    int unsigned non_silent_samples;
    int unsigned sectors_read;

    fat32_wav_player dut (
        .clk         (clk),
        .rst_n       (rst_n),
        .sd_ready    (sd_ready),
        .sd_busy     (sd_busy),
        .sd_done     (sd_done),
        .sd_error    (sd_error),
        .read_req    (read_req),
        .read_lba    (read_lba),
        .data        (data),
        .data_valid  (data_valid),
        .data_index  (data_index),
        .sample_tick (sample_tick),
        .sample      (sample),
        .playing     (playing),
        .status      (status)
    );

    // Test partition: MBR sector 0, BPB sector 1, root sector 161,
    // WAV begins in sector 169, file size 44 + 768 = 812 bytes.
    function automatic logic [7:0] sector_byte (
        input logic [31:0] lba,
        input integer index
    );
        logic [31:0] file_pos;
        begin
            sector_byte = 8'h00;
            case (lba)
                32'd0: begin
                    case (index)
                        450: sector_byte = 8'h0C;
                        454: sector_byte = 8'h01;
                        510: sector_byte = 8'h55;
                        511: sector_byte = 8'hAA;
                        default: ;
                    endcase
                end

                32'd1: begin
                    case (index)
                        11: sector_byte = 8'h00;
                        12: sector_byte = 8'h02;
                        13: sector_byte = 8'd8;
                        14: sector_byte = 8'd32;
                        16: sector_byte = 8'd2;
                        36: sector_byte = 8'd64;
                        44: sector_byte = 8'd2;
                        default: ;
                    endcase
                end

                32'd161: begin
                    case (index)
                        0: sector_byte = "T";
                        1: sector_byte = "R";
                        2: sector_byte = "A";
                        3: sector_byte = "C";
                        4: sector_byte = "K";
                        5, 6: sector_byte = "0";
                        7: sector_byte = "1";
                        8: sector_byte = "W";
                        9: sector_byte = "A";
                        10: sector_byte = "V";
                        11: sector_byte = 8'h20;
                        26: sector_byte = 8'd3;
                        28: sector_byte = 8'h2C; // 812 = 0x032C
                        29: sector_byte = 8'h03;
                        default: ;
                    endcase
                end

                32'd169, 32'd170: begin
                    file_pos = (lba - 32'd169) * 32'd512 + index;
                    case (file_pos)
                        0: sector_byte = "R";
                        1: sector_byte = "I";
                        2, 3: sector_byte = "F";
                        4: sector_byte = 8'h24; // RIFF size = 804
                        5: sector_byte = 8'h03;
                        8: sector_byte = "W";
                        9: sector_byte = "A";
                        10: sector_byte = "V";
                        11: sector_byte = "E";
                        12: sector_byte = "f";
                        13: sector_byte = "m";
                        14: sector_byte = "t";
                        15: sector_byte = " ";
                        16: sector_byte = 8'd16;
                        20, 22, 32: sector_byte = 8'd1;
                        24, 28: sector_byte = 8'h80;
                        25, 29: sector_byte = 8'hBB;
                        34: sector_byte = 8'd8;
                        36: sector_byte = "d";
                        37: sector_byte = "a";
                        38: sector_byte = "t";
                        39: sector_byte = "a";
                        40: sector_byte = 8'h00;
                        41: sector_byte = 8'h03;
                        default: begin
                            if (file_pos >= 44 && file_pos < 812)
                                sector_byte = 8'hC0;
                        end
                    endcase
                end
                default: ;
            endcase
        end
    endfunction

    // Not a cycle-accurate SD device; only models valid-data/done handshake.
    initial begin : sd_sector_model
        logic [31:0] requested_lba;
        rst_n       = 1'b0;
        sd_ready    = 1'b0;
        sd_busy     = 1'b1;
        sd_done     = 1'b0;
        sd_error    = 1'b0;
        data        = 8'd0;
        data_index  = 9'd0;
        data_valid  = 1'b0;
        sectors_read= 0;

        repeat (10) @(negedge clk);
        rst_n    = 1'b1;
        sd_ready = 1'b1;
        sd_busy  = 1'b0;

        forever begin
            @(negedge clk);
            if (read_req) begin
                requested_lba = read_lba;
                sd_busy      = 1'b1;
                sectors_read = sectors_read + 1;
                for (int i = 0; i < 512; i++) begin
                    @(negedge clk);
                    data       = sector_byte(requested_lba, i);
                    data_index = 9'(i);
                    data_valid = 1'b1;
                    @(negedge clk);
                    data_valid = 1'b0;
                end
                @(negedge clk);
                sd_busy = 1'b0;
                sd_done = 1'b1;
                @(negedge clk);
                sd_done = 1'b0;
            end
        end
    end

    initial begin : sample_clock
        sample_tick        = 1'b0;
        sample_timer       = 0;
        non_silent_samples = 0;
        forever begin
            @(negedge clk);
            if (sample_timer == 12) begin
                sample_timer = 0;
                sample_tick  = 1'b1;
                if (sample != 8'h80)
                    non_silent_samples++;
            end else begin
                sample_timer++;
                sample_tick = 1'b0;
            end
        end
    end

    initial begin : assertions
        wait (rst_n);
        wait (status == 8'h05);
        $display("Playback started after %0d sector reads", sectors_read);
        wait (status == 8'h06);
        if (non_silent_samples < 700)
            $fatal(1, "Lost PCM samples: observed only %0d", non_silent_samples);
        $display("PASS: complete playback, %0d non-silent samples", non_silent_samples);
        $finish;
    end

    initial begin
        #5_000_000;
        $fatal(1, "TIMEOUT status=0x%02h sector_count=%0d", status, sectors_read);
    end
endmodule
