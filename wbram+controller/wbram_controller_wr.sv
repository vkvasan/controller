module wbram_controller_wr#(
    parameter STREAM_WIDTH = 128,
    parameter WBRAM_WIDTH = STREAM_WIDTH //WRITE WIDTH OF BRAM, 
    NUM_BANKS = 16,
    WBRAM_DEPTH = (WEIGHT_BIT * (MAX_OUT_CHANNEL/NUM_BANKS) * MAX_IN_CHANNEL * MAX_KERNEL_SIZE )/WBRAM_WIDTH, //WRITE DEPTH OF BRAM
    MAX_OUT_CHANNEL = 128, 
    MAX_IN_CHANNEL = 45,
    MAX_KERNEL_SIZE = 5, 
    MAX_OUT_SEQ = 160, 
    MAX_NUM_LAYERS = 4,
    PARAM_WIDTH = $clog2(MAX_OUT_CHANNEL) + $clog2(MAX_IN_CHANNEL) + $clog2(MAX_KERNEL_SIZE) + $clog2(MAX_OUT_CHANNEL*MAX_KERNEL_SIZE), 
    WEIGHT_BIT = 8 
    )(
    input logic clk,
    input logic rst_n, 

    //axi signals 
    input logic [STREAM_WIDTH-1:0]wdata,
    input logic wdata_valid, 
    output logic wdata_ready, 

    //to WBRAM selector
    output logic [$clog2(WBRAM_DEPTH)-1:0]addrA, 
    output logic [STREAM_WIDTH-1:0]diA, 
    output logic [NUM_BANKS-1:0]enaA, 
    output logic [NUM_BANKS-1:0]weA, 
    output logic [$clog2(NUM_BANKS)-1:0]bank_counter,
    output logic ping_pong, 

    //to wbram_controller_rd
    output logic [1:0]wr_pointer_data,  //considering memory double buffering
    output logic wr_pointer_valid, 
    input logic wr_pointer_ready, 

    //from wbram_controller_rd, 
    input logic rd_pointer_data[1:0], 
    input logic rd_pointer_valid,
    output logic rd_pointer_ready


    //from param_module, // data channel 
    input logic [PARAM_WIDTH-1:0]param_data, 
    input logic param_data_valid,
    output logic  param_data_ready

    //to param_module, ( address channel )
    output logic [$clog2(MAX_NUM_LAYERS):0]param_addr, 
    output logic param_addr_valid,
    input logic  param_addr_ready


);

logic full; 
logic empty;
logic [1:0]rd_pointer_local;
logic [1:0]wr_pointer_local;
logic [PARAM_WIDTH-1:0]param_data_local;
logic param_data_set; //set after receveving the param value
logic[$clogs(MAX_NUM_LAYERS)-1:0]num_layers;
logic num_layers_set //set after receveving the total number of layers
logic [$clogs(MAX_NUM_LAYERS)-1:0]layer_count;
logic [$clog2(MAX_IN_CHANNEL)-1:0]num_in_channel;
logic [$clog2(MAX_OUT_CHANNEL)-1:0]num_out_channels;
logic [$clog2(MAX_KERNEL_SIZE)-1:0]kernel_size;
logic [$clog2(MAX_IN_CHANNEL*MAX_KERNEL_SIZE)-1:0]accum_total;

logic [$clog2((MAX_OUT_CHANNEL/NUM_BANKS) *MAX_IN_CHANNEL * MAX_KERNEL_SIZE )-1:0][NUM_BANKS-1:0] bram_counter;
logic [$clog2(MAX_OUT_CHANNEL)-1:0]out_channel_count;


//logic [$clog2(MAX_OUT_SEQ)-1:0]out_sequence_length; Not needed 


typedef enum logic [2:0] {IDLE, PARAM_READ, BRAM_WRITE} STATE;
STATE curr_state,next_state;


/***outputs as function of current state, input state and local registers***/
//WBRAM selector
/*
    output logic [$clog2(WBRAM_DEPTH)-1:0]addrA, 
    output logic [STREAM_WIDTH-1:0]diA, 
    output logic enaA, 
    output logic weA, 
    output logic [$clog2(NUM_BANKS)-1:0]bank_counter
    output ping_pong
    ////output all of this at the same clock edge when data is received from AXI Stream and the module is in BRAM_WRITE PHASE
*/

always_ff begin
if( !rst_n )begin
    addrA <= -1;
    diA <= 0;
    enaA <= 0;
    weA <= 0;
end
begin
    if( state == BRAM_WRITE & wdata_valid == 1 & wdata_ready == 1)begin
        if( addrA - bram_counter[bank_counter] == accum_total-1 )begin
            addrA <= bram_counter[bank_counter+1];
        end
        else 
            addrA <= addrA + 1;
        diA <= wdata;
        enaA <= 1;
        weA <= 1;
    end
    else begin
        enaA <= 0;
        weA <= 0;
    end
