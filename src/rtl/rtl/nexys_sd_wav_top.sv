module nexys_sd_wav_top (
 input logic CLK100MHZ,CPU_RESETN,SD_DAT0,
 output logic SD_RESET,SD_SCK,SD_CMD,SD_DAT3,
 output wire AUD_PWM,output logic AUD_SD,
 output logic [7:0] LED
);
 logic rst_n;
 assign rst_n=CPU_RESETN;
 logic initialized,busy,sector_done,error,read_req,data_valid,playing;
 logic [31:0] read_lba;
 logic [7:0] data,error_code,status,sample;
 logic [8:0] data_index;
 logic [31:0] sample_phase;
 logic sample_tick;
 logic [7:0] pwm_count;
 logic pwm_bit;
 // About 48000.007 Hz from 100MHz input.
 localparam logic [31:0] SAMPLE_STEP=32'd2061584;
 always_ff @(posedge CLK100MHZ or negedge rst_n) begin
  if(!rst_n) begin sample_phase<=0;sample_tick<=0;pwm_count<=0;end
  else begin
   {sample_tick,sample_phase}<={1'b0,sample_phase}+{1'b0,SAMPLE_STEP};
   pwm_count<=pwm_count+1'b1;
  end
 end
 sd_spi_sector sd(
  .clk(CLK100MHZ),.rst_n(rst_n),.miso(SD_DAT0),.sck(SD_SCK),.mosi(SD_CMD),
  .cs_n(SD_DAT3),.sd_reset_n(SD_RESET),.read_req(read_req),.read_lba(read_lba),
  .initialized(initialized),.busy(busy),.sector_done(sector_done),.error(error),
  .data(data),.data_valid(data_valid),.data_index(data_index),.error_code(error_code));
 fat32_wav_player player(
  .clk(CLK100MHZ),.rst_n(rst_n),.sd_ready(initialized),.sd_busy(busy),
  .sd_done(sector_done),.sd_error(error),.read_req(read_req),.read_lba(read_lba),
  .data(data),.data_valid(data_valid),.data_index(data_index),.sample_tick(sample_tick),
  .sample(sample),.playing(playing),.status(status));
 assign pwm_bit=(pwm_count<sample);
 assign AUD_PWM=pwm_bit?1'bz:1'b0;
 assign AUD_SD=playing;
 assign LED={error,status[6:0]};
endmodule
