module iwrite_controller1#(
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
    ACT_WIDTH = 8 
    )(

    input logic clk,
    input logic rst_n, 

    //from accumulator  
    input logic [NUM_ROWS-1:0][RESULT_BIT-1:0]idata_accum,
    input logic [NUM_ROWS-1:0]idata_accum_valid, 
    output logic [NUM_ROWS-1:0]idata_accum_ready, 

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

logic [$clog2(MAX_NUM_LAYERS)-1:0]layer_count;


/*
    //from quantizer  
    input logic [NUM_ROWS-1:0][ACT_WIDTH-1:0]odata,
    input logic [NUM_ROWS-1:0]odata_valid, 
    output logic [NUM_ROWS-1:0]odata_ready, 
*/
typedef enum  logic[1:0] {IDLE, PARAM_READ, BRAM_WRITE   } STATE;
STATE curr_state,next_state;

always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    odata_ready <= 0;
end
else begin
    if( curr_state == BRAM_WRITE)
        odata_ready <= 1<<NUM_ROWS-1;
    else 
        odata_ready <= 0;

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
    if( curr_state == BRAM_WRITE & next_state == PARAM_READ )begin
        param_addr_iwr2 <=  param_addr_iwr2 + 1;
        param_addr_valid_iwr2 <=  1;
        param_data_ready_iwr2 <= 1;
    end
    else if( curr_state == PARAM_READ)begin
        if( param_addr_valid_iwr2 & param_addr_ready_iwr2  )begin
            param_addr_valid_iwr2 <=  0;
        end
        if( param_data_valid_iwr2 & param_data_ready_iwr2 )begin
            param_data_local<= param_data_iwr2;
            param_data_ready_iwr2 <= 0;
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








//next_state
always_comb begin
case( curr_state )
IDLE:begin 
    if( param_addr_ready_iwr2 )
        next_state = PARAM_READ;
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
        if((in_channel_counter == ((in_chan_size +(STREAM_WIDTH/ACT_WIDTH)-1) << $clog2(STREAM_WIDTH/ACT_WIDTH) ) -1 ) & (in_seq_counter== in_seq_length -1))begin
            next_state = IDLE;
        end
        else 
            next_state = BRAM_WRITE;
end


endcase
end



endmodule