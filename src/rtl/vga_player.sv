module vga_player (
    input  logic       clk_40mhz,
    input  logic       rst,
    input  logic [1:0] song_id,
    input  logic [1:0] player_state,
    output logic [3:0] VGA_R,
    output logic [3:0] VGA_G,
    output logic [3:0] VGA_B,
    output logic       VGA_HS,
    output logic       VGA_VS
);

    localparam int H_VISIBLE = 800;
    localparam int H_FRONT   = 40;
    localparam int H_SYNC    = 128;
    localparam int H_TOTAL   = 1056;
    localparam int V_VISIBLE = 600;
    localparam int V_FRONT   = 1;
    localparam int V_SYNC    = 4;
    localparam int V_TOTAL   = 628;

    logic [10:0] h;
    logic [9:0]  v;
    logic [1:0] song_sync1, song_sync2;
    logic [1:0] state_sync1, state_sync2;

    always_ff @(posedge clk_40mhz or posedge rst) begin
        if (rst) begin
            h <= '0;
            v <= '0;
            song_sync1  <= '0;
            song_sync2  <= '0;
            state_sync1 <= '0;
            state_sync2 <= '0;
        end else begin
            song_sync1  <= song_id;
            song_sync2  <= song_sync1;
            state_sync1 <= player_state;
            state_sync2 <= state_sync1;

            if (h == H_TOTAL-1) begin
                h <= '0;
                if (v == V_TOTAL-1) v <= '0;
                else v <= v + 10'd1;
            end else h <= h + 11'd1;
        end
    end

    logic visible = (h < H_VISIBLE) && (v < V_VISIBLE);
    always_comb begin
        VGA_HS = (h >= H_VISIBLE + H_FRONT) &&
                 (h <  H_VISIBLE + H_FRONT + H_SYNC);
        VGA_VS = (v >= V_VISIBLE + V_FRONT) &&
                 (v <  V_VISIBLE + V_FRONT + V_SYNC);
    end

    logic [5:0] char_x = h[9:4];
    logic [5:0] char_y = v[9:4];
    logic [2:0] glyph_row = v[3:1];
    logic [2:0] glyph_col = h[3:1];
    logic [7:0] character;
    logic [4:0] glyph_bits;
    
    logic is_text = glyph_col < 3'd5 && glyph_row < 3'd7 &&
                   glyph_bits[4 - glyph_col];

    always_comb begin
        character = 8'd32;
        case (char_y)
            6'd5: begin
                case (char_x)
                    6'd16: character = 8'd70;
                    6'd17: character = 8'd80;
                    6'd18: character = 8'd71;
                    6'd19: character = 8'd65;
                    6'd21: character = 8'd77;
                    6'd22: character = 8'd85;
                    6'd23: character = 8'd83;
                    6'd24: character = 8'd73;
                    6'd25: character = 8'd67;
                    6'd27: character = 8'd80;
                    6'd28: character = 8'd76;
                    6'd29: character = 8'd65;
                    6'd30: character = 8'd89;
                    6'd31: character = 8'd69;
                    6'd32: character = 8'd82;
                    default: ;
                endcase
            end
            6'd9: begin
                case (char_x)
                    6'd11: character = 8'd75;
                    6'd12: character = 8'd69;
                    6'd13: character = 8'd89;
                    6'd14: character = 8'd66;
                    6'd15: character = 8'd79;
                    6'd16: character = 8'd65;
                    6'd17: character = 8'd82;
                    6'd18: character = 8'd68;
                    6'd20: character = 8'd67;
                    6'd21: character = 8'd79;
                    6'd22: character = 8'd78;
                    6'd23: character = 8'd84;
                    6'd24: character = 8'd82;
                    6'd25: character = 8'd79;
                    6'd26: character = 8'd76;
                    6'd28: character = 8'd86;
                    6'd29: character = 8'd71;
                    6'd30: character = 8'd65;
                    default: ;
                endcase
            end
            6'd16: begin
                case (char_x)
                    6'd9: character = 8'd83;
                    6'd10: character = 8'd79;
                    6'd11: character = 8'd78;
                    6'd12: character = 8'd71;
                    6'd14: character = 8'd49;
                    6'd23: character = 8'd83;
                    6'd24: character = 8'd79;
                    6'd25: character = 8'd78;
                    6'd26: character = 8'd71;
                    6'd28: character = 8'd50;
                    6'd36: character = 8'd83;
                    6'd37: character = 8'd79;
                    6'd38: character = 8'd78;
                    6'd39: character = 8'd71;
                    6'd41: character = 8'd51;
                    default: ;
                endcase
            end
            6'd23: begin
                case (char_x)
                    6'd11: character = 8'd83;
                    6'd12: character = 8'd84;
                    6'd13: character = 8'd65;
                    6'd14: character = 8'd84;
                    6'd15: character = 8'd85;
                    6'd16: character = 8'd83;
                    6'd17: character = 8'd58;
                    default: ;
                endcase
                case (state_sync2)
                    2'd0: begin
                        case (char_x)
                            6'd22: character = 8'd83;
                            6'd23: character = 8'd84;
                            6'd24: character = 8'd79;
                            6'd25: character = 8'd80;
                            6'd26: character = 8'd80;
                            6'd27: character = 8'd69;
                            6'd28: character = 8'd68;
                            default: ;
                        endcase
                    end
                    2'd1: begin
                        case (char_x)
                            6'd22: character = 8'd80;
                            6'd23: character = 8'd76;
                            6'd24: character = 8'd65;
                            6'd25: character = 8'd89;
                            6'd26: character = 8'd73;
                            6'd27: character = 8'd78;
                            6'd28: character = 8'd71;
                            default: ;
                        endcase
                    end
                    2'd2: begin
                        case (char_x)
                            6'd22: character = 8'd80;
                            6'd23: character = 8'd65;
                            6'd24: character = 8'd85;
                            6'd25: character = 8'd83;
                            6'd26: character = 8'd69;
                            6'd27: character = 8'd68;
                            default: ;
                        endcase
                    end
                    default: ;
                endcase
            end
            6'd29: begin
                case (char_x)
                    6'd9: character = 8'd49;
                    6'd11: character = 8'd50;
                    6'd13: character = 8'd51;
                    6'd15: character = 8'd83;
                    6'd16: character = 8'd69;
                    6'd17: character = 8'd76;
                    6'd18: character = 8'd69;
                    6'd19: character = 8'd67;
                    6'd20: character = 8'd84;
                    6'd22: character = 8'd83;
                    6'd23: character = 8'd79;
                    6'd24: character = 8'd78;
                    6'd25: character = 8'd71;
                    default: ;
                endcase
            end
            6'd31: begin
                case (char_x)
                    6'd9: character = 8'd78;
                    6'd11: character = 8'd78;
                    6'd12: character = 8'd69;
                    6'd13: character = 8'd88;
                    6'd14: character = 8'd84;
                    6'd18: character = 8'd66;
                    6'd20: character = 8'd80;
                    6'd21: character = 8'd82;
                    6'd22: character = 8'd69;
                    6'd23: character = 8'd86;
                    6'd24: character = 8'd73;
                    6'd25: character = 8'd79;
                    6'd26: character = 8'd85;
                    6'd27: character = 8'd83;
                    default: ;
                endcase
            end
            6'd33: begin
                case (char_x)
                    6'd9: character = 8'd83;
                    6'd10: character = 8'd80;
                    6'd11: character = 8'd65;
                    6'd12: character = 8'd67;
                    6'd13: character = 8'd69;
                    6'd15: character = 8'd80;
                    6'd16: character = 8'd76;
                    6'd17: character = 8'd65;
                    6'd18: character = 8'd89;
                    6'd20: character = 8'd80;
                    6'd21: character = 8'd65;
                    6'd22: character = 8'd85;
                    6'd23: character = 8'd83;
                    6'd24: character = 8'd69;
                    default: ;
                endcase
            end
            6'd35: begin
                case (char_x)
                    6'd9: character = 8'd83;
                    6'd11: character = 8'd83;
                    6'd12: character = 8'd84;
                    6'd13: character = 8'd79;
                    6'd14: character = 8'd80;
                    default: ;
                endcase
            end

            default: ;
        endcase
    end

    function automatic [4:0] glyph(input [7:0] ch, input [2:0] row);
        begin
            glyph = 5'd0;
            case (ch)
            8'd32: case (row)
                3'd0: glyph = 5'b00000;
                3'd1: glyph = 5'b00000;
                3'd2: glyph = 5'b00000;
                3'd3: glyph = 5'b00000;
                3'd4: glyph = 5'b00000;
                3'd5: glyph = 5'b00000;
                3'd6: glyph = 5'b00000;
                default: glyph = 5'b00000;
            endcase
            8'd65: case (row)
                3'd0: glyph = 5'b01110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b11111;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b10001;
                default: glyph = 5'b00000;
            endcase
            8'd66: case (row)
                3'd0: glyph = 5'b11110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b11110;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b11110;
                default: glyph = 5'b00000;
            endcase
            8'd67: case (row)
                3'd0: glyph = 5'b01111;
                3'd1: glyph = 5'b10000;
                3'd2: glyph = 5'b10000;
                3'd3: glyph = 5'b10000;
                3'd4: glyph = 5'b10000;
                3'd5: glyph = 5'b10000;
                3'd6: glyph = 5'b01111;
                default: glyph = 5'b00000;
            endcase
            8'd68: case (row)
                3'd0: glyph = 5'b11110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b10001;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b11110;
                default: glyph = 5'b00000;
            endcase
            8'd69: case (row)
                3'd0: glyph = 5'b11111;
                3'd1: glyph = 5'b10000;
                3'd2: glyph = 5'b10000;
                3'd3: glyph = 5'b11110;
                3'd4: glyph = 5'b10000;
                3'd5: glyph = 5'b10000;
                3'd6: glyph = 5'b11111;
                default: glyph = 5'b00000;
            endcase
            8'd70: case (row)
                3'd0: glyph = 5'b11111;
                3'd1: glyph = 5'b10000;
                3'd2: glyph = 5'b10000;
                3'd3: glyph = 5'b11110;
                3'd4: glyph = 5'b10000;
                3'd5: glyph = 5'b10000;
                3'd6: glyph = 5'b10000;
                default: glyph = 5'b00000;
            endcase
            8'd71: case (row)
                3'd0: glyph = 5'b01111;
                3'd1: glyph = 5'b10000;
                3'd2: glyph = 5'b10000;
                3'd3: glyph = 5'b10111;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b01111;
                default: glyph = 5'b00000;
            endcase
            8'd72: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b11111;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b10001;
                default: glyph = 5'b00000;
            endcase
            8'd73: case (row)
                3'd0: glyph = 5'b11111;
                3'd1: glyph = 5'b00100;
                3'd2: glyph = 5'b00100;
                3'd3: glyph = 5'b00100;
                3'd4: glyph = 5'b00100;
                3'd5: glyph = 5'b00100;
                3'd6: glyph = 5'b11111;
                default: glyph = 5'b00000;
            endcase
            8'd74: case (row)
                3'd0: glyph = 5'b00111;
                3'd1: glyph = 5'b00010;
                3'd2: glyph = 5'b00010;
                3'd3: glyph = 5'b00010;
                3'd4: glyph = 5'b10010;
                3'd5: glyph = 5'b10010;
                3'd6: glyph = 5'b01100;
                default: glyph = 5'b00000;
            endcase
            8'd75: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b10010;
                3'd2: glyph = 5'b10100;
                3'd3: glyph = 5'b11000;
                3'd4: glyph = 5'b10100;
                3'd5: glyph = 5'b10010;
                3'd6: glyph = 5'b10001;
                default: glyph = 5'b00000;
            endcase
            8'd76: case (row)
                3'd0: glyph = 5'b10000;
                3'd1: glyph = 5'b10000;
                3'd2: glyph = 5'b10000;
                3'd3: glyph = 5'b10000;
                3'd4: glyph = 5'b10000;
                3'd5: glyph = 5'b10000;
                3'd6: glyph = 5'b11111;
                default: glyph = 5'b00000;
            endcase
            8'd77: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b11011;
                3'd2: glyph = 5'b10101;
                3'd3: glyph = 5'b10101;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b10001;
                default: glyph = 5'b00000;
            endcase
            8'd78: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b11001;
                3'd2: glyph = 5'b10101;
                3'd3: glyph = 5'b10011;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b10001;
                default: glyph = 5'b00000;
            endcase
            8'd79: case (row)
                3'd0: glyph = 5'b01110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b10001;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b01110;
                default: glyph = 5'b00000;
            endcase
            8'd80: case (row)
                3'd0: glyph = 5'b11110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b11110;
                3'd4: glyph = 5'b10000;
                3'd5: glyph = 5'b10000;
                3'd6: glyph = 5'b10000;
                default: glyph = 5'b00000;
            endcase
            8'd81: case (row)
                3'd0: glyph = 5'b01110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b10001;
                3'd4: glyph = 5'b10101;
                3'd5: glyph = 5'b10010;
                3'd6: glyph = 5'b01101;
                default: glyph = 5'b00000;
            endcase
            8'd82: case (row)
                3'd0: glyph = 5'b11110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b11110;
                3'd4: glyph = 5'b10100;
                3'd5: glyph = 5'b10010;
                3'd6: glyph = 5'b10001;
                default: glyph = 5'b00000;
            endcase
            8'd83: case (row)
                3'd0: glyph = 5'b01111;
                3'd1: glyph = 5'b10000;
                3'd2: glyph = 5'b10000;
                3'd3: glyph = 5'b01110;
                3'd4: glyph = 5'b00001;
                3'd5: glyph = 5'b00001;
                3'd6: glyph = 5'b11110;
                default: glyph = 5'b00000;
            endcase
            8'd84: case (row)
                3'd0: glyph = 5'b11111;
                3'd1: glyph = 5'b00100;
                3'd2: glyph = 5'b00100;
                3'd3: glyph = 5'b00100;
                3'd4: glyph = 5'b00100;
                3'd5: glyph = 5'b00100;
                3'd6: glyph = 5'b00100;
                default: glyph = 5'b00000;
            endcase
            8'd85: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b10001;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b01110;
                default: glyph = 5'b00000;
            endcase
            8'd86: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b10001;
                3'd4: glyph = 5'b10001;
                3'd5: glyph = 5'b01010;
                3'd6: glyph = 5'b00100;
                default: glyph = 5'b00000;
            endcase
            8'd87: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b10001;
                3'd3: glyph = 5'b10101;
                3'd4: glyph = 5'b10101;
                3'd5: glyph = 5'b10101;
                3'd6: glyph = 5'b01010;
                default: glyph = 5'b00000;
            endcase
            8'd88: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b01010;
                3'd3: glyph = 5'b00100;
                3'd4: glyph = 5'b01010;
                3'd5: glyph = 5'b10001;
                3'd6: glyph = 5'b10001;
                default: glyph = 5'b00000;
            endcase
            8'd89: case (row)
                3'd0: glyph = 5'b10001;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b01010;
                3'd3: glyph = 5'b00100;
                3'd4: glyph = 5'b00100;
                3'd5: glyph = 5'b00100;
                3'd6: glyph = 5'b00100;
                default: glyph = 5'b00000;
            endcase
            8'd90: case (row)
                3'd0: glyph = 5'b11111;
                3'd1: glyph = 5'b00001;
                3'd2: glyph = 5'b00010;
                3'd3: glyph = 5'b00100;
                3'd4: glyph = 5'b01000;
                3'd5: glyph = 5'b10000;
                3'd6: glyph = 5'b11111;
                default: glyph = 5'b00000;
            endcase
            8'd48: case (row)
                3'd0: glyph = 5'b01110;
                3'd1: glyph = 5'b10011;
                3'd2: glyph = 5'b10101;
                3'd3: glyph = 5'b10101;
                3'd4: glyph = 5'b10101;
                3'd5: glyph = 5'b11001;
                3'd6: glyph = 5'b01110;
                default: glyph = 5'b00000;
            endcase
            8'd49: case (row)
                3'd0: glyph = 5'b00100;
                3'd1: glyph = 5'b01100;
                3'd2: glyph = 5'b00100;
                3'd3: glyph = 5'b00100;
                3'd4: glyph = 5'b00100;
                3'd5: glyph = 5'b00100;
                3'd6: glyph = 5'b01110;
                default: glyph = 5'b00000;
            endcase
            8'd50: case (row)
                3'd0: glyph = 5'b01110;
                3'd1: glyph = 5'b10001;
                3'd2: glyph = 5'b00001;
                3'd3: glyph = 5'b00010;
                3'd4: glyph = 5'b00100;
                3'd5: glyph = 5'b01000;
                3'd6: glyph = 5'b11111;
                default: glyph = 5'b00000;
            endcase
            8'd51: case (row)
                3'd0: glyph = 5'b11110;
                3'd1: glyph = 5'b00001;
                3'd2: glyph = 5'b00001;
                3'd3: glyph = 5'b00110;
                3'd4: glyph = 5'b00001;
                3'd5: glyph = 5'b00001;
                3'd6: glyph = 5'b11110;
                default: glyph = 5'b00000;
            endcase
            8'd58: case (row)
                3'd0: glyph = 5'b00000;
                3'd1: glyph = 5'b00100;
                3'd2: glyph = 5'b00100;
                3'd3: glyph = 5'b00000;
                3'd4: glyph = 5'b00100;
                3'd5: glyph = 5'b00100;
                3'd6: glyph = 5'b00000;
                default: glyph = 5'b00000;
            endcase
            8'd47: case (row)
                3'd0: glyph = 5'b00001;
                3'd1: glyph = 5'b00001;
                3'd2: glyph = 5'b00010;
                3'd3: glyph = 5'b00100;
                3'd4: glyph = 5'b01000;
                3'd5: glyph = 5'b10000;
                3'd6: glyph = 5'b10000;
                default: glyph = 5'b00000;
            endcase
            8'd45: case (row)
                3'd0: glyph = 5'b00000;
                3'd1: glyph = 5'b00000;
                3'd2: glyph = 5'b00000;
                3'd3: glyph = 5'b11111;
                3'd4: glyph = 5'b00000;
                3'd5: glyph = 5'b00000;
                3'd6: glyph = 5'b00000;
                default: glyph = 5'b00000;
            endcase

                default: glyph = 5'd0;
            endcase
        end
    endfunction

    always_comb begin
        glyph_bits = glyph(character, glyph_row);
        VGA_R = 4'd0;
        VGA_G = 4'd0;
        VGA_B = 4'd0;
        if (visible) begin
            VGA_R = 4'd1;
            VGA_G = 4'd2;
            VGA_B = 4'd4;

            // Title stripe.
            if (h >= 11'd92 && h < 11'd708 && v >= 10'd58 && v < 10'd158) begin
                VGA_R = 4'd2;
                VGA_G = 4'd3;
                VGA_B = 4'd7;
            end

            // Song cards. The selected song uses a green accent.
            if ((h >= 11'd80 && h < 11'd274) ||
                (h >= 11'd303 && h < 11'd497) ||
                (h >= 11'd526 && h < 11'd720)) begin
                if (v >= 10'd220 && v < 10'd330) begin
                    VGA_R = 4'd3;
                    VGA_G = 4'd3;
                    VGA_B = 4'd6;
                    if ((h < 11'd274 && song_sync2 == 2'd0) ||
                        (h >= 11'd303 && h < 11'd497 && song_sync2 == 2'd1) ||
                        (h >= 11'd526 && song_sync2 == 2'd2)) begin
                        VGA_R = 4'd1;
                        VGA_G = 4'd8;
                        VGA_B = 4'd6;
                    end
                end
            end

            // Player status panel.
            if (h >= 11'd150 && h < 11'd650 &&
                v >= 10'd353 && v < 10'd409) begin
                VGA_R = 4'd2;
                VGA_G = (state_sync2 == 2'd1) ? 4'd6 : 4'd3;
                VGA_B = (state_sync2 == 2'd1) ? 4'd3 : 4'd7;
            end
            if (is_text) begin
                VGA_R = 4'hF;
                VGA_G = 4'hF;
                VGA_B = 4'hF;
            end
        end
    end
endmodule
