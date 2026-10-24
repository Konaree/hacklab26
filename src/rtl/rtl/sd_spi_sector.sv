// SDHC/SDXC SPI reader. CLK=100MHz; SPI initially 250kHz, then 12.5MHz.
// Stream bytes [0..511] via data_valid (one-clock pulse). Command timeout/error code exposed.
module sd_spi_sector(input logic clk,rst_n,input logic miso,
 output logic sck,mosi,cs_n,sd_reset_n,
 input logic read_req,input logic [31:0] read_lba,
 output logic initialized,busy,sector_done,error,
 output logic [7:0] data,output logic data_valid,
 output logic [8:0] data_index,output logic [7:0] error_code);
 logic bstart,bdone,bbusy,bsck,bmosi;
 logic [7:0] btx,brx;
 logic slow;
 // First byte engine runs at fixed 250kHz for simplicity; safe, but ~16kB/s.
 // 100MHz/(2*25)=2MHz for the present divider; SD initialization requires <=400kHz.
 // Use DIV=250 for 200kHz; afterwards still 200kHz (~20kB/s), insufficient for 48kHz PCM.
 // Therefore instantiate switchable fast/slow SPI byte engines via runtime divisor below.
 spi_byte_variable byteio(.clk(clk),.rst_n(rst_n),.start(bstart),.tx(btx),
  .miso(miso),.divisor(slow?16'd250:16'd4),.sck(bsck),.mosi(bmosi),.busy(bbusy),.done(bdone),.rx(brx));
 assign sck=bsck;assign mosi=bmosi;
 typedef enum logic [4:0] {POWER,DUMMY,ISSUE,SEND,GET_R1,GET_EXTRA,AFTER_CMD,
   WAIT_TOKEN,READ_DATA,READ_CRC,FINISH,FAULT,READY} state_t;
 state_t state;
 logic [7:0] cmd,crc,r1;
 logic [31:0] arg;
 logic [2:0] pos;
 logic [2:0] extra;
 logic [7:0] dummy_count;
 logic [31:0] timeout_count;
 logic [31:0] wait_count;
 logic [31:0] ocr;
 logic [9:0] index;
 logic [1:0] crcleft;
 logic init_acmd;
 logic [31:0] latched_lba;
 // Each byte operation: set btx in state, bstart for one clock, then await bdone.
 logic byte_wait;
 logic [7:0] tx_pending;
 always_comb begin
  // One-byte SPI transfer launcher, states keep tx_pending constant until done.
  bstart= !bbusy && !byte_wait && (state==DUMMY||state==SEND||state==GET_R1||state==GET_EXTRA||state==WAIT_TOKEN||state==READ_DATA||state==READ_CRC);
  btx=tx_pending;
 end
 always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   state<=POWER;slow<=1;cs_n<=1;sd_reset_n<=0;initialized<=0;busy<=1;sector_done<=0;error<=0;error_code<=0;
   data<=0;data_valid<=0;data_index<=0;cmd<=0;crc<=0;arg<=0;pos<=0;extra<=0;
   dummy_count<=0;timeout_count<=0;wait_count<=0;ocr<=0;index<=0;crcleft<=0;init_acmd<=0;latched_lba<=0;byte_wait<=0;tx_pending<=8'hff;
  end else begin
   sector_done<=0;data_valid<=0;
   if(bstart) byte_wait<=1;
   if(bdone) byte_wait<=0;
   case(state)
    POWER: begin
     cs_n<=1;sd_reset_n<=0;
     if(wait_count==32'd2_000_000) begin wait_count<=0;dummy_count<=0;tx_pending<=8'hff;state<=DUMMY;end
     else wait_count<=wait_count+1'b1;
    end
    DUMMY: if(bdone) begin
      if(dummy_count==9) begin cmd<=0;arg<=0;crc<=8'h95;cs_n<=0;pos<=0;state<=SEND;tx_pending<=8'h40;end
      else dummy_count<=dummy_count+1'b1;
    end
    ISSUE: begin
     cs_n<=0;pos<=0;tx_pending<=8'h40|cmd;timeout_count<=0;state<=SEND;
    end
    SEND: if(bdone) begin
      if(pos==5) begin pos<=0;tx_pending<=8'hff;state<=GET_R1;end
      else begin
       pos<=pos+1'b1;
       case(pos)
        0:tx_pending<=arg[31:24];
        1:tx_pending<=arg[23:16];
        2:tx_pending<=arg[15:8];
        3:tx_pending<=arg[7:0];
        4:tx_pending<=crc;
        default:tx_pending<=8'hff;
       endcase
      end
    end
    GET_R1: if(bdone) begin
     if(!brx[7]) begin
      r1<=brx;
      if(cmd==8 || cmd==58) begin extra<=4;ocr<=0;state<=GET_EXTRA;end
      else state<=AFTER_CMD;
     end else if(timeout_count>32'd100) begin error<=1;error_code<=8'h01;state<=FAULT;end
     else timeout_count<=timeout_count+1'b1;
    end
    GET_EXTRA: if(bdone) begin
      ocr<={ocr[23:0],brx};
      if(extra==1) state<=AFTER_CMD;
      extra<=extra-1'b1;
    end
    AFTER_CMD: begin
     case(cmd)
      0: if(r1==8'h01) begin cmd<=8;arg<=32'h000001aa;crc<=8'h87;state<=ISSUE;end
         else begin error<=1;error_code<=8'h10;state<=FAULT;end
      8: if(r1==8'h01 && ocr[11:0]==12'h1aa) begin cmd<=55;arg<=0;crc<=8'h01;state<=ISSUE;end
         else begin error<=1;error_code<=8'h11;state<=FAULT;end
      55: if(r1<=1) begin cmd<=41;arg<=32'h40000000;crc<=8'h01;state<=ISSUE;end
          else begin error<=1;error_code<=8'h12;state<=FAULT;end
      41: if(r1==0) begin cmd<=58;arg<=0;crc<=8'h01;state<=ISSUE;end
          else if(r1==1 && wait_count<32'd5000) begin wait_count<=wait_count+1'b1;cmd<=55;arg<=0;crc<=8'h01;state<=ISSUE;end
          else begin error<=1;error_code<=8'h13;state<=FAULT;end
      58: if(r1==0 && ocr[30]) begin initialized<=1;slow<=0;cs_n<=1;busy<=0;state<=READY;end
          else begin error<=1;error_code<=8'h14;state<=FAULT;end
      17: if(r1==0) begin timeout_count<=0;state<=WAIT_TOKEN;end
          else begin error<=1;error_code<=8'h17;state<=FAULT;end
      default: begin error<=1;error_code<=8'hff;state<=FAULT;end
     endcase
    end
    READY: if(read_req) begin
     latched_lba<=read_lba;cmd<=17;arg<=read_lba;crc<=8'h01;busy<=1;state<=ISSUE;
    end
    WAIT_TOKEN: if(bdone) begin
      if(brx==8'hfe) begin index<=0;tx_pending<=8'hff;state<=READ_DATA;end
      else if(timeout_count>32'd200000) begin error<=1;error_code<=8'h20;state<=FAULT;end
      else timeout_count<=timeout_count+1'b1;
    end
    READ_DATA: if(bdone) begin
      data<=brx;data_index<=index[8:0];data_valid<=1;
      if(index==511) begin crcleft<=2;state<=READ_CRC;end
      else index<=index+1'b1;
    end
    READ_CRC: if(bdone) begin
      if(crcleft==1) state<=FINISH;
      else crcleft<=crcleft-1'b1;
    end
    FINISH: begin cs_n<=1;sector_done<=1;busy<=0;state<=READY;end
    FAULT: begin cs_n<=1;busy<=0;end
    default: state<=FAULT;
   endcase
  end
 end
endmodule

module spi_byte_variable(input logic clk,rst_n,start,input logic [7:0] tx,
 input logic miso,input logic [15:0] divisor,
 output logic sck,mosi,busy,done,output logic [7:0] rx);
 logic [15:0] divcnt;
 logic [2:0] bitno;
 logic [7:0] txshift,rxshift;
 logic phase;
 always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin sck<=0;mosi<=1;busy<=0;done<=0;rx<=0;divcnt<=0;bitno<=0;txshift<=0;rxshift<=0;phase<=0;end
  else begin
   done<=0;
   if(!busy) begin
    sck<=0;
    if(start) begin busy<=1;divcnt<=divisor-1'b1;bitno<=7;txshift<=tx;rxshift<=0;mosi<=tx[7];phase<=0;end
   end else if(divcnt!=0) divcnt<=divcnt-1'b1;
   else begin
    divcnt<=divisor-1'b1;
    if(!phase) begin sck<=1;rxshift<={rxshift[6:0],miso};phase<=1;end
    else begin
     sck<=0;phase<=0;
     if(bitno==0) begin busy<=0;done<=1;rx<=rxshift;mosi<=1;end
     else begin bitno<=bitno-1'b1;txshift<={txshift[6:0],1'b1};mosi<=txshift[6];end
    end
   end
  end
 end
endmodule
