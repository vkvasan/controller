module wbram_controller_rd_leftpe#(
    parameter STREAM_WIDTH = 128,
     WBRAM_WIDTH = STREAM_WIDTH //WRITE WIDTH OF BRAM, 
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

    // to/from weight axi_bram
    output logic [$clog2(WBRAM_DEPTH)-1:0]addrB, 
    input  logic [STREAM_WIDTH-1:0]diB, 
    //input logic diB_valid,
    output logic enaB, 
    output logic weB, 
    
    //from wbram_controller_wr ( wr--------1st PE )
    input logic [1:0]wr_pointer_data_l,  //considering memory double buffering
    input logic wr_pointer_valid_l, 
    output logic wr_pointer_ready_l, 

    //to wbram_controller_rd ( 1st pe --------- neighbouring PE ) //POINTER
    output logic [1:0]wr_pointer_data_r,  //considering memory double buffering
    output logic wr_pointer_valid_r, 
    input logic wr_pointer_ready_r, 
    //to wbram_controller_rd ( 1st pe --------- neighbouring PE ) //PARAMS 
    output logic [1:0]param_data_r,  //considering memory double buffering
    output logic param_data_valid_r, 
    input logic param_data_ready_r, 
    output logic start, 

    //from param_module, // data channel 
    input logic [PARAM_WIDTH-1:0]param_data_l, 
    input logic param_data_valid_l,
    output logic  param_data_ready_l

    //to param_module, ( address channel )
    output logic [$clog2(MAX_NUM_LAYERS):0]param_addr_l, 
    output logic param_addr_valid_l,
    input logic  param_addr_ready_l, 


    //to systolic array
    output logic[WEIGHT_BIT-1:0]w_sys_data;
    output logic w_sys_valid, 
    input logic w_sys_ready

);

typedef enum logic [2:0] {IDLE, PARAM_READ, BRAM_READ} STATE;
STATE curr_state,next_state;

logic [$clog2(WBRAM_DEPTH)-1:0]addrB_reg;
logic enaB_reg;
logic param_data_set;
logic num_layers_set;
logic [$clog2(MAX_OUT_CHANNEL/NUM_BANKS * MAX_IN_CHANNEL * MAX_KERNEL_SIZE)]bram_counter;
logic [$clog2(MAX_OUT_CHANNEL/NUM_BANKS)]out_channel_count;

logic full; 
logic empty;
logic [1:0]rd_pointer_local;
logic [1:0]wr_pointer_local;
logic [PARAM_WIDTH-1:0]param_data_local;
logic[$clogs(MAX_NUM_LAYERS)-1:0]num_layers;
logic [$clogs(MAX_NUM_LAYERS)-1:0]layer_count;
logic [$clog2(MAX_IN_CHANNEL)-1:0]num_in_channel;
logic [$clog2(MAX_OUT_CHANNEL)-1:0]num_out_channels;
logic [$clog2(MAX_KERNEL_SIZE)-1:0]kernel_size;
logic [$clog2(MAX_IN_CHANNEL*MAX_KERNEL_SIZE)-1:0]accum_total;




/***outputs as function of current state, input state and local registers***/
//WBRAM interface
/*
    output logic [$clog2(WBRAM_DEPTH)-1:0]addrB,  //make it comb
    input  logic [STREAM_WIDTH-1:0]diB, 
    input logic diB_valid,
    output logic [NUM_BANKS-1:0]enaB, 
    output logic [NUM_BANKS-1:0]weB, 
    ////output all of this at the same clock edge when data is received from AXI Stream and the module is in BRAM_WRITE PHASE
*/
always_comb begin
    weB = 0;
    if( curr_state  == PARAM_READ )begin
        if(next_state == BRAM_READ & w_sys_ready == 1)begin
            addrB = 0;
            enaB = 1;
        end
    end
    else if( curr_state == BRAM_READ )begin
            if( next_state == BRAM_READ & w_sys_ready == 1 )begin
                addrB = addrB_reg + 1;
                enaB = 1;
            end
            else begin
                addrB = addrB_reg;
                enaB = 0;
            end
    end
    else begin
        addrB = addrB_reg;
        enaB = 0;
    end
end

always_ff begin
    enaB_reg <= enaB;
    if( state == BRAM_READ)
        addrB_reg <= addrB;
    else    
        addrB_reg <= 0;
end

/***
//from wbram_controller_wr ( wr--------1st PE )
    input logic [1:0]wr_pointer_data_l,  //considering memory double buffering
    input logic wr_pointer_valid_l, 
    output logic wr_pointer_ready_l, 

*/

always_ff begin
    if(!rst_n)
        wr_pointer_ready_l <= 1;
    else begin
        wr_pointer_ready_l <= wr_pointer_ready_r;
    end
end
/****
    //to wbram_controller_rd ( 1st pe --------- neighbouring PE ) //POINTER
        output logic [1:0]wr_pointer_data_r,  //considering memory double buffering
        output logic wr_pointer_valid_r, 
        input logic wr_pointer_ready_r, 
    //to wbram_controller_rd ( 1st pe --------- neighbouring PE ) //PARAMS 
        output logic [1:0]param_data_r,  //considering memory double buffering
        output logic param_data_valid_r, 
        input logic param_data_ready_r, 
*/
always_ff begin
    if(!rst_n) begin
        wr_pointer_data_r <= 0;
        wr_pointer_valid_r <= 0;
        param_data_r <= 0;
        param_data_valid_r <= 0;
    end
    else begin
        if( wr_pointer_valid_l & wr_pointer_ready_l)begin
            wr_pointer_data_r <= wr_pointer_data_l;
            wr_pointer_valid_r <= wr_pointer_valid_l;
        end
        else 
            wr_pointer_valid_r <= 0;
        
        if( param_data_valid_l & param_data_ready_l )begin
            param_data_r <= param_data_l;
            param_data_valid_r <= param_data_valid_l;
        end
        else 
            param_data_valid_r <= 0;

    end
