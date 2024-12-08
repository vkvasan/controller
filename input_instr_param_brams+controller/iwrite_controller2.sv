module iwrite_controller2#(
    parameter STREAM_WIDTH = 128,
    parameter IBRAM_WIDTH = STREAM_WIDTH //WRITE WIDTH OF BRAM, 
    NUM_BANKS = 16,
    IBRAM_DEPTH = (ACTIVATION_BIT * (MAX_OUT_CHANNEL/NUM_BANKS) * MAX_IN_CHANNEL * MAX_KERNEL_SIZE )/IBRAM_WIDTH, //WRITE DEPTH OF BRAM
    MAX_OUT_CHANNEL = 128, 
    MAX_IN_CHANNEL = 45,
    MAX_KERNEL_SIZE = 5, 
    MAX_OUT_SEQ = 160, 
    MAX_NUM_LAYERS = 4,
    NUM_ACT_TILES = MAX_OUT_SEQ / NUM_BANKS,
    PARAM_WIDTH = $clog2(MAX_OUT_CHANNEL) + $clog2(MAX_IN_CHANNEL) + $clog2(MAX_KERNEL_SIZE) + $clog2(MAX_OUT_CHANNEL*MAX_KERNEL_SIZE), 
    ACT_WIDTH = 8, 
    )(

    input logic clk,
    input logic rst_n, 

    //from accumulator  
    input logic [NUM_ROWS-1:0][STREAM_WIDTH-1:0]odata_accum,
    input logic [NUM_ROWS-1:0]odata_accum_valid, 
    output logic [NUM_ROWS-1:0]odata_accum_ready, 

    //to IBRAM selector
    //output logic [$clog2(WBRAM_DEPTH)-1:0]addrA, 
    output logic [NUM_ROWS-1:0][STREAM_WIDTH-1:0]doA2, //act_data
    output logic [NUM_ROWS-1:0]enaA2, 
    output logic [NUM_ROWS-1:0]weA2, 
    output logic [NUM_ROWS-1:0]bank_idx2,
    output logic wr_done2,
    input logic [NUM_BANKS-1:0]full2,
    //input [NUM_BANKS-1:0][$clog2(READ_DEPTH):0]read_addrB_ping_pong;

    //to iwritecontroller1 ( Data channel )
    input logic [PARAM_WIDTH-1:0]param_data_iwr2,  
    input logic param_data_valid_iwr2, 
    output logic param_data_ready_iwr2, 

    //to iwritecontroller1 ( Address channel )
    output logic [PARAM_WIDTH-1:0]param_addr_iwr2,  
    output logic param_addr_valid_iwr2, 
    input logic param_addr_ready_iwr2 

);


typedef enum  logic[1:0] {IDLE, PARAM_READ, BRAM_WRITE   } STATE;
STATE curr_state,next_state;

logic [$clog2(MAX_NUM_LAYERS)-1:0]layer_count;
logic [$clog2(MAX_NUM_LAYERS)-1:0]num_layer;
logic [NUM_ROWS-1:0][$clog2(MAX_KERNEL_SIZE)-1:0]kernel_count;
logic [NUM_ROWS-1:0][STREAM_WIDTH-1:0]odata_accum_local;
logic [$clog2(MAX_OUT_CHANNEL/(STREAM_WIDTH/RESULT_BIT))-1:0]out_channel_counter;
logic [$clog2(MAX_OUT_SEQ/(NUM_ROWS))-1:0]out_seq_counter;
/*

accumulator
    input logic [NUM_ROWS-1:0][STREAM_WIDTH-1:0]odata_accum,
    input logic [NUM_ROWS-1:0]odata_accum_valid, 
    output logic [NUM_ROWS-1:0]odata_accum_ready, 

and local registers->
    odata_accum_local 
    kernel_count
*/
always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    odata_accum_local <= 0;
end
else begin  
    for( int i =0; i < NUM_BANKS;i++)begin
        if( curr_state != BRAM_WRITE || full2[i] )
            odata_accum_ready[i] <= 0;
        else if( odata_accum_valid[i] & odata_accum_ready[i])begin
            odata_accum_local[i] <=  odata_accum[i];
            odata_accum_ready[i] <= 0;
            kernel_count[i] <= 0;
        end
        else if (odata_accum_ready[i]== 0 & kernel_count[i]==kernel_size-1 )begin
            odata_accum_ready[i] <= 1;
            kernel_count[i] <= 0;
        end
        else if (odata_accum_ready[i]== 0 & kernel_count[i]!=kernel_size-1 )begin
            odata_accum_ready[i] <= 0;
            kernel_count[i] <= kernel_count[i] + 1;
        end
    end
