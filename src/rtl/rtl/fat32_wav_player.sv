// Simplified, read-only FAT32 WAV player.
// Requirements: MBR partition 1, FAT32, sector 512B, root directory entry TRACK001WAV
// in FIRST root sector, contiguous file clusters, canonical 44-byte PCM WAV header,
// mono unsigned 8-bit 48000Hz. No FAT-chain traversal in this MVP.
module fat32_wav_player(input logic clk,rst_n,
 input logic sd_ready,sd_busy,sd_done,sd_error,
 output logic read_req,output logic [31:0] read_lba,
 input logic [7:0] data,input logic data_valid,input logic [8:0] data_index,
 input logic sample_tick,
 output logic [7:0] sample,output logic playing,
 output logic [7:0] status);
 typedef enum logic [3:0] {WAIT_SD,REQ_MBR,WAIT_MBR,REQ_BPB,WAIT_BPB,
 REQ_DIR,WAIT_DIR,REQ_WAV,WAIT_WAV,ENDPLAY,FAIL} st_t;
 st_t state;
 logic [31:0] part_lba,fat_size,root_cluster,root_lba,data_lba;
 logic [15:0] reserved;
 logic [7:0] fats,spc;
 logic [31:0] first_cluster,file_size,first_lba;
 logic [31:0] sector_no,file_byte_offset;
 logic [31:0] bytes_left;
 logic [31:0] audio_rate;
 logic [15:0] audio_fmt,channels,bits;
 logic [31:0] riff_len;
 logic [87:0] dir_name;
 logic [7:0] dir_attr;
 logic [15:0] cluster_hi,cluster_lo;
 logic [31:0] dir_size;
 logic found;
 logic [7:0] fifo [0:4095];
 logic [11:0] wr_ptr,rd_ptr;
 wire [11:0] used=wr_ptr-rd_ptr;
 wire can_fetch=(used<=12'd3072);
 logic [7:0] header [0:43];
 logic [31:0] wav_payload_size;
 logic header_ok;
 logic [31:0] wav_data_sent;
 logic [31:0] wav_total_sent;
 logic [31:0] expected_lba;
 integer j;

 always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=WAIT_SD;read_req<=0;read_lba<=0;status<=0;playing<=0;sample<=8'h80;
   part_lba<=0;fat_size<=0;root_cluster<=0;root_lba<=0;data_lba<=0;reserved<=0;fats<=0;spc<=0;
   first_cluster<=0;file_size<=0;first_lba<=0;sector_no<=0;file_byte_offset<=0;bytes_left<=0;
   audio_rate<=0;audio_fmt<=0;channels<=0;bits<=0;riff_len<=0;dir_name<=0;dir_attr<=0;
   cluster_hi<=0;cluster_lo<=0;dir_size<=0;found<=0;wr_ptr<=0;rd_ptr<=0;
   wav_payload_size<=0;header_ok<=0;wav_data_sent<=0;wav_total_sent<=0;expected_lba<=0;
  end else begin
   read_req<=0;
   if(sd_error) begin state<=FAIL;status<=8'hE0;playing<=0;end
   else begin
    if(sample_tick && playing) begin
     if(used!=0) begin sample<=fifo[rd_ptr];rd_ptr<=rd_ptr+1'b1;end
     else sample<=8'h80;
    end
    case(state)
     WAIT_SD: if(sd_ready) begin status<=8'h01;state<=REQ_MBR;end
     REQ_MBR: if(!sd_busy) begin read_lba<=0;read_req<=1;state<=WAIT_MBR;end
     WAIT_MBR: begin
      if(data_valid) begin
       case(data_index)
        9'd454: part_lba[7:0]<=data;
        9'd455: part_lba[15:8]<=data;
        9'd456: part_lba[23:16]<=data;
        9'd457: part_lba[31:24]<=data;
       endcase
      end
      if(sd_done) begin if(part_lba!=0) begin state<=REQ_BPB;status<=8'h02;end else begin state<=FAIL;status<=8'hE1;end end
     end
     REQ_BPB: if(!sd_busy) begin read_lba<=part_lba;read_req<=1;state<=WAIT_BPB;end
     WAIT_BPB: begin
      if(data_valid) begin
       case(data_index)
        9'd11: if(data!=8'd0) begin status<=8'hE2;state<=FAIL;end // 512 bytes = 00 02
        9'd12: if(data!=8'd2) begin status<=8'hE2;state<=FAIL;end
        9'd13: spc<=data;
        9'd14: reserved[7:0]<=data;
        9'd15: reserved[15:8]<=data;
        9'd16: fats<=data;
        9'd36: fat_size[7:0]<=data;
        9'd37: fat_size[15:8]<=data;
        9'd38: fat_size[23:16]<=data;
        9'd39: fat_size[31:24]<=data;
        9'd44: root_cluster[7:0]<=data;
        9'd45: root_cluster[15:8]<=data;
        9'd46: root_cluster[23:16]<=data;
        9'd47: root_cluster[31:24]<=data;
       endcase
      end
      if(sd_done && state==WAIT_BPB) begin
       if(spc==0 || fats==0 || root_cluster<2 || fat_size==0) begin state<=FAIL;status<=8'hE3;end
       else begin
        data_lba<=part_lba+{16'b0,reserved}+fat_size*{24'b0,fats};
        root_lba<=part_lba+{16'b0,reserved}+fat_size*{24'b0,fats}+(root_cluster-2)*{24'b0,spc};
        status<=8'h03;state<=REQ_DIR;
       end
      end
     end
     REQ_DIR: if(!sd_busy) begin read_lba<=root_lba;read_req<=1;state<=WAIT_DIR;found<=0;end
     WAIT_DIR: begin
      if(data_valid) begin
       case(data_index[4:0])
        0: dir_name[87:80]<=data;
        1: dir_name[79:72]<=data;
        2: dir_name[71:64]<=data;
        3: dir_name[63:56]<=data;
        4: dir_name[55:48]<=data;
        5: dir_name[47:40]<=data;
        6: dir_name[39:32]<=data;
        7: dir_name[31:24]<=data;
        8: dir_name[23:16]<=data;
        9: dir_name[15:8]<=data;
        10:dir_name[7:0]<=data;
        11:dir_attr<=data;
        20:cluster_hi[7:0]<=data;
        21:cluster_hi[15:8]<=data;
        26:cluster_lo[7:0]<=data;
        27:cluster_lo[15:8]<=data;
        28:dir_size[7:0]<=data;
        29:dir_size[15:8]<=data;
        30:dir_size[23:16]<=data;
        31: begin
          dir_size[31:24]<=data;
          if(!found && dir_name==88'h545241434b303031574156 && dir_attr[3:0]!=4'hf && !dir_attr[3]) begin
           // 'TRACK001WAV' 11 bytes
           found<=1;
           first_cluster<={cluster_hi,cluster_lo};
           file_size<={data,dir_size[23:0]};
          end
         end
       endcase
      end
      if(sd_done) begin
       if(found && first_cluster>=2 && file_size>=44) begin
        first_lba<=data_lba+(first_cluster-2)*{24'b0,spc};sector_no<=0;
        file_byte_offset<=0;wav_total_sent<=0;wav_data_sent<=0;
        status<=8'h04;state<=REQ_WAV;
       end else begin status<=8'hE4;state<=FAIL;end
      end
     end
     REQ_WAV: if(!sd_busy && can_fetch) begin
      read_lba<=first_lba+sector_no;read_req<=1;state<=WAIT_WAV;
     end
     WAIT_WAV: begin
      if(data_valid && (file_byte_offset+{23'b0,data_index})<file_size) begin
       if(file_byte_offset==0 && data_index<44) header[data_index]<=data;
       if(file_byte_offset==0 && data_index==43) begin
        audio_fmt<={header[21],header[20]};channels<={header[23],header[22]};
        audio_rate<={header[27],header[26],header[25],header[24]};
        bits<={header[35],header[34]};
        wav_payload_size<={data,header[42],header[41],header[40]};
        header_ok<=(header[0]==8'h52 && header[1]==8'h49 && header[2]==8'h46 && header[3]==8'h46 &&
                    header[8]==8'h57 && header[9]==8'h41 && header[10]==8'h56 && header[11]==8'h45 &&
                    header[12]==8'h66 && header[13]==8'h6d && header[14]==8'h74 && header[15]==8'h20 &&
                    header[16]==8'd16 && header[17]==0 && header[18]==0 && header[19]==0 &&
                    header[20]==1 && header[21]==0 && header[22]==1 && header[23]==0 &&
                    header[24]==8'h80 && header[25]==8'hbb && header[26]==0 && header[27]==0 &&
                    header[34]==8 && header[35]==0 &&
                    header[36]==8'h64 && header[37]==8'h61 && header[38]==8'h74 && header[39]==8'h61);
       end
       if(file_byte_offset+{23'b0,data_index}>=44 && header_ok && wav_data_sent<wav_payload_size && used<12'd4095) begin
        fifo[wr_ptr]<=data;wr_ptr<=wr_ptr+1'b1;wav_data_sent<=wav_data_sent+1'b1;
        playing<=1;status<=8'h05;
       end
      end
      if(sd_done) begin
       if(!header_ok && sector_no==0) begin status<=8'hE5;state<=FAIL;playing<=0;end
       else if(file_byte_offset+512>=file_size || wav_data_sent>=wav_payload_size) begin state<=ENDPLAY;end
       else begin sector_no<=sector_no+1'b1;file_byte_offset<=file_byte_offset+512;state<=REQ_WAV;end
      end
     end
     ENDPLAY: if(used==0) begin playing<=0;sample<=8'h80;status<=8'h06;end
     FAIL: begin playing<=0;sample<=8'h80;end
     default: state<=FAIL;
    endcase
   end
  end
 end
endmodule
