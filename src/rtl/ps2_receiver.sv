module ps2_receiver (
    input  logic       clk,
    input  logic       rst,
    input  logic       ps2_clk,
    input  logic       ps2_data,
    output logic [7:0] scan_code,
    output logic       scan_valid
);
    logic [2:0]     clk_sync;
    logic [2:0]     data_sync;
    logic [3:0]     bit_index;
    logic [7:0]     shift_data;
    logic           parity_bit;
    logic [17:0]    timeout_count;

    logic falling_edge = clk_sync[2:1] == 2'b10;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            clk_sync        <= 3'b111;
            data_sync       <= 3'b111;
            bit_index       <= 4'd0;
            shift_data      <= 8'd0;
            parity_bit      <= 1'b0;
            timeout_count   <= 18'd0;
            scan_code       <= 8'd0;
            scan_valid      <= 1'b0;
        end else begin  
            clk_sync    <= {clk_sync[1:0], ps2_clk};
            data_sync   <= {data_sync[1:0], ps2_data};
            scan_valid  <= 1'b0;

            if (falling_edge) begin
                timeout_count <= 18'd0;
                case (bit_index)
                    4'd0: if (!data_sync[2]) bit_index <= 4'd1;
                    4'd1, 4'd2, 4'd3, 4'd4,
                    4'd5, 4'd6, 4'd7, 4'd8: begin
                        shift_data[bit_index - 4'd1] <= data_sync[2];
                        bit_index <= bit_index + 4'd1;
                    end
                    4'd9: begin
                        parity_bit <= data_sync[2];
                        bit_index <= 4'd10;
                    end
                    4'd10: begin
                        bit_index <= 4'd0;
                        if (data_sync[2] && ((^shift_data) ^ parity_bit)) begin
                            scan_code <= shift_data;
                            scan_valid <= 1'b1;
                        end
                    end
                    default: bit_index <= 4'd0;
                endcase
            end else if (timeout_count == 18'd199999) begin
                timeout_count <= 18'd0;
                bit_index <= 4'd0;
            end else begin
                timeout_count <= timeout_count + 18'd1;
            end
        end
    end
    
endmodule