end

//start
always_ff begin
if(!rst_n) 
    start<= 0;
else 
    if(curr_state == IDLE & param_addr_ready_l )
        start <=1;
    else start <= 0;

end

always_ff begin
if( !rst_n )begin
    param_data_ready_l <= 1;
end
begin
    if( curr_state == IDLE)begin
       if( next_state == PARAM_READ)begin
            param_data_ready_l <= 1;
       end
       else 
           param_data_ready_l <= 0; 
    end
    else if( curr_state == BRAM_WRITE) begin
        if (next_state == PARAM_READ)begin
            param_data_ready_l <= 1;
        end
        else begin
            param_data_ready_l <= 0;
        end
    end
    else begin
        if( param_data_valid_l )
            param_data_ready_l <= 0;
        else
            param_data_ready_l <= 1;
    end
end
end




/***
    //to param_module, ( address channel )
    output logic [PARAM_WIDTH-1:0]param_addr_l, 
    output logic param_addr_valid_l,
    input logic  param_addr_ready_l, 
*///
always_ff begin
    if(!rst_n)
        param_addr_l <= 0;
        param_addr_valid_l <= 0;
    else begin
        if( curr_state == IDLE & param_addr_ready_l & num_layers_set == 0 )begin
            param_addr_l <= 0;
            param_addr_valid_l <= 1;
        end
        if( curr_state == PARAM_READ )begin
            if(param_addr_ready_l & param_data_set == 0 & param_addr_valid == 0)begin
                param_addr_l <= param_addr_l + 1;
                param_addr_valid_l <= 1;
            end
            else 
                param_addr_valid_l <= 0;
        end
        else begin
            param_addr_valid <= 0;
        end

    end
end

/****
//to systolic array
    output logic[WEIGHT_BIT-1:0]w_sys_data;
    output logic w_sys_valid, 
    input logic w_sys_ready
*///

always_ff begin
    if(!rst_n)
        w_sys_data <= 0;
        w_sys_valid <= 0;
    else begin
        if( state == BRAM_READ & enaB_reg )begin
            w_sys_data <= diB;
            w_sys_valid <= 1;
        end
        else 
            w_sys_valid <= 0;
    end
end


//Next state
always_comb
case(curr_state)
IDLE:begin
    if( param_addr_ready_l )begin
        next_state = PARAM_READ; 
    end
    else 
        next_state = IDLE;
end
PARAM_READ: begin
            if( param_data_valid_l & param_data_ready_l )begin
                if(num_layers_set )
                    next_state = BRAM_READ;
                else begin
                    next_state = PARAM_READ;
                end
            end 
            else begin
                next_state = PARAM_READ;
            end
end
BRAM_READ:begin
                if( layer_count == num_layers -1 & out_channel_count == num_out_channel-1 & (addrB - bram_counter)== accum_total-1  )
                    next_state = IDLE;
                else if( out_channel_count == (num_out_channel>>NUM_BANKS)-1 & (addrB - bram_counter)== accum_total-1)
                    next_state = PARAM_READ;    
                else 
                    next_state = BRAM_WRITE;
                
end
endcase


//address generation ff 
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
        if( addrB - bram_counter == accum_total-1 )begin
            out_channel_count <= out_channel_count + 1;
            bram_counter <= bram_counter + accum_total;
        end
    end
end
end 

// layer_count, rd_pointer_local
always_ff begin
    if( state == IDLE )begin
        layer_count <= 0;
        rd_pointer_local <= 0;
    end
    if( curr_state ==  BRAM_READ & next_state == PARAM_READ)begin
        layer_count <= layer_count + 1;
        rd_pointer_local <= rd_pointer_local + 1;
    end
end

//wr_pointer_local
always_ff begin
if( !rst_n )
    wr_pointer_local <= 0;
else begin
    if( wr_pointer_valid_l & wr_pointer_ready_l)
        wr_pointer_local <=  wr_pointer_data_l;
end
end

//param_data_set and num_layer_set
always_ff begin
    if( curr_state == PARAM_READ )begin
        if(num_layers_set == 0)begin
            if(param_data_valid_l & param_data_ready_l)begin
                num_layers_set <= 1;
                num_layers <= param_data;
            end
        end
        else begin
            if(param_data_valid_l & param_data_ready_l)begin
                param_data_set <= 1;
                param_data_local <= param_data;
            end
        end
    end
    else if( curr_state == BRAM_READ )begin
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

always_comb begin
 empty = (wr_pointer_local == rd_pointer_local) ? 1 : 0;
 full = (wr_pointer_local[0] == rd_pointer_local[0]) & (wr_pointer_local[1] != rd_pointer_local[1]) ? 1 : 0;
    num_in_channel = param_data_set ? param_data_local[$clog2(MAX_IN_CHANNEL) -1:0] : 0;
    num_out_channel = param_data_set ? param_data_local[$clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL) -1:$clog2(MAX_IN_CHANNEL)] : 0;
    kernel_size = param_data_set ? param_data_local[ $clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL) + $clog2(MAX_KERNEL_SIZE) -1:$clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL)  ] : 0;
    accum_total = param_data_set ? param_data_local[$clog2(MAX_OUT_CHANNEL*MAX_KERNEL_SIZE) + $clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL)+ $clog2(MAX_KERNEL_SIZE) -1:$clog2(MAX_IN_CHANNEL)+$clog2(MAX_OUT_CHANNEL) + $clog2(MAX_KERNEL_SIZE)  ] : 0;
end


endmodule