end
end

always_comb
    ping_pong = wr_pointer_local[0];


////from/to wbram_controller_rd
/*  
    /from
    output logic [1:0]wr_pointer_data,  //considering memory double buffering //comb assigned outside
    output logic wr_pointer_valid, 
    ////output only after num_layers is set . 
    /to
    output logic rd_pointer_ready
    ////always set ready. 
*/
always_ff begin
if( !rst_n )begin
    wr_pointer_valid <= 0;
    rd_pointer_ready <= 1;
end
begin
    rd_pointer_ready <= 1;
    if( wr_pointer_ready == 1 & num_layers_set == 1 )begin
         wr_pointer_valid <= 1;
    end
    else begin
        wr_pointer_valid <= 0;
    end
end
end

////to param_module( addr stream)
/*  

    //to param_module, ( address channel )
    output logic [PARAM_WIDTH-1:0]param_addr, 
    output logic param_addr_valid,

    //////Output this when you are in PARAM_READ PHASE or IDLE PHASE with param_data_set, num_layers_set.

*/
always_ff begin
if( !rst_n )begin
    param_addr <= 0;
    param_addr_valid <= 0;
end
begin
    if( curr_state == IDLE)begin
        if( num_layers_set == 0 & param_addr_ready == 1 & param_addr_valid == 0 )begin
            param_addr_valid <= 1;
            param_addr <= 0;
        end
        else begin
            param_addr_valid <= 0;
            param_addr <= 0;
        end
    end
    else if( curr_state == PARAM_READ) begin
        if( param_data_set == 0 & param_addr_ready == 1 & param_addr_valid == 0)begin
            param_addr_valid <= 1;
            param_addr <= param_addr + 1;
        end
        else begin
            param_addr_valid <= 0;
        end
    end
    else begin
        param_addr_valid <= 0;
    end
end
end


////from param_module( data stream)
/*  
    output logic param_data_ready
    if param_data_set is not high, param_data_ready is high
    if( param_data_valid is high and param_data_set is low, )

*/

always_ff begin
if( !rst_n )begin
    param_data_ready <= 0;
end
begin
    if( curr_state == IDLE)begin
       if( next_state == PARAM_READ)begin
            param_data_ready <= 1;
       end
       else 
           param_data_ready <= 0; 
    end
    else if( curr_state == BRAM_WRITE) begin
        if (next_state == PARAM_READ)begin
            param_data_ready <= 1;
        end
        else begin
            param_data_ready <= 0;
        end
    end
    else begin
        if( param_data_valid )
            param_data_ready <= 0;
        else
            param_data_ready <= 1;
    end
end
end



////from/to param_module( addr stream)
/*  
    //from param_module, // data channel 
    output logic  param_data_ready


    //////Output this ready always

    //to param_module, ( address channel )
    output logic [PARAM_WIDTH-1:0]param_addr, 
    output logic param_addr_valid,

    //////Output this when you are in PARAM_READ PHASE or IDLE PHASE and when param_addr_ready = 1 & param_data_set = 0
*/
always_ff begin
if( !rst_n )begin
    param_data_ready <= 0;
    param_addr <= 0;
    param_addr_valid <= 0;
end
begin
    if( curr_state == IDLE)begin
        if( param_addr_ready == 1 & num_layers_set == 0)begin
            param_addr <= 0;
            param_addr_valid <= 1;
        end
    end
    else if( curr_state == PARAM_READ) begin
        if( param_addr_ready == 1 & num_layers_set == 1 )begin
            param_addr <= param_addr + 1;
            param_addr_valid <= 1;
        end
    end
end
end

////AXI Stream ports interfacing outside the IP ( data stream)
/*
    output logic wdata_ready

    if full , make it 0. 
*/
always_ff begin
if( !rst_n )begin
    wdata_ready <= 0;
end
begin
    if( curr_state == BRAMfull )
        wdata_ready <= 0;
    else 
        wdata_ready <= 1;
end
end




