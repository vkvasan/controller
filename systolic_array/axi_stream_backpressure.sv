module axi_stream_backpressure_simd#(
    parameter VALID_WIDTH = 16,
    parameter DATA_WIDTH = 16,
    parameter PE_ID = 4
)(
    input logic clk, 
    input logic rst_n, 

    input logic [DATA_WIDTH]i_data,
    input logic [VALID_WIDTH]i_valid, 
    output logic o_ready, 

    output logic [DATA_WIDTH]o_data,
    output logic [VALID_WIDTH]o_valid, 
    input logic i_ready,

    //other miscellaneous signals to exert backpressure ( extend it if you need )
    input logic full
);


logic [DATA_WIDTH]r_data;
logic [VALID_WIDTH]r_data_valid_cols;
logic r_data_valid;
logic r_data_ready;

always_ff @(posedge clk or negedge rst_n )begin
if(!rst_n)begin
    o_data <= 0;
end
else begin
    if ( (!o_ready && i_valid[PE_ID]) && (!o_valid[PE_ID+1] || i_ready ))   //curent stream stalled and next stream not stalled , you then send a bubble with 0s. 
        if (r_data_valid)      
            o_data <= r_data;
        else 
            o_data <= 0;
    if ( !(!o_ready && i_valid[PE_ID]) && (!o_valid[PE_ID+1] || i_ready ))   //next stream and current stream not stalled
        if (r_data_valid)     
            o_data <= r_data;
        else 
            o_data <= i_data;

end
end

always_ff @(posedge clk or negedge rst_n )begin
if(!rst_n)begin
    r_data_valid <= 0;
    r_data_valid_cols <= 0;
end
else begin
    if((i_valid[PE_ID] & o_ready ) &&  (o_valid[PE_ID + 1] & !i_ready) )begin
       r_data_valid <= 1;   //registering a STALL 
       r_data_valid_cols <= i_valid;
    end
    else if ( i_ready )begin
        r_data_valid <= 0;
        r_data_valid_cols <= 0;
    end

end
end

always_ff @(posedge clk)begin
	if (o_ready)
		r_data <= i_data;
end

always @(*)
		o_ready = !r_data_valid & !full ;


always@(posedge clk or negedge rst_n)begin
if(!rst_n)
    o_valid <= 0;
else begin
    if ( (!o_ready && i_valid[PE_ID]) && (!o_valid[PE_ID+1] || i_ready ))   //curent stream stalled and next stream not stalled , you then send a bubble with 0s. 
        if (r_data_valid)      
            o_valid <= r_data_valid_cols;
        else 
            o_valid <= 0;
    if ( !(!o_ready && i_valid[PE_ID]) && (!o_valid[PE_ID+1] || i_ready ))   //next stream and current stream not stalled
         if (r_data_valid)   
            o_valid <= r_data_valid_cols;
         else 
            o_valid <= i_valid;
//other 2 cases, o_valid should remain same because the next stream is stalled. 
end
end



endmodule