module param_arbiter(
    input logic clk,
    input logic rst_n, 

    //from read controller
    //address_channel
    input logic [$clog2(MAX_NUM_LAYERS):0]param_addr_l, 
    input logic param_addr_valid_l,
    output logic  param_addr_ready_l, 
    //to read controller
    // data channel 
    output logic [PARAM_WIDTH-1:0]param_data_l, 
    output logic param_data_valid_l,
    input logic  param_data_ready_l

    //to write controller
    // data channel 
    output logic [PARAM_WIDTH-1:0]param_data, 
    output logic param_data_valid,
    input logic  param_data_ready

    // from write controller
    //( address channel )
    input logic [$clog2(MAX_NUM_LAYERS):0]param_addr, 
    input logic param_addr_valid,
    output logic  param_addr_ready

    //to param_module(addr)
    output logic [$clog2(MAX_NUM_LAYERS):0]param_addr_p, 
    output logic param_addr_valid_p,
    input logic  param_addr_ready_p, 

    //to param_module(data)
    input logic [PARAM_WIDTH-1:0]param_data_p, 
    input logic param_data_valid_p,
    output logic  param_data_ready_p 

);

//write preference given over read 
typedef enum logic  {IDLE,WRITE, READ} STATE;
STATE curr_state,next_state;


/////////////////address channel /////////////////////////////
//deciding the correct address channel for the controller ( rd/wr)
always_ff begin
if(!rst_n)begin
    param_addr_ready_l <= 0;
    param_addr_ready <= 0;
end
else begin
    if( curr_state == WRITE )begin
        param_addr_ready <= param_addr_ready_p;
        param_addr_ready_l <= 0;
    end
    if( curr_state == READ )begin
        param_addr_ready <= 0;
        param_addr_ready_l <= param_addr_ready_p;
    end
end
end

//sending the right address to the param module 
always_ff begin
if(!rst_n)begin
    param_addr_ready_l <= 0;
    param_addr_ready <= 0;
end
else begin
    if( curr_state == WRITE )begin
        if( param_addr_ready & param_addr_valid )begin
            param_addr_p <= param_addr;
            param_addr_valid_p <= param_addr_valid;
        end
    end
    if( curr_state == READ )begin
        if( param_addr_ready_l & param_addr_valid_l )begin
            param_addr_p <= param_addr_l;
            param_addr_valid_p <= param_addr_valid_l;
        end
    end
end
end

/*///////////////DATA channel /////////////////////////////

    // data channel 
    output logic [PARAM_WIDTH-1:0]param_data_l, 
    output logic param_data_valid_l,
    input logic  param_data_ready_l

    // data channel 
    output logic [PARAM_WIDTH-1:0]param_data, 
    output logic param_data_valid,
    input logic  param_data_ready

    //to param_module(data)
    input logic [PARAM_WIDTH-1:0]param_data_p, 
    input logic param_data_valid_p,
    output logic  param_data_ready_p 

*///////////////////////////////////////////////////////////
//deciding the right channel 
always_ff begin
if(!rst_n)begin
    param_data_ready <= 0;
    param_data_ready_l <= 0;
end
else begin
    if( curr_state == WRITE )begin
        param_data_ready <= param_data_ready_p;
        param_data_ready_l <= 0;
    end
    if( curr_state == READ )begin
        param_data_ready <= 0;
        param_data_ready_l <= param_data_ready_p;
    end
end
end

always_ff begin
if(!rst_n)begin
    param_addr_ready_l <= 0;
    param_addr_ready <= 0;
end
else begin
    if( curr_state == WRITE )begin
        if( param_data_ready_p & param_data_valid_p)begin
            param_data <= param_data_p;
            param_data_valid <= param_data_valid_p;
            param_data_valid_l <= 0;
        end
        else begin
            param_data_valid <= 0;
            param_data_valid_l <= 0;
        end
    end
    else if( curr_state == READ )begin
        if( param_data_ready_p & param_data_valid_p)begin
            param_data_l <= param_data_p;
            param_data_valid_l <= param_data_valid_p;
            param_data_valid <= 0;
        end
        else begin
            param_data_valid <= 0;
            param_data_valid_l <= 0;
        end
    end
    else begin
        param_data_valid <= 0;
        param_data_valid_l <= 0;
    end
end
end

//states and next state

always_ff begin
if(!rst_n)
    curr_state <= IDLE;
else 
    curr_state <=  next_state;
end

//NEXT_state
always_comb begin
case(curr_state)
IDLE:begin 
    if( param_addr_valid )
        next_state = WRITE;
    else if (param_addr_valid_l)
        next_state = READ;
    else
        next_state = IDLE;
end
WRITE: begin
    if( param_data_valid_p & param_data_ready_p )
        if( param_addr_valid_l )
            next_state = READ;
        else
            next_state = IDLE;
    else
        next_state = WRITE;
end
READ: begin
    if( param_data_valid_p & param_data_ready_p )
        if( param_addr_valid )
            next_state = WRITE;
        else
            next_state = IDLE;
    else
        next_state = READ;
end
endcase

end
endmodule