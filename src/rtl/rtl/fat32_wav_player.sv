// SPDX-License-Identifier: MIT
// Read-only MVP: MBR, FAT32, first root-directory sector, TRACK001.WAV.
// WAV: canonical 44-byte header, unsigned PCM, mono, 8-bit, 48000 Hz.
// IMPORTANT: file clusters MUST be physically contiguous. FAT chain traversal
// is deliberately not implemented in this revision.
module fat32_wav_player (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        sd_ready,
    input  logic        sd_busy,
    input  logic        sd_done,
    input  logic        sd_error,
    output logic        read_req,
    output logic [31:0] read_lba,
    input  logic [7:0]  data,
    input  logic        data_valid,
    input  logic [8:0]  data_index,
    input  logic        sample_tick,
    output logic [7:0]  sample,
    output logic        playing,
    output logic [7:0]  status
);
    localparam int FIFO_ADDR_BITS = 12;
    localparam int FIFO_DEPTH     = 1 << FIFO_ADDR_BITS;
    localparam int FIFO_WATERMARK = FIFO_DEPTH - 512;
    localparam logic [87:0] TARGET_FILE = "TRACK001WAV";

    typedef enum logic [3:0] {
        ST_WAIT_SD,
        ST_REQ_MBR,
        ST_WAIT_MBR,
        ST_REQ_BPB,
        ST_WAIT_BPB,
        ST_CALC_ROOT,
        ST_REQ_DIR,
        ST_WAIT_DIR,
        ST_REQ_WAV,
        ST_WAIT_WAV,
        ST_DRAIN,
        ST_FAIL
    } state_t;

    state_t state;

    logic [31:0] partition_lba;
    logic [7:0]  partition_type;
    logic        mbr_signature_ok;
    logic [31:0] fat_size;
    logic [31:0] root_cluster;
    logic [31:0] data_region_lba;
    logic [31:0] root_directory_lba;
    logic [15:0] reserved_sectors;
    logic [1:0]  number_of_fats;
    logic [2:0]  cluster_shift;
    logic        cluster_size_valid;
    logic        bytes_per_sector_valid;

    logic [87:0] dir_name;
    logic [7:0]  dir_attributes;
    logic [15:0] dir_cluster_hi;
    logic [15:0] dir_cluster_lo;
    logic [31:0] dir_file_size;
    logic        file_found;
    logic [31:0] file_start_cluster;
    logic [31:0] file_size;
    logic [31:0] first_sector_lba;
    logic [31:0] sector_offset;

    logic [31:0] file_byte_position;
    logic [31:0] payload_size;
    logic [31:0] payload_bytes_queued;
    logic        header_bad;

    // This array has no reset and is read synchronously so that Vivado can
    // infer a compact block RAM rather than a large LUT-based async-read mux.
    (* ram_style = "block" *) logic [7:0] audio_ram [0:FIFO_DEPTH-1];
    logic [FIFO_ADDR_BITS-1:0] fifo_wr_ptr;
    logic [FIFO_ADDR_BITS-1:0] fifo_rd_ptr;
    logic [FIFO_ADDR_BITS:0]   fifo_count;
    logic [7:0]               fifo_read_data;
    logic                     fifo_read_valid;
    logic                     fifo_push;
    logic                     fifo_pop;

    wire fifo_has_space = fifo_count < FIFO_DEPTH;
    wire fifo_can_fetch = fifo_count <= FIFO_WATERMARK;

    // Check only the header fields required by the exact supported format.
    // No 44-byte register array or variable-index read mux is necessary.
    function automatic logic header_byte_ok (
        input logic [5:0] position,
        input logic [7:0] value
    );
        begin
            case (position)
                6'd0:  header_byte_ok = (value == "R");
                6'd1:  header_byte_ok = (value == "I");
                6'd2:  header_byte_ok = (value == "F");
                6'd3:  header_byte_ok = (value == "F");
                6'd8:  header_byte_ok = (value == "W");
                6'd9:  header_byte_ok = (value == "A");
                6'd10: header_byte_ok = (value == "V");
                6'd11: header_byte_ok = (value == "E");
                6'd12: header_byte_ok = (value == "f");
                6'd13: header_byte_ok = (value == "m");
                6'd14: header_byte_ok = (value == "t");
                6'd15: header_byte_ok = (value == " ");
                6'd16: header_byte_ok = (value == 8'd16);
                6'd17, 6'd18, 6'd19: header_byte_ok = (value == 8'h00);
                6'd20: header_byte_ok = (value == 8'h01); // PCM
                6'd21: header_byte_ok = (value == 8'h00);
                6'd22: header_byte_ok = (value == 8'h01); // mono
                6'd23: header_byte_ok = (value == 8'h00);
                6'd24: header_byte_ok = (value == 8'h80); // 48000 Hz
                6'd25: header_byte_ok = (value == 8'hBB);
                6'd26, 6'd27: header_byte_ok = (value == 8'h00);
                6'd28: header_byte_ok = (value == 8'h80); // byte rate = 48000
                6'd29: header_byte_ok = (value == 8'hBB);
                6'd30, 6'd31: header_byte_ok = (value == 8'h00);
                6'd32: header_byte_ok = (value == 8'h01); // block align
                6'd33: header_byte_ok = (value == 8'h00);
                6'd34: header_byte_ok = (value == 8'h08); // 8 bits
                6'd35: header_byte_ok = (value == 8'h00);
                6'd36: header_byte_ok = (value == "d");
                6'd37: header_byte_ok = (value == "a");
                6'd38: header_byte_ok = (value == "t");
                6'd39: header_byte_ok = (value == "a");
                default: header_byte_ok = 1'b1; // RIFF size and data size
            endcase
        end
    endfunction

    always_comb begin
        fifo_push = 1'b0;
        fifo_pop  = 1'b0;

        if (state == ST_WAIT_WAV && data_valid && fifo_has_space &&
            !header_bad && file_byte_position >= 32'd44 &&
            file_byte_position < file_size &&
            payload_bytes_queued < payload_size) begin
            fifo_push = 1'b1;
        end

        if (sample_tick && playing && fifo_count != 0) begin
            fifo_pop = 1'b1;
        end
    end

    // Inferred simple dual-port synchronous RAM, one write and one read.
    // Deliberately keep reset and presentation logic OUT of the RAM process.
    always_ff @(posedge clk) begin
        if (fifo_push) begin
            audio_ram[fifo_wr_ptr] <= data;
        end
        if (fifo_pop) begin
            fifo_read_data <= audio_ram[fifo_rd_ptr];
        end
    end

    // One-sample tick of latency is harmless: a read at tick N is used at N+1.
    // This preserves continuous playback while enabling synchronous RAM reads.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state                  <= ST_WAIT_SD;
            read_req               <= 1'b0;
            read_lba               <= 32'd0;
            sample                 <= 8'h80;
            playing                <= 1'b0;
            status                 <= 8'd0;
            partition_lba          <= 32'd0;
            partition_type         <= 8'd0;
            mbr_signature_ok       <= 1'b0;
            fat_size               <= 32'd0;
            root_cluster           <= 32'd0;
            data_region_lba        <= 32'd0;
            root_directory_lba     <= 32'd0;
            reserved_sectors       <= 16'd0;
            number_of_fats         <= 2'd0;
            cluster_shift          <= 3'd0;
            cluster_size_valid     <= 1'b0;
            bytes_per_sector_valid <= 1'b0;
            dir_name               <= 88'd0;
            dir_attributes         <= 8'd0;
            dir_cluster_hi         <= 16'd0;
            dir_cluster_lo         <= 16'd0;
            dir_file_size          <= 32'd0;
            file_found             <= 1'b0;
            file_start_cluster     <= 32'd0;
            file_size              <= 32'd0;
            first_sector_lba       <= 32'd0;
            sector_offset          <= 32'd0;
            file_byte_position     <= 32'd0;
            payload_size           <= 32'd0;
            payload_bytes_queued   <= 32'd0;
            header_bad             <= 1'b0;
            fifo_wr_ptr            <= '0;
            fifo_rd_ptr            <= '0;
            fifo_count             <= '0;
            fifo_read_valid        <= 1'b0;
        end else begin
            read_req <= 1'b0;

            // Occupancy has one writer. Concurrent push+pop leaves it constant.
            case ({fifo_push, fifo_pop})
                2'b10: fifo_count <= fifo_count + 1'b1;
                2'b01: fifo_count <= fifo_count - 1'b1;
                default: ;
            endcase

            if (fifo_push) begin
                fifo_wr_ptr          <= fifo_wr_ptr + 1'b1;
                payload_bytes_queued <= payload_bytes_queued + 32'd1;
                playing              <= 1'b1;
                status               <= 8'h05;
            end

            if (fifo_pop) begin
                fifo_rd_ptr <= fifo_rd_ptr + 1'b1;
            end

            if (sample_tick) begin
                sample          <= (playing && fifo_read_valid) ? fifo_read_data : 8'h80;
                fifo_read_valid <= fifo_pop;
            end

            if (sd_error) begin
                state   <= ST_FAIL;
                status  <= 8'hE0;
                playing <= 1'b0;
            end else begin
                case (state)
                    ST_WAIT_SD: if (sd_ready) begin
                        status <= 8'h01;
                        state  <= ST_REQ_MBR;
                    end

                    ST_REQ_MBR: if (!sd_busy) begin
                        read_lba <= 32'd0;
                        read_req <= 1'b1;
                        state    <= ST_WAIT_MBR;
                    end

                    ST_WAIT_MBR: begin
                        if (data_valid) begin
                            case (data_index)
                                9'd450: partition_type        <= data;
                                9'd454: partition_lba[7:0]  <= data;
                                9'd455: partition_lba[15:8] <= data;
                                9'd456: partition_lba[23:16]<= data;
                                9'd457: partition_lba[31:24]<= data;
                                9'd510: mbr_signature_ok    <= (data == 8'h55);
                                9'd511: mbr_signature_ok    <= mbr_signature_ok && (data == 8'hAA);
                                default: ;
                            endcase
                        end
                        if (sd_done) begin
                            if (partition_lba != 0 && mbr_signature_ok &&
                                (partition_type == 8'h0B || partition_type == 8'h0C ||
                                 partition_type == 8'h1B || partition_type == 8'h1C)) begin
                                status <= 8'h02;
                                state  <= ST_REQ_BPB;
                            end else begin
                                status <= 8'hE1;
                                state  <= ST_FAIL;
                            end
                        end
                    end

                    ST_REQ_BPB: if (!sd_busy) begin
                        read_lba <= partition_lba;
                        read_req <= 1'b1;
                        state    <= ST_WAIT_BPB;
                    end

                    ST_WAIT_BPB: begin
                        if (data_valid) begin
                            case (data_index)
                                9'd11: bytes_per_sector_valid <= (data == 8'h00);
                                9'd12: bytes_per_sector_valid <= bytes_per_sector_valid && (data == 8'h02);
                                9'd13: begin
                                    cluster_size_valid <= 1'b1;
                                    case (data)
                                        8'd1:   cluster_shift <= 3'd0;
                                        8'd2:   cluster_shift <= 3'd1;
                                        8'd4:   cluster_shift <= 3'd2;
                                        8'd8:   cluster_shift <= 3'd3;
                                        8'd16:  cluster_shift <= 3'd4;
                                        8'd32:  cluster_shift <= 3'd5;
                                        8'd64:  cluster_shift <= 3'd6;
                                        8'd128: cluster_shift <= 3'd7;
                                        default: cluster_size_valid <= 1'b0;
                                    endcase
                                end
                                9'd14: reserved_sectors[7:0]   <= data;
                                9'd15: reserved_sectors[15:8]  <= data;
                                9'd16: number_of_fats          <= data[1:0];
                                9'd36: fat_size[7:0]          <= data;
                                9'd37: fat_size[15:8]         <= data;
                                9'd38: fat_size[23:16]        <= data;
                                9'd39: fat_size[31:24]        <= data;
                                9'd44: root_cluster[7:0]      <= data;
                                9'd45: root_cluster[15:8]     <= data;
                                9'd46: root_cluster[23:16]    <= data;
                                9'd47: root_cluster[31:24]    <= data;
                                default: ;
                            endcase
                        end

                        if (sd_done) begin
                            if (!bytes_per_sector_valid || !cluster_size_valid ||
                                root_cluster < 2 || fat_size == 0 ||
                                reserved_sectors == 0 ||
                                (number_of_fats != 1 && number_of_fats != 2)) begin
                                status <= 8'hE3;
                                state  <= ST_FAIL;
                            end else begin
                                // FAT count is restricted to 1 or 2: no 32x8 multiplier.
                                data_region_lba <= partition_lba + reserved_sectors +
                                    ((number_of_fats == 2) ? (fat_size << 1) : fat_size);
                                status <= 8'h03;
                                state  <= ST_CALC_ROOT;
                            end
                        end
                    end

                    // Separate the two wide address calculations for timing closure.
                    ST_CALC_ROOT: begin
                        root_directory_lba <= data_region_lba +
                            ((root_cluster - 32'd2) << cluster_shift);
                        state <= ST_REQ_DIR;
                    end

                    ST_REQ_DIR: if (!sd_busy) begin
                        read_lba <= root_directory_lba;
                        read_req <= 1'b1;
                        state    <= ST_WAIT_DIR;
                    end

                    ST_WAIT_DIR: begin
                        if (data_valid) begin
                            case (data_index[4:0])
                                5'd0:  dir_name[87:80]      <= data;
                                5'd1:  dir_name[79:72]      <= data;
                                5'd2:  dir_name[71:64]      <= data;
                                5'd3:  dir_name[63:56]      <= data;
                                5'd4:  dir_name[55:48]      <= data;
                                5'd5:  dir_name[47:40]      <= data;
                                5'd6:  dir_name[39:32]      <= data;
                                5'd7:  dir_name[31:24]      <= data;
                                5'd8:  dir_name[23:16]      <= data;
                                5'd9:  dir_name[15:8]       <= data;
                                5'd10: dir_name[7:0]        <= data;
                                5'd11: dir_attributes       <= data;
                                5'd20: dir_cluster_hi[7:0] <= data;
                                5'd21: dir_cluster_hi[15:8]<= data;
                                5'd26: dir_cluster_lo[7:0] <= data;
                                5'd27: dir_cluster_lo[15:8]<= data;
                                5'd28: dir_file_size[7:0]   <= data;
                                5'd29: dir_file_size[15:8]  <= data;
                                5'd30: dir_file_size[23:16] <= data;
                                5'd31: begin
                                    dir_file_size[31:24] <= data;
                                    if (!file_found && dir_name == TARGET_FILE &&
                                        !dir_attributes[3] && !dir_attributes[4] &&
                                        dir_attributes != 8'h0F) begin
                                        file_found         <= 1'b1;
                                        file_start_cluster <= {dir_cluster_hi, dir_cluster_lo};
                                        file_size          <= {data, dir_file_size[23:0]};
                                    end
                                end
                                default: ;
                            endcase
                        end

                        if (sd_done) begin
                            if (file_found && file_start_cluster >= 2 && file_size >= 44) begin
                                first_sector_lba   <= data_region_lba +
                                    ((file_start_cluster - 32'd2) << cluster_shift);
                                sector_offset      <= 32'd0;
                                file_byte_position <= 32'd0;
                                payload_size       <= 32'd0;
                                header_bad         <= 1'b0;
                                status             <= 8'h04;
                                state              <= ST_REQ_WAV;
                            end else begin
                                status <= 8'hE4;
                                state  <= ST_FAIL;
                            end
                        end
                    end

                    ST_REQ_WAV: if (!sd_busy && fifo_can_fetch) begin
                        read_lba <= first_sector_lba + sector_offset;
                        read_req <= 1'b1;
                        state    <= ST_WAIT_WAV;
                    end

                    ST_WAIT_WAV: begin
                        if (data_valid && file_byte_position < file_size) begin
                            if (file_byte_position < 40 &&
                                !header_byte_ok(file_byte_position[5:0], data)) begin
                                header_bad <= 1'b1;
                            end

                            // Payload byte count in a canonical 44-byte WAV header.
                            case (file_byte_position)
                                32'd40: payload_size[7:0]   <= data;
                                32'd41: payload_size[15:8]  <= data;
                                32'd42: payload_size[23:16] <= data;
                                32'd43: payload_size[31:24] <= data;
                                default: ;
                            endcase
                            file_byte_position <= file_byte_position + 32'd1;
                        end

                        if (sd_done) begin
                            if (sector_offset == 0 &&
                                (header_bad || payload_size > (file_size - 32'd44))) begin
                                status  <= 8'hE5;
                                playing <= 1'b0;
                                state   <= ST_FAIL;
                            end else if (file_byte_position >= file_size ||
                                         payload_bytes_queued >= payload_size) begin
                                state <= ST_DRAIN;
                            end else begin
                                sector_offset <= sector_offset + 32'd1;
                                state         <= ST_REQ_WAV;
                            end
                        end
                    end

                    // Finish on an audio tick, after the last prefetched sample
                    // has spent a full sample period on the PWM output.
                    ST_DRAIN: if (sample_tick && fifo_count == 0 && !fifo_read_valid) begin
                        playing <= 1'b0;
                        sample  <= 8'h80;
                        status  <= 8'h06;
                    end

                    ST_FAIL: begin
                        playing <= 1'b0;
                        sample  <= 8'h80;
                    end

                    default: state <= ST_FAIL;
                endcase
            end
        end
    end
endmodule
