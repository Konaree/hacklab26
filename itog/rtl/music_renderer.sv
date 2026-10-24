`timescale 1ns/1ps
// 800x600 music-player UI. Artwork is stored in a synchronous RGB444 block ROM.
module music_renderer (
    input  logic        clk,
    input  logic [10:0] x,
    input  logic [9:0]  y,
    input  logic [1:0]  track,
    input  logic [15:0] elapsed_seconds,
    input  logic [15:0] duration_seconds,
    input  logic [9:0]  progress_pixels,
    input  logic [31:0] spectrum_levels,
    input  logic        sleep_mode,
    output logic [11:0] rgb
);
    localparam integer COVER_W = 192;
    localparam integer COVER_H = 192;
    localparam integer COVER_PIXELS = COVER_W * COVER_H;
    localparam integer COVER_COUNT = 3;
    localparam integer LOGO_W = 128;
    localparam integer LOGO_H = 48;
    localparam integer LOGO_BASE = COVER_PIXELS*COVER_COUNT;
    localparam integer SLEEP_LOGO_W = 192;
    localparam integer SLEEP_LOGO_H = 52;
    localparam integer SLEEP_LOGO_BASE = LOGO_BASE + LOGO_W*LOGO_H;
    localparam integer ROM_PIXELS = SLEEP_LOGO_BASE + SLEEP_LOGO_W*SLEEP_LOGO_H;

    (* rom_style = "block" *) logic [11:0] cover_rom [0:ROM_PIXELS-1];
    logic [16:0] cover_addr;
    logic cover_mask;
    logic [11:0] base_rgb;
    logic [11:0] cover_rgb_q, base_rgb_q;
    logic cover_mask_q;

    initial $readmemh("music_covers_rgb444.mem", cover_rom);

    function automatic logic [34:0] glyph(input logic [7:0] c);
        begin
            case (c)
                "A": glyph={5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
                "B": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110};
                "C": glyph={5'b01111,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b01111};
                "D": glyph={5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110};
                "E": glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111};
                "F": glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
                "G": glyph={5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110};
                "H": glyph={5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001};
                "I": glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111};
                "J": glyph={5'b00111,5'b00010,5'b00010,5'b00010,5'b10010,5'b10010,5'b01100};
                "K": glyph={5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001};
                "L": glyph={5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111};
                "M": glyph={5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001};
                "N": glyph={5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001};
                "O": glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "P": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
                "Q": glyph={5'b01110,5'b10001,5'b10001,5'b10001,5'b10101,5'b10010,5'b01101};
                "R": glyph={5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001};
                "S": glyph={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
                "T": glyph={5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100};
                "U": glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110};
                "V": glyph={5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100};
                "W": glyph={5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010};
                "X": glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001};
                "Y": glyph={5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100};
                "Z": glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b10000,5'b11111};
                "0": glyph={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
                "1": glyph={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
                "2": glyph={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
                "3": glyph={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
                "4": glyph={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
                "5": glyph={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
                "6": glyph={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
                "7": glyph={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
                "8": glyph={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
                "9": glyph={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
                ".": glyph={5'b00000,5'b00000,5'b00000,5'b00000,5'b00000,5'b00110,5'b00110};
                ":": glyph={5'b00000,5'b00110,5'b00110,5'b00000,5'b00110,5'b00110,5'b00000};
                "-": glyph={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
                "/": glyph={5'b00001,5'b00010,5'b00010,5'b00100,5'b01000,5'b01000,5'b10000};
                default: glyph=35'd0;
            endcase
        end
    endfunction

    function automatic logic glyph_hit(
        input logic [10:0] px,
        input logic [9:0] py,
        input integer x0,
        input integer y0,
        input logic [1:0] scale,
        input logic [7:0] code
    );
        logic [34:0] bits;
        integer col, row;
        begin
            glyph_hit = 1'b0;
            if (px >= x0 && px < x0 + (5 << scale) &&
                py >= y0 && py < y0 + (7 << scale)) begin
                col = (px - x0) >> scale;
                row = (py - y0) >> scale;
                bits = glyph(code);
                glyph_hit = bits[(6-row)*5 + (4-col)];
            end
        end
    endfunction

    // Character lookup for metadata, playlist labels, and the header.
    function automatic logic [7:0] text_char(
        input logic [1:0] selected_track,
        input logic [2:0] field,
        input integer index
    );
        begin
            text_char = 8'h20;
            case (field)
                3'd0: begin // Main title, first line
                    case (selected_track)
                        2'd0: case(index)
                            0:text_char="T"; 1:text_char="E"; 2:text_char="T";
                            3:text_char="R"; 4:text_char="I"; 5:text_char="S";
                            default: ;
                        endcase
                        2'd1: case(index)
                            0:text_char="S"; 1:text_char=" "; 2:text_char="N";
                            3:text_char="A"; 4:text_char="R"; 5:text_char="U";
                            6:text_char="Z"; 7:text_char="H"; 8:text_char="I";
                            9:text_char=" "; 10:text_char="V"; 11:text_char="S";
                            12:text_char="E"; 13:text_char="H";
                            default: ;
                        endcase
                        default: case(index)
                            0:text_char="P"; 1:text_char="A"; 2:text_char="I"; 3:text_char="N";
                            default: ;
                        endcase
                    endcase
                end
                3'd1: if (selected_track == 2'd1) begin // Long title, second line
                    case(index)
                        0:text_char="I"; 1:text_char="Z"; 2:text_char="M";
                        3:text_char="E"; 4:text_char="R"; 5:text_char="E";
                        6:text_char="N"; 7:text_char="I"; 8:text_char="Y";
                        default: ;
                    endcase
                end
                3'd2: begin // Artist
                    case (selected_track)
                        2'd0: case(index)
                            0:text_char="K"; 1:text_char="O"; 2:text_char="R";
                            3:text_char="O"; 4:text_char="B"; 5:text_char="E";
                            6:text_char="Y"; 7:text_char="N"; 8:text_char="I";
                            9:text_char="K"; 10:text_char="I";
                            default: ;
                        endcase
                        2'd1: case(index)
                            0:text_char="G"; 1:text_char="R"; 2:text_char="A";
                            3:text_char="Z"; 4:text_char="H"; 5:text_char="D";
                            6:text_char="A"; 7:text_char="N"; 8:text_char="S";
                            9:text_char="K"; 10:text_char="A"; 11:text_char="Y";
                            12:text_char="A"; 13:text_char=" "; 14:text_char="O";
                            15:text_char="B"; 16:text_char="O"; 17:text_char="R";
                            18:text_char="O"; 19:text_char="N"; 20:text_char="A";
                            default: ;
                        endcase
                        default: case(index)
                            0:text_char="T"; 1:text_char="H"; 2:text_char="R";
                            3:text_char="E"; 4:text_char="E"; 5:text_char=" ";
                            6:text_char="D"; 7:text_char="A"; 8:text_char="Y";
                            9:text_char="S"; 10:text_char=" "; 11:text_char="G";
                            12:text_char="R"; 13:text_char="A"; 14:text_char="C";
                            15:text_char="E";
                            default: ;
                        endcase
                    endcase
                end
                3'd3: begin // Short playlist title
                    case (selected_track)
                        2'd0: case(index)
                            0:text_char="T"; 1:text_char="E"; 2:text_char="T";
                            3:text_char="R"; 4:text_char="I"; 5:text_char="S";
                            default: ;
                        endcase
                        2'd1: case(index)
                            0:text_char="S"; 1:text_char="."; 2:text_char="N";
                            3:text_char="."; 4:text_char="V"; 5:text_char=".";
                            6:text_char="I"; 7:text_char=".";
                            default: ;
                        endcase
                        default: case(index)
                            0:text_char="P"; 1:text_char="A"; 2:text_char="I"; 3:text_char="N";
                            default: ;
                        endcase
                    endcase
                end
                3'd4: begin // Playlist artist labels
                    case (selected_track)
                        2'd0: case(index)
                            0:text_char="K"; 1:text_char="O"; 2:text_char="R";
                            3:text_char="O"; 4:text_char="B"; 5:text_char="E";
                            6:text_char="Y"; 7:text_char="N"; 8:text_char="I";
                            9:text_char="K"; 10:text_char="I";
                            default: ;
                        endcase
                        2'd1: case(index)
                            0:text_char="G"; 1:text_char="R"; 2:text_char="A";
                            3:text_char="Z"; 4:text_char="H"; 5:text_char="D";
                            6:text_char="A"; 7:text_char="N"; 8:text_char="S";
                            9:text_char="K"; 10:text_char="A"; 11:text_char="Y";
                            12:text_char="A"; 13:text_char=" "; 14:text_char="O";
                            15:text_char="B"; 16:text_char="O"; 17:text_char="R";
                            18:text_char="O"; 19:text_char="N"; 20:text_char="A";
                            default: ;
                        endcase
                        default: case(index)
                            0:text_char="T"; 1:text_char="H"; 2:text_char="R";
                            3:text_char="E"; 4:text_char="E"; 5:text_char=" ";
                            6:text_char="D"; 7:text_char="A"; 8:text_char="Y";
                            9:text_char="S"; 10:text_char=" "; 11:text_char="G";
                            12:text_char="R"; 13:text_char="A"; 14:text_char="C";
                            15:text_char="E";
                            default: ;
                        endcase
                    endcase
                end
                3'd5: begin // Header label MY MUSIC
                    case(index)
                        0:text_char="M"; 1:text_char="Y"; 2:text_char=" ";
                        3:text_char="M"; 4:text_char="U"; 5:text_char="S";
                        6:text_char="I"; 7:text_char="C";
                        default: ;
                    endcase
                end
                3'd6: begin // SBER wordmark text
                    case(index)
                        0:text_char="S"; 1:text_char="B"; 2:text_char="E"; 3:text_char="R";
                        default: ;
                    endcase
                end
                default: ;
            endcase
        end
    endfunction

    function automatic logic text_hit(
        input logic [10:0] px,
        input logic [9:0] py,
        input integer x0,
        input integer y0,
        input logic [1:0] selected_track,
        input logic [2:0] field,
        input logic [1:0] scale
    );
        logic [7:0] c;
        integer char_width, char_index;
        begin
            text_hit = 1'b0;
            char_width = (6 << scale);
            if (px >= x0 && py >= y0 && py < y0 + (7 << scale)) begin
                char_index = ((px - x0) >> scale) / 6;
                c = text_char(selected_track, field, char_index);
                text_hit = glyph_hit(px,py,x0+char_index*char_width,y0,scale,c);
            end
        end
    endfunction

    integer local_x, local_y, src_x, src_y, row_y;
    integer progress_pos, dx, dy, abs_dx, abs_dy, bar_x, bar_h, bar_h2, bar_level, reflection_h;
    logic [11:0] spectrum_color, reflection_color;
    integer elapsed_min, elapsed_sec, duration_min, duration_sec;
    integer ti;
    logic [7:0] time_glyph;

    always_comb begin
        cover_mask = 1'b0;
        cover_addr = 17'd0;
        base_rgb = 12'h101;
        local_x = 0; local_y = 0; src_x = 0; src_y = 0;
        row_y = 0;
        progress_pos = 0; dx = 0; dy = 0; abs_dx = 0; abs_dy = 0;
        bar_x = 0; bar_h = 0; bar_h2 = 0; bar_level = 0; reflection_h = 0;
        spectrum_color = 12'h000; reflection_color = 12'h000;
        elapsed_min = 0; elapsed_sec = 0; duration_min = 0; duration_sec = 0;
        ti = 0; time_glyph = 8'h20;

        // Dark charcoal canvas and a restrained header band.
        if (y < 10'd54) base_rgb = 12'h101;
        else if (x < 11'd344) base_rgb = 12'h111;
        else base_rgb = 12'h101;
        if (y == 10'd53) base_rgb = 12'h233;

        if (text_hit(x,y,32,18,track,3'd5,2'd1)) base_rgb = 12'hDDE;

        // Detailed gradient icon and clean Cyrillic wordmark from the RGB444 ROM.
        if (x >= 11'd650 && x < 11'd778 && y >= 10'd3 && y < 10'd51) begin
            cover_mask = 1'b1;
            cover_addr = LOGO_BASE + (y-10'd3)*LOGO_W + (x-11'd650);
        end

        // Left playlist panel, selected row highlight, track and artist names.
        if (x >= 11'd28 && x < 11'd334 && y >= 10'd82 && y < 10'd322) begin
            for (ti=0; ti<3; ti=ti+1) begin
                row_y = 96 + ti*72;
                if (x >= 11'd30 && x < 11'd330 && y >= row_y && y < row_y+56) begin
                    if (track == ti[1:0]) begin
                        base_rgb = 12'h132;
                        if (x < 11'd35) base_rgb = 12'h5DB;
                    end
                    if (glyph_hit(x,y,48,row_y+13,2'd1,"0") ||
                        glyph_hit(x,y,60,row_y+13,2'd1,(ti==0)?"1":(ti==1)?"2":"3"))
                        base_rgb = (track == ti[1:0]) ? 12'h6EB : 12'h687;
                    if (text_hit(x,y,86,row_y+10,ti[1:0],3'd3,2'd1))
                        base_rgb = (track == ti[1:0]) ? 12'hFFF : 12'hCCD;
                    if (text_hit(x,y,86,row_y+34,ti[1:0],3'd4,2'd0))
                        base_rgb = (track == ti[1:0]) ? 12'h8CA : 12'h788;
                end
            end
        end

        // 192x192 album art is enlarged 2x to fill the 384x384 display window.
        if (x >= 11'd368 && x < 11'd752 && y >= 10'd80 && y < 10'd464) begin
            cover_mask = 1'b1;
            local_x = x - 368;
            local_y = y - 80;
            src_x = local_x / 2;
            src_y = local_y / 2;
            case (track)
                2'd1: cover_addr = COVER_PIXELS + src_y*COVER_W + src_x;
                2'd2: cover_addr = 2*COVER_PIXELS + src_y*COVER_W + src_x;
                default: cover_addr = src_y*COVER_W + src_x;
            endcase
        end
        if ((x >= 11'd365 && x < 11'd755 && y >= 10'd77 && y < 10'd467) &&
            !(x >= 11'd368 && x < 11'd752 && y >= 10'd80 && y < 10'd464))
            base_rgb = 12'h245;

        // Selected track title and artist under the cover.
        if (text_hit(x,y,368,476,track,3'd0,2'd1)) base_rgb = 12'hFFF;
        if (text_hit(x,y,368,496,track,3'd1,2'd0)) base_rgb = 12'hDDE;
        if (text_hit(x,y,368,516,track,3'd2,2'd0)) base_rgb = 12'h9AB;

        // Elapsed and total time, with a progress rail driven by consumed samples.
        progress_pos = (progress_pixels * 9) / 10;
        if (x >= 11'd86 && x < 11'd626 && y >= 10'd559 && y < 10'd563)
            base_rgb = 12'h344;
        if (x >= 11'd86 && x < 11'd86+progress_pos && y >= 10'd559 && y < 10'd563)
            base_rgb = 12'h4D9;
        dx = x - (86 + progress_pos);
        dy = y - 561;
        abs_dx = (dx < 0) ? -dx : dx;
        abs_dy = (dy < 0) ? -dy : dy;
        if (abs_dx <= 4 && abs_dy <= 4 && abs_dx + abs_dy <= 7)
            base_rgb = 12'h6EB;

        elapsed_min = elapsed_seconds / 16'd60;
        elapsed_sec = elapsed_seconds % 16'd60;
        duration_min = duration_seconds / 16'd60;
        duration_sec = duration_seconds % 16'd60;
        if (elapsed_min > 99) elapsed_min = 99;
        if (duration_min > 99) duration_min = 99;
        for (ti=0; ti<5; ti=ti+1) begin
            case (ti)
                0: time_glyph = 8'd48 + (elapsed_min / 10);
                1: time_glyph = 8'd48 + (elapsed_min % 10);
                2: time_glyph = ":";
                3: time_glyph = 8'd48 + (elapsed_sec / 10);
                default: time_glyph = 8'd48 + (elapsed_sec % 10);
            endcase
            if (glyph_hit(x,y,26+ti*10,551,2'd1,time_glyph)) base_rgb = 12'hEDE;
            case (ti)
                0: time_glyph = 8'd48 + (duration_min / 10);
                1: time_glyph = 8'd48 + (duration_min % 10);
                2: time_glyph = ":";
                3: time_glyph = 8'd48 + (duration_sec / 10);
                default: time_glyph = 8'd48 + (duration_sec % 10);
            endcase
            if (glyph_hit(x,y,634+ti*10,551,2'd1,time_glyph)) base_rgb = 12'hEDE;
        end

        // Eight live frequency bands. Each band is a colored pair; the dim
        // pixels below the baseline give a small reflection like the reference.
        if (x >= 11'd694 && x < 11'd784 && y == 10'd574)
            base_rgb = 12'h223;
        for (ti=0; ti<8; ti=ti+1) begin
            bar_x = 696 + ti*11;
            bar_level = spectrum_levels[ti*4 +: 4];
            bar_h = bar_level * 2;
            bar_h2 = bar_h - (bar_h >> 2);
            reflection_h = bar_h / 3;
            case (ti)
                0: begin spectrum_color=12'hE44; reflection_color=12'h512; end
                1: begin spectrum_color=12'hE83; reflection_color=12'h521; end
                2: begin spectrum_color=12'hDD4; reflection_color=12'h551; end
                3: begin spectrum_color=12'h9D4; reflection_color=12'h352; end
                4: begin spectrum_color=12'h4C9; reflection_color=12'h245; end
                5: begin spectrum_color=12'h3CD; reflection_color=12'h236; end
                6: begin spectrum_color=12'h46D; reflection_color=12'h235; end
                default: begin spectrum_color=12'hA5D; reflection_color=12'h324; end
            endcase
            if (bar_h != 0) begin
                if (x >= bar_x && x < bar_x+3 && y >= 574-bar_h && y < 574)
                    base_rgb = spectrum_color;
                if (x >= bar_x+4 && x < bar_x+7 && y >= 574-bar_h2 && y < 574)
                    base_rgb = spectrum_color;
                if (reflection_h != 0 && x >= bar_x && x < bar_x+3 &&
                    y >= 576 && y < 576+reflection_h)
                    base_rgb = reflection_color;
                if (reflection_h > 1 && x >= bar_x+4 && x < bar_x+7 &&
                    y >= 576 && y < 576+(reflection_h*3)/4)
                    base_rgb = reflection_color;
            end
        end

        // During accelerometer sleep, replace the player UI with the supplied
        // Sber logo centered on black. The source bitmap is enlarged 2x.
        if (sleep_mode) begin
            base_rgb = 12'h000;
            cover_mask = 1'b0;
            cover_addr = 17'd0;
            if (x >= 11'd208 && x < 11'd592 && y >= 10'd248 && y < 10'd352) begin
                cover_mask = 1'b1;
                cover_addr = SLEEP_LOGO_BASE + ((y-10'd248)/2)*SLEEP_LOGO_W + ((x-11'd208)/2);
            end
        end
    end

    // Synchronous ROM read and matching UI-color pipeline for VGA timing.
    always_ff @(posedge clk) begin
        cover_rgb_q  <= cover_rom[cover_addr];
        base_rgb_q   <= base_rgb;
        cover_mask_q <= cover_mask;
    end

    always_comb begin
        rgb = cover_mask_q ? cover_rgb_q : base_rgb_q;
    end
endmodule
