module spi_byte #(parameter int DIV=25)(
 input logic clk,rst_n,start,input logic [7:0] tx,
 input logic miso,output logic sck,mosi,busy,done,output logic [7:0] rx
);
 localparam int CW=$clog2(DIV+1);
 logic [CW-1:0] divcnt;
 logic [2:0] bitno;
 logic [7:0] txshift,rxshift;
 logic phase;
 always_ff @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin sck<=0;mosi<=1;busy<=0;done<=0;rx<=0;divcnt<=0;bitno<=0;txshift<=0;rxshift<=0;phase<=0;end
  else begin
   done<=0;
   if(!busy) begin
    sck<=0;
    if(start) begin busy<=1;divcnt<=DIV-1;bitno<=7;txshift<=tx;rxshift<=0;mosi<=tx[7];phase<=0;end
   end else if(divcnt!=0) divcnt<=divcnt-1'b1;
   else begin
    divcnt<=DIV-1;
    if(!phase) begin sck<=1;rxshift<={rxshift[6:0],miso};phase<=1;end
    else begin
     sck<=0;phase<=0;
     if(bitno==0) begin busy<=0;done<=1;rx<={rxshift[6:0],miso};mosi<=1;end
     else begin bitno<=bitno-1'b1;txshift<={txshift[6:0],1'b1};mosi<=txshift[6];end
    end
   end
  end
 end
endmodule
