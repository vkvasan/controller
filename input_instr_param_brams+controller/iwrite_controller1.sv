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

    //axi signals 
    input logic [STREAM_WIDTH-1:0]idata,
    input logic idata_valid, 
    output logic idata_ready, 

    //to IBRAM selector
    //output logic [$clog2(WBRAM_DEPTH)-1:0]addrA, 
    output logic [STREAM_WIDTH-1:0]diA, //act_data
    output logic [NUM_BANKS-1:0]enaA, 
    output logic [NUM_BANKS-1:0]weA, 
    output logic [NUM_BANKS-1:0]bank_idx,
    output logic wr_done1,
    input logic [NUM_BANKS-1:0]full1,
    //input [NUM_BANKS-1:0][$clog2(READ_DEPTH):0]read_addrB_ping_pong;

    //to instruction buffer 
    output logic [STREAM_WIDTH-1:0]idata_instr,
    output logic idata_instr_valid,
    output logic [$clog2(NUM_BANKS)-1:0]instr_bank_counter, 
    input logic idata_instr_ready, 
    input logic instr_fill_done,

    //param_module // data channel 
    output logic [PARAM_WIDTH-1:0]param_data, 
    output logic param_data_valid,
    input logic  param_data_ready,

    //param_module //address channel
    input logic [$clog2(MAX_NUM_LAYERS):0]param_addr, 
    input logic param_addr_valid,
    output logic  param_addr_ready,

    //to IBRAM_controller_rd ( Data channel )
    output logic [PARAM_WIDTH-1:0]param_data_rd,  
    output logic param_data_valid_rd, 
    input logic param_data_ready_rd, 

    //to IBRAM_controller_rd ( Address channel )
    input logic [PARAM_WIDTH-1:0]param_addr_rd,  
    input logic param_addr_valid_rd, 
    output logic param_addr_ready_rd, 

    //to iwritecontroller2 ( Data channel )
    output logic [PARAM_WIDTH-1:0]param_data_iwr2,  
    output logic param_data_valid_iwr2, 
    input logic param_data_ready_iwr2, 

    //to iwritecontroller2 ( Address channel )
    input logic [PARAM_WIDTH-1:0]param_addr_iwr2,  
    input logic param_addr_valid_iwr2, 
    output logic param_addr_ready_iwr2 
);

typedef enum  logic[2:0] {IDLE, NUM_LAYER_READ, PARAM_WRITE, INSTR, BRAM_WRITE   } STATE;
STATE curr_state,next_state;

logic [NUM_ROWS-1:0][NUM_TILES-1:0]or_stages;
logic [MAX_OUT_SEQ + MAX_KERNEL_SIZE -1:0] temp_valid;
logic [$clog2(MAX_IN_CHANNEL)-1:0]in_channel_counter;
logic [$clog2(MAX_OUT_SEQ)-1:0]in_seq_counter;
logic [$clog2(MAX_KERNEL_SIZE)-1:0]kernel_size;
/***outputs as function of current state, input state and local registers***/
//
// Output logic idata_ready( axi )
//IBRAM selector
/*
    output logic [STREAM_WIDTH-1:0]diA, //act_data
    output logic [NUM_BANKS-1:0]enaA, 
    output logic [NUM_BANKS-1:0]weA, 
    output logic [NUM_BANKS-1:0]bank_idx

    ////output all of this at the same clock edge when data is received from AXI Stream and the module is in BRAM_WRITE PHASE
*/

logic [NUM_BANKS-1:0]temp;
genvar i;
generate
    temp[0] = !full1[1] | !full1[0] ;
    for( i = 1; i < NUM_BANKS;i++)begin
        temp[i] = temp[i-1] | !full1[i];
    end
endgenerate
 
logic [STREAM_WIDTH-1:0]diA_reg;
always_ff begin
if( !rst_n )begin
    idata_ready <= 0;
    diA <= 0;
    diA_reg <= 0;
end
begin
    if ( curr_state == WRITE)begin
        idata_ready <= temp[NUM_BANKS-1]; 
        if( curr_state == BRAM_WRITE & idata_ready & idata_valid)begin
            diA_reg <= idata;
            diA <= diA_reg;
        end
    end
    if ( curr_state == INSTR )begin
        idata_ready <= idata_instr_ready & !instr_fill_done;
    end
end
end

//enaA, weA
always_ff begin
if( !rst_n )begin
    enaA <= 0;
    weA <= 0;
