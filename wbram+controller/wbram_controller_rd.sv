module wbram_controller_rd#(
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
    output logic [NUM_BANKS-1:0][$clog2(WBRAM_DEPTH)-1:0]addrB, 
    input  logic [NUM_BANKS-1:0][STREAM_WIDTH-1:0]diB, 
    //input logic [NUM_BANKS-1:0]diB_valid,
    output logic [NUM_BANKS-1:0]enaB, 
    output logic [NUM_BANKS-1:0]weB, 

        
    //from wbram_controller_wr ( wr--------1st PE )
    input logic [1:0]wr_pointer_data_l,  //considering memory double buffering
    input logic wr_pointer_valid_l, 
    output logic wr_pointer_ready_l, 

    //to wbram_controller_wr ( pe (end) ---------> wr_controller ) //POINTER
    output logic [1:0]rd_pointer_data_r,  
    output logic rd_pointer_valid_r, 
    input logic rd_pointer_ready_r, 

    
    //to systolic array
    output logic[NUM_BANKS-1:0][WEIGHT_BIT-1:0]w_sys_data;
    output logic [NUM_BANKS-1:0]w_sys_valid, 
    input logic [NUM_BANKS-1:0]w_sys_ready, 


    //from param_module, // data channel 
    input logic [PARAM_WIDTH-1:0]param_data_l, 
    input logic param_data_valid_l,
    output logic  param_data_ready_l

    //to param_module, ( address channel )
    output logic [$clog2(MAX_NUM_LAYERS):0]param_addr_l, 
    output logic param_addr_valid_l,
    input logic  param_addr_ready_l
);


logic [NUM_BANKS-2:0][1:0]wr_pointer_data; 
logic [NUM_BANKS-2:0]wr_pointer_valid; 
logic [NUM_BANKS-2:0]wr_pointer_ready; 
logic [NUM_BANKS-2:0][1:0]param_data; 
logic [NUM_BANKS-2:0]param_data_valid; 
logic [NUM_BANKS-2:0]param_data_ready; 
logic [NUM_BANKS-2:0]start; 


wbram_controller_rd_leftpe #(.STREAM_WIDTH(STREAM_WIDTH), 
.NUM_BANKS(NUM_BANKS), 
.MAX_OUT_CHANNEL(MAX_OUT_CHANNEL), 
.MAX_IN_CHANNEL(MAX_IN_CHANNEL),
.MAX_KERNEL_SIZE(MAX_KERNEL_SIZE),
.MAX_OUT_SEQ(MAX_OUT_SEQ), 
.MAX_NUM_LAYERS(MAX_NUM_LAYERS),
.WEIGHT_BIT(WEIGHT_BIT)
) lpe(.w_sys_data(w_sys_data[0]),.w_sys_valid(w_sys_valid[0]),.w_sys_ready(w_sys_ready[0]),.addrB(addrB[0]),.diB(diB[0]), .enaB(enaB[0]), .weB(weB[0]) , 
        .wr_pointer_data_r(wr_pointer_data[0]),.wr_pointer_valid_r(wr_pointer_valid[0]), .wr_pointer_ready_r(wr_pointer_ready[0]), 
        .param_data_r(param_data[0]),.param_data_valid_r(param_data_valid[0]), .param_data_ready_r(param_data_ready[0]),.start(start[0]), .*  );
generate
    
for( int i =1; i < NUM_BANKS-1; i++)begin
wbram_controller_rd_midpe #(.STREAM_WIDTH(STREAM_WIDTH), 
.NUM_BANKS(NUM_BANKS), 
.MAX_OUT_CHANNEL(MAX_OUT_CHANNEL), 
.MAX_IN_CHANNEL(MAX_IN_CHANNEL),
.MAX_KERNEL_SIZE(MAX_KERNEL_SIZE),
.MAX_OUT_SEQ(MAX_OUT_SEQ), 
.MAX_NUM_LAYERS(MAX_NUM_LAYERS),
.WEIGHT_BIT(WEIGHT_BIT)
) mpe(.w_sys_data(w_sys_data[i]),.w_sys_valid(w_sys_valid[i]),.w_sys_ready(w_sys_ready[i]),.addrB(addrB[i]),.diB(diB[i]), .enaB(enaB[i]), .weB(weB[i]), 
 .wr_pointer_data_l(wr_pointer_data[i-1]),.wr_pointer_valid_l(wr_pointer_valid[i-1]), .wr_pointer_ready_l(wr_pointer_ready[i-1]), 
        .wr_pointer_data_r(wr_pointer_data[i]),.wr_pointer_valid_r(wr_pointer_valid[i]), .wr_pointer_ready_r(wr_pointer_ready[i]), 
        .param_data_r(param_data[i]),.param_data_valid_r(param_data_valid[i]), .param_data_ready_r(param_data_ready[i]),.start_o(start[i]), 
        .param_data_l(param_data[i-1]),.param_data_valid_l(param_data_valid[i-1]), .param_data_ready_l(param_data_ready[i-1]),.start_i(start[i-1]),.*  );
end
endgenerate


wbram_controller_rd_rightpe #(.STREAM_WIDTH(STREAM_WIDTH), 
.NUM_BANKS(NUM_BANKS), 
.MAX_OUT_CHANNEL(MAX_OUT_CHANNEL), 
.MAX_IN_CHANNEL(MAX_IN_CHANNEL),
.MAX_KERNEL_SIZE(MAX_KERNEL_SIZE),
.MAX_OUT_SEQ(MAX_OUT_SEQ), 
.MAX_NUM_LAYERS(MAX_NUM_LAYERS),
.WEIGHT_BIT(WEIGHT_BIT)
) rpe(.w_sys_data(w_sys_data[NUM_BANKS-1]),.w_sys_valid(w_sys_valid[NUM_BANKS-1]),.w_sys_ready(w_sys_ready[NUM_BANKS-1]),.addrB(addrB[NUM_BANKS-1]),.diB(diB[NUM_BANKS-1]), .enaB(enaB[NUM_BANKS-1]), .weB(weB[NUM_BANKS-1]), 
 .wr_pointer_data_l(wr_pointer_data[NUM_BANKS-2]),.wr_pointer_valid_l(wr_pointer_valid[NUM_BANKS-2]), .wr_pointer_ready_l(wr_pointer_ready[NUM_BANKS-2]), 
        .param_data_l(param_data[NUM_BANKS-2]),.param_data_valid_l(param_data_valid[NUM_BANKS-2]), .param_data_ready_l(param_data_ready[NUM_BANKS-2]),.start_i(start[NUM_BANKS-2]),.*  );



endmodule