end
end


/*
    //to IBRAM selector
    output logic [NUM_ROWS-1:0][STREAM_WIDTH-1:0]doA2, //act_data
    output logic [NUM_ROWS-1:0]enaA2, 
    output logic [NUM_ROWS-1:0]weA2, 
    output logic [NUM_ROWS-1:0]bank_idx2,
    output logic wr_done2,
    input logic [NUM_BANKS-1:0]full2,


*/
always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    doA2 <= 0;
    enaA2 <= 0;
    weA2 <= 0;
    bank_idx2 <= 0;
    wr_done2 <= 0;
end
else begin
    wr_done2 <=  wr_done2_comb;
    for( int i = 0; i < NUM_BANKS; i++)begin
        if (odata_accum_ready[i]== 0 & !full2[i] )begin
            enaA[i] <= 1;
            weA2[i] <= 1;
            doA2[i] <= odata_accum_local[kernel_count[i]];
            bank_idx2[i] <= 1;
        end
        else begin
            enaA[i] <= 0;
            weA2[i] <= 0;
            doA2[i] <= 0;
            bank_idx2[i] <= 0;
        end
    end


end
end

always_comb begin
    if( (next_state == IDLE || next_state == PARAM_READ ) & (curr_state == BRAM_WRITE) )
        wr_done2_comb = 1;
    else 
        wr_done2_comb = 0;

end
//logic for  out_channel_counter AND out_seq_counter;
always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    out_channel_counter <= 0; 
    out_seq_counter <= 0;
    layer_count <= 0;
end
else 
    if( curr_state == BRAM_WRITE)begin
        if( act_first_oc_next )begin
            if( odata_accum_valid[NUM_BANKS-1] & odata_accum_ready[NUM_BANKS-1] )begin
                if( (out_seq_counter != (out_seq_length +(NUM_ROWS)-1) >> $clog2(NUM_ROWS)  -1) & out_channel_counter != out_chan_size>>$clog2((STREAM_WIDTH/RESULT_BIT)) -1 )begin
                    //out_channel_counter <= out_channel_counter + 1;
                    out_seq_counter <= out_seq_counter + 1;
                end
                else if( (out_seq_counter == (out_seq_length +(NUM_ROWS)-1) >> $clog2(NUM_ROWS)  -1) & out_channel_counter != out_chan_size>>$clog2((STREAM_WIDTH/RESULT_BIT)) -1 )begin
                    out_channel_counter <= out_channel_counter + 1;
                    out_seq_counter <= 0;
                end
                else if( (out_seq_counter != (out_seq_length +(NUM_ROWS)-1) >> $clog2(NUM_ROWS)  -1) & out_channel_counter == out_chan_size>>$clog2((STREAM_WIDTH/RESULT_BIT)) -1 )begin
                    out_channel_counter <= 0; //not used
                    out_seq_counter <= out_seq_counter + 1; //not used
                end
                else begin
                    out_channel_counter <= 0; 
                    out_seq_counter <= 0;
                    layer_count <= layer_count + 1;
                end
            end
        end
        else begin
            if( odata_accum_valid[NUM_BANKS-1] & odata_accum_ready[NUM_BANKS-1] )begin
                if( (out_seq_counter != (out_seq_length +(NUM_ROWS)-1) >> $clog2(NUM_ROWS)  -1) & out_channel_counter != out_chan_size>>$clog2((STREAM_WIDTH/RESULT_BIT)) -1 )begin
                    out_channel_counter <= out_channel_counter + 1;
                    //out_seq_counter <= out_seq_counter + 1;
                end
                else if( (out_seq_counter == (out_seq_length +(NUM_ROWS)-1) >> $clog2(NUM_ROWS)  -1) & out_channel_counter != out_chan_size>>$clog2((STREAM_WIDTH/RESULT_BIT)) -1 )begin
                    out_channel_counter <= out_channel_counter + 1; //not used
                    out_seq_counter <= 0; //not used
                end
                else if( (out_seq_counter != (out_seq_length +(NUM_ROWS)-1) >> $clog2(NUM_ROWS)  -1) & out_channel_counter == out_chan_size>>$clog2((STREAM_WIDTH/RESULT_BIT)) -1 )begin
                    out_channel_counter <= 0;
                    out_seq_counter <= out_seq_counter + 1;
                end
                else begin
                    out_channel_counter <= 0;
                    out_seq_counter <= 0;
                    layer_count <= layer_count + 1;
                end
            end

        end
    end
    else begin
            out_channel_counter <= 0; 
            out_seq_counter <= 0;
    end