end
begin
    if( curr_state == BRAM_WRITE )begin
        enaA <= temp_valid;
        weA <= temp_valid;
    end

end
end

//logic for in_seq_counter
//logic for in_channel_counter
//logic for out_seq_valid //comb
//logic for bank_idx //comb
// Function to generate the valid signal

function automatic logic [MAX_OUT_SEQ_LEN + MAX_KERNEL_SIZE - 1:0] fn_valid(
    input logic [$clog2(MAX_OUT_SEQ_LEN)-1:0] inseq_counter,
    input logic [$clog2(MAX_KERNEL_SIZE)-1:0] kernel_size_reg
);
    logic [MAX_OUT_SEQ_LEN + MAX_KERNEL_SIZE - 1:0] temp_valid;
    begin
        temp_valid = '0;
        for (int i = 0; i < MAX_KERNEL_SIZE; i++) begin
            if (i < kernel_size_reg)
                temp_valid[inseq_counter + MAX_KERNEL_SIZE - i] = 1;
        end
        return temp_valid;
    end
endfunction

genvar i;
generate 
for( i = 0; i < NUM_ROWS;i++)begin:tg1
	assign or_stages[i][0] = temp_valid[MAX_KERNEL_SIZE + i];
	for( j =1; j < NUM_TILES;j++)begin:tg2
		assign or_stages[i][j] = or_stages[i][j-1] | temp_valid[MAX_KERNEL_SIZE + i + j*NUM_ROWS];
	end
	assign bank_idx[i] = or_stages[i][NUM_TILES-1];
end
endgenerate

//temp_valid (out_seq_valid)
//logic for in_seq_counter
//logic for in_channel_counter

always_ff@(posedge clk or negedge rst_n )begin
    in_seq_counter <= 0;
    in_channel_counter <= 0;
    wr_done1 <= 0;
end
else begin
    if (curr_state == BRAM_WRITE & idata_ready & idata_valid )begin
        if( next_state == BRAM_WRITE)begin
            if( in_channel_counter == ((in_chan_size +(STREAM_WIDTH/ACT_WIDTH)-1) << $clog2(STREAM_WIDTH/ACT_WIDTH) ) -1 )begin
                in_seq_counter <= in_seq_counter + 1;
                in_channel_counter <= 0;
            end
            else 
                in_channel_counter <= in_channel_counter + 1;
        end
        else begin
            in_channel_counter <= 0;
            in_seq_counter <= 0;
            wr_done1 <=  1;
        end
    end
    if( curr_state ! = BRAM_WRITE )
        wr_done1 <= 0;
    if( curr_state == BRAM_WRITE & idata_ready & idata_valid)begin
        temp_valid <= fn_valid(inseq_counter, kernel_size);  //fn call
    end
    else begin
        temp_valid <= 0;
    end
end

/*Outputs
    //to instruction buffer 
    output logic [STREAM_WIDTH-1:0]idata_instr,
    output logic idata_instr_valid,
    output logic [$clog2(NUM_BANKS)-1:0]instr_bank_counter, 
    input logic idata_instr_ready, 
    input logic instr_fill_done,
*/

