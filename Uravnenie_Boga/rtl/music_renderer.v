`timescale 1ns/1ps
// Streaming-service style player UI with a simulated, continuously moving bar.
module music_renderer (
    input wire [10:0] x, input wire [9:0] y,
    input wire [1:0] track,
    input wire [9:0] progress_pixels,
    output reg [11:0] rgb
);
    function [34:0] glyph;
        input [7:0] c;
        begin
            case (c)
                "0": glyph={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
                "1": glyph={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
                "2": glyph={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
                "3": glyph={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
                "A": glyph={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
                "C": glyph={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
                "E": glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
                "G": glyph={5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
                "I": glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
                "K": glyph={5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
                "L": glyph={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
                "M": glyph={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
                "N": glyph={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
                "O": glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "P": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
                "R": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
                "S": glyph={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
                "T": glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
                "U": glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "W": glyph={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
                "Y": glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
                default: glyph=35'd0;
            endcase
        end
    endfunction

    function glyph_hit;
        input [10:0] px;
        input [9:0] py;
        input integer x0;
        input integer y0;
        input [1:0] scale;
        input [7:0] code;
        reg [34:0] bits;
        integer col,row;
        begin
            glyph_hit=1'b0;
            if (px>=x0 && px<x0+(5<<scale) && py>=y0 && py<y0+(7<<scale)) begin
                col=(px-x0)>>scale; row=(py-y0)>>scale;
                bits=glyph(code);
                glyph_hit=bits[(6-row)*5+(4-col)];
            end
        end
    endfunction

    wire title_my = glyph_hit(x,y,32,35,2'd1,"M") ||
                    glyph_hit(x,y,44,35,2'd1,"Y");
    wire title_music = glyph_hit(x,y,82,35,2'd1,"M") ||
                       glyph_hit(x,y,94,35,2'd1,"U") ||
                       glyph_hit(x,y,106,35,2'd1,"S") ||
                       glyph_hit(x,y,118,35,2'd1,"I") ||
                       glyph_hit(x,y,130,35,2'd1,"C");
    wire label_all = glyph_hit(x,y,34,112,2'd0,"A") ||
                     glyph_hit(x,y,40,112,2'd0,"L") ||
                     glyph_hit(x,y,46,112,2'd0,"L");
    wire label_tracks = glyph_hit(x,y,64,112,2'd0,"T") ||
                        glyph_hit(x,y,70,112,2'd0,"R") ||
                        glyph_hit(x,y,76,112,2'd0,"A") ||
                        glyph_hit(x,y,82,112,2'd0,"C") ||
                        glyph_hit(x,y,88,112,2'd0,"K") ||
                        glyph_hit(x,y,94,112,2'd0,"S");
    wire now_playing = glyph_hit(x,y,370,414,2'd1,"N") ||
                       glyph_hit(x,y,382,414,2'd1,"O") ||
                       glyph_hit(x,y,394,414,2'd1,"W") ||
                       glyph_hit(x,y,418,414,2'd1,"P") ||
                       glyph_hit(x,y,430,414,2'd1,"L") ||
                       glyph_hit(x,y,442,414,2'd1,"A") ||
                       glyph_hit(x,y,454,414,2'd1,"Y") ||
                       glyph_hit(x,y,466,414,2'd1,"I") ||
                       glyph_hit(x,y,478,414,2'd1,"N") ||
                       glyph_hit(x,y,490,414,2'd1,"G");

    integer row_y;
    integer row_id;
    integer n;
    reg [11:0] art_color;
    always @* begin
        rgb=12'h080;
        row_y=0; row_id=0; art_color=12'h000;

        // Header and main panels.
        if (y<10'd92) rgb=12'h101;
        if (x<11'd292 && y>=10'd92 && y<10'd480) rgb=12'h111;
        if (x>=11'd300 && y>=10'd92 && y<10'd480) rgb=12'h101;
        if (y>=10'd480) rgb=12'h090;

        if (title_my || title_music) rgb=12'hFFF;
        if (label_all || label_tracks) rgb=12'h9AB;

        // Three playlist rows. Track selection comes from the PS/2 controller.
        for (n=0;n<3;n=n+1) begin
            row_y=145+100*n;
            if (x>=11'd24 && x<11'd278 && y>=row_y && y<row_y+82) begin
                if (track==n) rgb=12'h243;
                else rgb=12'h171;
                if (x>=11'd37 && x<11'd99 && y>=row_y+10 && y<row_y+72) begin
                    case (n)
                        0: rgb=12'hB46;
                        1: rgb=12'h368;
                        default: rgb=12'hA73;
                    endcase
                    if (x[4]==y[4]) rgb=(n==0)?12'hF9C:(n==1)?12'h8DF:12'hFD8;
                    if (x>=11'd58 && x<11'd78 && y>=row_y+28 && y<row_y+54)
                        rgb=12'h102;
                end
                if (glyph_hit(x,y,116,row_y+22,2'd0,"T") ||
                    glyph_hit(x,y,122,row_y+22,2'd0,"R") ||
                    glyph_hit(x,y,128,row_y+22,2'd0,"A") ||
                    glyph_hit(x,y,134,row_y+22,2'd0,"C") ||
                    glyph_hit(x,y,140,row_y+22,2'd0,"K")) rgb=12'hFFF;
                if (n==0 && (glyph_hit(x,y,152,row_y+22,2'd0,"0") ||
                             glyph_hit(x,y,158,row_y+22,2'd0,"1"))) rgb=12'hFFF;
                if (n==1 && (glyph_hit(x,y,152,row_y+22,2'd0,"0") ||
                             glyph_hit(x,y,158,row_y+22,2'd0,"2"))) rgb=12'hFFF;
                if (n==2 && (glyph_hit(x,y,152,row_y+22,2'd0,"0") ||
                             glyph_hit(x,y,158,row_y+22,2'd0,"3"))) rgb=12'hFFF;
            end
        end

        // Large abstract cover art placeholder; SD images will replace it later.
        if (x>=11'd330 && x<11'd710 && y>=10'd118 && y<10'd398) begin
            case (track)
                2'd1: art_color=12'h137;
                2'd2: art_color=12'h742;
                default: art_color=12'h526;
            endcase
            rgb=art_color;
            if (x[5]==y[5]) rgb=(track==0)?12'hF46:(track==1)?12'h5CF:12'hFD4;
            if (x>=11'd410 && x<11'd630 && y>=10'd246 && y<10'd270)
                rgb=art_color;
            if (x>=11'd500 && x<11'd540 && y>=10'd170 && y<10'd346)
                rgb=12'hFFF;
            if (x>=11'd470 && x<11'd570 && y>=10'd238 && y<10'd278)
                rgb=12'h102;
            if (x>=(11'd330+progress_pixels/2) &&
                x<(11'd330+progress_pixels/2+5) && y>=10'd118 && y<10'd398)
                rgb=12'hFFF;
        end

        if (now_playing) rgb=12'h9AB;

        // Progress rail and continuously animated fill.
        if (x>=11'd100 && x<11'd700 && y>=10'd520 && y<10'd530)
            rgb=12'h344;
        if (x>=11'd100 && x<(11'd100+progress_pixels) &&
            y>=10'd520 && y<10'd530) rgb=12'h5DF;
        if (x>=11'd94 && x<11'd106 && y>=10'd519 && y<10'd531)
            rgb=12'hFFF;
        if (x>=(11'd94+progress_pixels) && x<(11'd106+progress_pixels) &&
            y>=10'd519 && y<10'd531) rgb=12'hFFF;
        if (x>=11'd24 && x<11'd776 && y>=10'd506 && y<10'd508)
            rgb=12'h233;
    end
endmodule
