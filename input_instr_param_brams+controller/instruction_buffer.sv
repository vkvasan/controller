`timescale 1ns / 1ps

module instr_buffer#(
    parameter STREAM_WIDTH = 128,
    parameter INSTR_DEPTH = 16,
    parameter INSTR_WIDTH = STREAM_WIDTH //WRITE WIDTH OF BRAM, 
    )(
    input logic clk, 
    input logic rst_n, 
    //write interface 
    input logic [STREAM_WIDTH-1:0]idata_instr,
    input logic idata_instr_valid,
    input logic [$clog2(NUM_BANKS)-1:0]instr_bank_counter, 
    output logic idata_instr_ready, 

    //read interface 
    output logic [NUM_BANKS-1:0][STREAM_WIDTH-1:0]idata_instr_rd,
    output logic [NUM_BANKS-1:0]idata_instr_valid_rd,
    input logic [NUM_BANKS-1:0]idata_instr_ready_rd
);

//instruction buffer 
logic [NUM_BANKS-1:0][INSTR_DEPTH-1:0][INSTR_WIDTH-1:0]instr_buffer;  //global
//other local registers
logic [NUM_BANKS-1:0][$clog2(INSTR_DEPTH):0]rd_pointer; 
logic [NUM_BANKS-1:0][$clog2(INSTR_DEPTH):0]wr_pointer; 
logic [NUM_BANKS-1:0]full;
logic [NUM_BANKS-1:0]empty;


always_ff @( posedge(clk) ) begin 
if( !rst_n)begin
    idata_instr_ready <= 1;
    idata_instr_rd <= 0;
    idata_instr_valid_rd <= 0;
  end
else begin
   if( full[instr_bank_counter] )   
        idata_instr_ready <= 0;
   else
        idata_instr_ready <= 1; 
    for ( int i =0; i < NUM_BANKS; i++)begin
        if(!empty[i] & idata_instr_ready_rd[i] )begin
            idata_instr_valid_rd[i] <= 1;
            idata_instr_rd[i] <= instr_buffer[i][rd_pointer[i]];
        end
        else 
            idata_instr_valid_rd[i] <= 0;
    end
    
end
end


//local register 
always_ff @(posedge clk or negedge rst_n )begin
if( !rst_n )begin
    instr_buffer <= 0;
    wr_pointer <= 0;
    rd_pointer <= 0;
end
else begin
        if(idata_instr_ready & idata_instr_valid)begin
            instr_buffer[instr_bank_counter][wr_pointer[instr_bank_counter]] <= idata_instr;
            wr_pointer[instr_bank_counter] <= wr_pointer[instr_bank_counter] + 1;
        end
        for ( int i =0; i < NUM_BANKS; i++)begin
            if(idata_instr_valid_rd[i] & idata_instr_ready_rd[i] )begin
                rd_pointer[i] <= rd_pointer[i] + 1;
            end
        end
end

end

genvar i;
generate
    for(  i = 0; i < NUM_BANKS; i++)begin
        assign full[i] = (wr_pointer[i][$clog2(INSTR_DEPTH)-1:0] == rd_pointer[i][$clog2(INSTR_DEPTH)-1:0] & (wr_pointer[i][$clog2(INSTR_DEPTH)] != rd_pointer[i][$clog2(INSTR_DEPTH)]))?1:0;
        assign empty[i] = wr_pointer[i] == rd_pointer[i] ? 1 : 0;
    end
endgenerate


endmodule