always_ff @(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    idata_instr <= 0;
    idata_instr_valid <= 0;
    instr_bank_counter <=0;
end
else begin
    if(curr_state == INSTR )begin
        if( idata_ready & idata_valid )begin
            instr_bank_counter <=  instr_bank_counter + 1;
            idata_instr_valid <= 1;
            idata_instr <=  idata;
        end
        else 
            idata_instr_valid <= 0;

    end
end
end


/*
    //param_module // data channel 
    output logic [PARAM_WIDTH-1:0]param_data, 
    output logic param_data_valid,
    input logic  param_data_ready,

    //param_module //address channel
    input logic [$clog2(MAX_NUM_LAYERS):0]param_addr, 
    input logic param_addr_valid,
    output logic  param_addr_ready,
*/
logic [$clog2(MAX_NUM_LAYERS)-1:0][PARAM_WIDTH-1:0]param_buffer;
logic [$clog2(MAX_NUM_LAYERS)-1:0]param_counter;

//writing param_buffer
always_ff @(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    param_buffer <= 0;
    param_counter <= param_counter + 1;
end
else begin
    if(curr_state == PARAM_WRITE || curr_state == NUM_LAYER_READ)begin
        if ( idata_valid & idata_ready )    begin
            param_buffer[param_counter] <=  idata[PARAM_WIDTH-1:0];
            param_counter <= param_counter+1;
        end
    end
end
end


//data and address channel.. 
always_ff @(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    param_addr_ready <= 0;
    param_data_valid <= 0;
    param_data <=0;
end
else begin
    if(curr_state == PARAM_WRITE & next_state == INSTR )begin
        param_addr_ready <= 1;
    end

    if( param_addr_ready & param_addr_valid )begin
        param_data <= param_buffer[param_addr];
        param_data_valid <= 1;
    end
    if( param_data_valid & param_data_ready)
        param_data_valid <= 0;
end
end

/*
    //to IBRAM_controller_rd ( Data channel )
    output logic [PARAM_WIDTH-1:0]param_data_rd,  
    output logic param_data_valid_rd, 
    input logic param_data_ready_rd, 

    //to IBRAM_controller_rd ( Address channel )
    input logic [PARAM_WIDTH-1:0]param_addr_rd,  
    input logic param_addr_valid_rd, 
    output logic param_addr_ready_rd, 

    //to iwritecontroller2 ( Data channel )
    output logic [PARAM_WIDTH-1:0]param_data_iwr2,  
    output logic param_data_valid_iwr2, 
    input logic param_data_ready_iwr2, 

    //to iwritecontroller2 ( Address channel )
    input logic [PARAM_WIDTH-1:0]param_addr_iwr2,  
    input logic param_addr_valid_iwr2, 
    output logic param_addr_ready_iwr2 

*/

always_ff@(posedge clk or negedge rst_n ) begin
if(!rst_n)begin
    param_data_rd <= 0;
    param_data_valid_rd <= 0;
    param_addr_ready_rd <=0;
    param_data_iwr2 <= 0;
    param_data_valid_iwr2 <= 0;
    param_addr_ready_iwr2 <= 0;
end
else begin
    if(curr_state == PARAM_WRITE & next_state == INSTR )begin
        param_addr_ready_rd <= 1;
        param_addr_ready_iwr2 <= 1;
    end

    if( param_addr_ready_rd & param_addr_valid_rd )begin
        param_data_rd <= param_buffer[param_addr_rd];
        param_data_valid_rd <= 1;
    end
    if( param_data_valid_rd & param_data_ready_rd)
        param_data_valid_rd <= 0;

    if( param_addr_ready_iwr2 & param_addr_valid_iwr2 )begin
        param_data_iwr2 <= param_buffer[param_addr_iwr2];
        param_data_valid_iwr2 <= 1;
    end
    if( param_data_valid_iwr2 & param_data_ready_iwr2)
        param_data_valid_iwr2 <= 0;
end
end

//next_state
always_comb begin
case(curr_state )
IDLE: if( ird_data_valid )
        next_state = NUM_LAYER_READ;
      else
        next_state = IDLE;

NUM_LAYER_READ: if ( idata_valid & idata_ready )
                    next_state = PARAM_WRITE;
                else 
                    next_state = NUM_LAYER_READ;
PARAM_WRITE: if ( param_counter == num_layer-1 )
                    next_state = INSTR;
            else 
                next_state = PARAM_WRITE;

INSTR: if ( instr_fill_done )
                next_state = BRAM_WRITE;
            else 
                next_state = PARAM_WRITE;

BRAM_WRITE:begin
        if((in_channel_counter == ((in_chan_size +(STREAM_WIDTH/ACT_WIDTH)-1) << $clog2(STREAM_WIDTH/ACT_WIDTH) ) -1 ) & (in_seq_counter== in_seq_length -1))begin
            next_state = IDLE;
        end
        else 
            next_state = BRAM_WRITE;
end


endcase
end




always_comb begin
    in_chan_size = param_buffer[1][$clog2(MAX_IN_CHANNEL)-1:0];
    in_seq_length = param_buffer[1][ $clog2(MAX_IN_CHANNEL) + $clog2(MAX_OUT_SEQ)  -1:$clog2(MAX_IN_CHANNEL)];
    kernel_size=  param_buffer[1][$clog2(MAX_IN_CHANNEL) + $clog2(MAX_OUT_SEQ) + $clog2(MAX_KERNEL_SIZE) -1: $clog2(MAX_IN_CHANNEL) + $clog2(MAX_OUT_SEQ)];
end


endmodule