end

/*
    //to iwritecontroller1 ( Data channel )
    input logic [PARAM_WIDTH-1:0]param_data_iwr2,  
    input logic param_data_valid_iwr2, 
    output logic param_data_ready_iwr2, 

    //to iwritecontroller1 ( Address channel )
    output logic [PARAM_WIDTH-1:0]param_addr_iwr2,  
    output logic param_addr_valid_iwr2, 
    input logic param_addr_ready_iwr2 
*/

always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    param_data_ready_iwr2 <= 0;
    param_addr_iwr2 <= 0;
    param_addr_valid_iwr2 <= 0;
end
else begin
    case( curr_state)
    IDLE:begin 
        if( next_state == NUM_LAYER_READ )begin
                param_addr_iwr2 <=  param_addr_iwr2 + 1;
                param_addr_valid_iwr2 <=  1;
                param_data_ready_iwr2 <= 1;
           end
           else begin
                param_data_ready_iwr2 <= 0;
                param_addr_iwr2 <= 0;
                param_addr_valid_iwr2 <= 0;
           end
        end
    NUM_LAYER_READ:begin 
        if( next_state == PARAM_READ)begin
            param_addr_valid_iwr2 <=  1;
            param_data_ready_iwr2 <= 1;
            param_addr_iwr2 <=  param_addr_iwr2 + 1;
        end
        else if( param_addr_valid_iwr2 & param_addr_ready_iwr2  )begin
            param_addr_valid_iwr2 <=  0;
            param_data_ready_iwr2 <= 1; 

        end
        
        if( param_data_valid_iwr2 & param_data_ready_iwr2 )begin
            num_layer <= param_data_iwr2;
            param_data_ready_iwr2 <= 0;
        end
    end
    PARAM_READ:begin
        if( param_addr_valid_iwr2 & param_addr_ready_iwr2  )begin
            param_addr_valid_iwr2 <=  0;
            param_data_ready_iwr2 <= 1; 
        end
        
        if( param_data_valid_iwr2 & param_data_ready_iwr2 )begin
            num_layer <= param_data_iwr2;
            param_data_ready_iwr2 <= 0;
        end
    end
    BRAM_WRITE: begin
        if( next_state == IDLE)begin
            param_addr_valid_iwr2 <=  0;
            param_data_ready_iwr2 <= 0;
            param_addr_iwr2 <=  0;
        end
        else if ( next_state == PARAM_READ)begin
            param_addr_valid_iwr2 <=  1;
            param_data_ready_iwr2 <= 1;
            param_addr_iwr2 <=  param_addr_iwr2 + 1;
        end
    end
    endcase
end
end

//next_state
always_comb begin
case( curr_state )
IDLE:begin 
    if( param_addr_ready_iwr2 )
        next_state = NUM_LAYER_READ;
      else
        next_state = IDLE;
end
NUM_LAYER_READ: if ( param_data_valid_iwr2 & param_data_ready_iwr2 )
                    next_state = PARAM_READ;
                else 
                    next_state = NUM_LAYER_READ;
PARAM_READ: if ( param_data_valid_iwr2 & param_data_ready_iwr2 )
                    next_state = BRAM_WRITE;
            else 
                next_state = PARAM_READ;

BRAM_WRITE:begin
        if((out_channel_counter == ((out_chan_size +(STREAM_WIDTH/ACT_WIDTH)-1) >> $clog2(STREAM_WIDTH/ACT_WIDTH) ) -1 ) & (out_seq_counter== (out_seq_length +(NUM_ROWS)-1) << $clog2(NUM_ROWS)  -1) & layer_count == num_layer -1 )begin
            next_state = IDLE;
        end
        else if((out_channel_counter == ((out_chan_size +(STREAM_WIDTH/ACT_WIDTH)-1) >> $clog2(STREAM_WIDTH/ACT_WIDTH) ) -1 ) & (out_seq_counter== (out_seq_length +(NUM_ROWS)-1) << $clog2(NUM_ROWS)  -1) & layer_count != num_layer -1 )begin
            next_state = PARAM_READ;
        end
        else 
            next_state = BRAM_WRITE;
end
endcase
end


//get the params
//obtaining the parameters
always_comb begin
    {act_first_oc_next, out_seq_len, out_chan_size, accum_total, kernel_size, in_chan_size,in_seq_length} = param_data_iwr2;
end


endmodule