/*******************************Local registers **************************
logic full; //comb 
logic empty; //comb
logic [1:0]rd_pointer_local; //reg
logic [1:0]wr_pointer_local; //reg
logic [PARAM_WIDTH-1:0]param_data_local; //reg
logic param_data_set; //set after receveving the param value reg
logic[$clogs(MAX_NUM_LAYERS)-1:0]num_layers;//reg
logic num_layers_set //set after receveving the total number of layers //reg
logic [$clogs(MAX_NUM_LAYERS)-1:0]layer_count;reg
logic state;
logic next_state;
logic [$clog2(MAX_IN_CHANNEL)-1:0]num_in_channel;
logic [$clog2(MAX_OUT_CHANNEL)-1:0]num_out_channels;
logic [$clog2(MAX_KERNEL_SIZE) -1 :0]kernel_size;
logic [$clog2(MAX_IN_CHANNEL*MAX_KERNEL_SIZE)-1:0]accum_total;

logic [$clog2(MAX_OUT_CHANNEL)-1:0]out_channel_count; //reg
logic [$clog2((MAX_OUT_CHANNEL/NUM_BANKS) *MAX_IN_CHANNEL * MAX_KERNEL_SIZE )-1:0] bram_counter; //reg

**************************************************************************/

//address generation ff and comb
always_ff begin
if( !rst_n )begin
    out_channel_count <= 0;
    bram_counter <= 0;
end
else begin
    if( curr_state != BRAM_WRITE ) begin
        out_channel_count <= 0;
        bram_counter <= 0;
    end
    else begin
        if( addrA - bram_counter[bank_counter] == accum_total-1 )begin
            out_channel_count <= out_channel_count + 1;
            bram_counter[bank_counter] <= bram_counter[bank_counter] + accum_total;
        end
    end
end
end 


always_comb begin
 wr_pointer_data = wr_pointer_local; // this is an output-> redundant assignment
 empty = (wr_pointer_local == rd_pointer_local) ? 1 : 0;
 full = (wr_pointer_local[0] == rd_pointer_local[0]) & (wr_pointer_local[1] != rd_pointer_local[1]) ? 1 : 0;
    num_in_channel = param_data_local[$clog2(MAX_IN_CHANNEL) -1:0];
    num_out_channel = param_data_local[$clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL) -1:$clog2(MAX_IN_CHANNEL)];
    kernel_size = param_data_local[ $clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL) + $clog2(MAX_KERNEL_SIZE) -1:$clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL)  ];
    accum_total = param_data_local[$clog2(MAX_OUT_CHANNEL*MAX_KERNEL_SIZE) + $clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL)+ $clog2(MAX_KERNEL_SIZE) -1:$clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL) + $clog2(MAX_KERNEL_SIZE)  ];
    bank_counter = out_channel_count[$clog2(NUM_BANKS)-1:0]; 
end


//next state
always_comb begin
case( curr_state)
IDLE:begin
    if( param_addr_ready )begin
        next_state = PARAM_READ; 
    end
    else 
        next_state = IDLE;
end
PARAM_READ: begin
if( param_data_valid & param_data_ready )begin
                if(num_layers_set )
                    next_state = BRAM_WRITE;
                else begin
                    next_state = PARAM_READ;
                end
            end 
            else begin
                next_state = PARAM_READ;
            end
end
BRAM_WRITE: begin
                if( layer_count == num_layers -1 & out_channel_count == num_out_channel-1 & (addrA - bram_counter[bank_counter])== accum_total-1  )
                    next_state = IDLE;
                else if( out_channel_count == num_out_channel-1 & (addrA - bram_counter[bank_counter])== accum_total-1)begin
                    next_state = PARAM_READ;
                end
                else begin
                    next_state = BRAM_WRITE;
                end

            
end
endcase
end


always_ff begin
    if( curr_state == PARAM_READ )begin
        if(num_layers_set == 0)begin
            if(param_data_valid & param_data_ready)begin
                num_layers_set <= 1;
                num_layers <= param_data;
            end
        end
        else begin
            if(param_data_valid & param_data_ready)begin
                param_data_set <= 1;
                param_data_local <= param_data;
            end
        end
    end
    else if( curr_state == BRAM_WRITE )begin
        if (next_state == PARAM_READ)begin
            param_data_set <= 0;
        end
        else 
            param_data_set <= 1;
    end
    else begin
        param_data_set <= 0; 
        num_layers_set <= 0;
    end
    
end
// layer_count, rd_pointer_local , wr_pointer_local
always_ff begin
if(!rst_n)begin
    wr_pointer_local <= 0;
    layer_count <= 0;
end
else begin

    if( curr_state == IDLE )begin
        layer_count <= 0;
        wr_pointer_local <= 0;
    end
    if( curr_state ==  BRAM_WRITE & next_state == PARAM_READ)begin
        layer_count <= layer_count + 1;
        wr_pointer_local <= wr_pointer_local + 1;
    end
end
end

//rd_pointer_local
always_ff begin
if( !rst_n )
    rd_pointer_local <= 0;
else begin
    if( rd_pointer_data_valid & rd_pointer_ready)
        rd_pointer_local <=  rd_pointer_data;
end
end


endmodule