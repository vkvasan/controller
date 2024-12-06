module accumulator#(
 parameter WEIGHT_BIT = 8,
  INPUT_BIT = 8,
  ACCUM_BIT = 27,
  RESULT_BIT = 8,
  WRITE_WIDTH = 128,
  NUM_ROWS = 16,
  MAX_CHAN = 256
 )(
    input logic clk, 
    input logic rst_n, 
    
    //input logic [15:0]seq_len,
    input logic [RESULT_BIT-1:0]in_data, 
    input logic valid_i, 
    output logic [WRITE_WIDTH-1:0]out, 
    output logic valid_o,
    input logic [$clog2(MAX_CHAN)-1:0]out_chan_size
);

logic [$clog2(WRITE_WIDTH/RESULT_BIT)-1:0] shift_counter;
logic [WRITE_WIDTH-1:0] write_buffers;
//logic [2:0] kernel_size_reg;
//logic [7:0] num_out_chan_reg; 
//logic [7:0] num_in_chan_reg;

// Output registers
logic [WRITE_WIDTH-1:0] out_reg;
logic  out_reg_valid;
logic [$clog2(MAX_CHAN)-1:0]out_chan_count;

assign out = out_reg;
assign valid_o = out_reg_valid;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        shift_counter <= 0;
        write_buffers <= 0;
        
        out_reg <= 0;
        out_reg_valid <= 0;
        out_chan_count <= 0;
    end
    else begin
        
            if(valid_i) begin
                
                if( out_chan_count == out_chan_size - 1)begin
                    out_chan_count <= 0;
                    out_reg  <= {write_buffers[WRITE_WIDTH - RESULT_BIT-1:0],in_data};
                    out_reg_valid <= 1;
                    shift_counter<= 0; 
                    write_buffers <= 0;
                end
                else if( shift_counter == WRITE_WIDTH/RESULT_BIT -1)begin
                    shift_counter<= 0;
                    out_reg_valid <= 1;
                    write_buffers <= 0;
                    out_chan_count <= out_chan_count + 1;
                    out_reg <= {write_buffers[WRITE_WIDTH - RESULT_BIT-1:0],in_data};
                    
                end
                else begin
                    out_reg_valid <= 0;
                    write_buffers <= {write_buffers[WRITE_WIDTH - RESULT_BIT-1:0],in_data};
                    shift_counter <= shift_counter + 1;
                    out_chan_count <= out_chan_count + 1;
                end
                             
            end
            else 
                out_reg_valid <= 0;
    end
end
endmodule