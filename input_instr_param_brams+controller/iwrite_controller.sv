module iwrite_controller_init#(
    parameter STREAM_WIDTH = 128,
    parameter IBRAM_WIDTH = STREAM_WIDTH //WRITE WIDTH OF BRAM, 
    NUM_BANKS = 16,
    IBRAM_DEPTH = (ACTIVATION_BIT * (MAX_OUT_CHANNEL/NUM_BANKS) * MAX_IN_CHANNEL * MAX_KERNEL_SIZE )/IBRAM_WIDTH, //WRITE DEPTH OF BRAM
    MAX_OUT_CHANNEL = 128, 
    MAX_IN_CHANNEL = 45,
    MAX_KERNEL_SIZE = 5, 
    MAX_OUT_SEQ = 160, 
    MAX_NUM_LAYERS = 4,
    PARAM_WIDTH = $clog2(MAX_OUT_CHANNEL) + $clog2(MAX_IN_CHANNEL) + $clog2(MAX_KERNEL_SIZE) + $clog2(MAX_OUT_CHANNEL*MAX_KERNEL_SIZE), 
    ACTIVATION_BIT = 8 
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

    //to instruction buffer 
    output logic [STREAM_WIDTH-1:0]idata_instr,
    output logic idata_instr_valid,
    output logic [$clog2(NUM_BANKS)-1:0]instr_bank_counter, 
    input logic idata_instr_ready, 

    //param_module // data channel 
    output logic [PARAM_WIDTH-1:0]param_data, 
    output logic param_data_valid,
    input logic  param_data_ready,

    //param_module //address channel
    input logic [$clog2(MAX_NUM_LAYERS):0]param_addr, 
    input logic param_addr_valid,
    output logic  param_addr_ready,

    //to IBRAM_controller_rd
    output logic [PARAM_WIDTH-1:0]param_data_rd,  //considering memory double buffering
    output logic param_data_valid_rd, 
    input logic param_data_valid_ready 

);

logic param_received;
logic instr_received;
logic act_receved;
logic [$clog2(NUM_BANKS)-1:0]bank_counter;

typedef enum  logic[2:0] {IDLE, PARAM, INSTR, WRITE  } STATE;
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
    if
end
end



endmodule