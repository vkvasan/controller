module iread_controller(
    input logic clk, 
    input logic rst_n, 

    //to pe   data channel
    output logic [NUM_BANKS-1:0][ACTIVATION_BIT-1:0]pe_act_data,
    output logic [NUM_BANKS-1:0]pe_act_data_valid,
    input logic [NUM_BANKS-1:0]pe_act_data_ready, 

    //to IBRAM_selector( write address info.)
    input logic [NUM_BANKS-1:0][$clog2(WRITE_DEPTH):0]write_addr_pingpong_data, 
    //output logic [NUM_BANKS-1:0]write_addr_pingpong_valid, 
    //input logic [NUM_BANKS-1:0]write_addr_pingpong_ready, 

    //to IBRAM_selector ( data and address stream ) 
    input logic [NUM_BANKS-1:0][READ_WIDTH-1:0]doB, 
    output logic [NUM_BANKS-1:0]enaB, 
    output logic [NUM_BANKS-1:0]weB, 
    output logic [NUM_BANKS-1:0][$clog2(READ_DEPTH):0]addrB_ping_pong,   

    
    //from iwrite_controller(PARAMS)    data channel
    input logic [PARAM_WIDTH-1:0]param_data_rd,  //considering memory double buffering
    input logic param_data_valid_rd, 
    output logic param_data_ready_rd 


    //to iwrite_controller(PARAMS)    address channel 
    output logic [PARAM_WIDTH-1:0]param_addr_rd,  //considering memory double buffering
    output logic param_addr_valid_rd, 
    input logic param_addr_ready_rd
);


//top pe 

    //to rd_controller_south (WBRAM_active synchronization)  data channel
     logic ird_south_valid, 
     logic ird_south_data, 
     logic ird_south_ready, 

    //to rd_controller_south (PARAMS) data channel
     logic [PARAM_WIDTH-1:0]param_data_rd_s,  //considering memory double buffering
     logic param_data_valid_rd_s, 
     logic param_data_ready_rd_s 

//mid pe 
    
    //from rd_controller_north (WBRAM_active synchronization)  data channel
    input logic ird_north_valid, 
    input logic ird_north_data, 
    output logic ird_north_ready, 

    //to rd_controller_south (WBRAM_active synchronization)  data channel
    output logic ird_south_valid, 
    output logic ird_south_data, 
    input logic ird_south_ready, 

    //to rd_controller_south (PARAMS) data channel
    output logic [PARAM_WIDTH-1:0]param_data_rd_s,  //considering memory double buffering
    output logic param_data_valid_rd_s, 
    input logic param_data_ready_rd_s, 

    //from rd_controller_north(PARAMS)    data channel
    input logic [PARAM_WIDTH-1:0]param_data_rd_n,  //considering memory double buffering
    input logic param_data_valid_rd_n, 
    output logic param_data_ready_rd_n  

//last pe
    //from rd_controller_north (WBRAM_active synchronization)  data channel
    input logic ird_north_valid, 
    input logic ird_north_data, 
    output logic ird_north_ready, 

    //from rd_controller_north(PARAMS)    data channel
    input logic [PARAM_WIDTH-1:0]param_data_rd_n,  //considering memory double buffering
    input logic param_data_valid_rd_n, 
    output logic param_data_ready_rd_n  


logic [NUM_ROWS-1:0]ird_data;
logic [NUM_ROWS-1:0]ird_data_valid;
logic [NUM_ROWS-1:0]ird_data_ready;

logic [NUM_ROWS-1][PARAM_WIDTH-1:0]param_data;
logic [NUM_ROWS-1]param_data_ready;
logic [NUM_ROWS-1]param_data_valid;

genvar i;
generate 
for( i =0; i < NUM_ROWS; i++)begin
    iread_controller_top_pe tpe(
        .ird_south_valid(ird_data_valid[i]), 
     .ird_south_data(ird_data[i]), 
     .ird_south_ready(ird_data_ready[i]), 
     .param_data_rd_s(param_data[i]), 
     .param_data_valid_rd_s(param_data_valid[i]), 
     .param_data_ready_rd_s(param_data_ready[i]),.*
    );
    

    iread_controller_mid_pe mpe(
        .ird_north_valid(ird_data_valid[i]), 
     .ird_north_data(ird_data[i]), 
     .ird_north_ready(ird_data_ready[i]), 
     
     .param_data_rd_n(param_data[i]), 
     .param_data_valid_rd_n(param_data_valid[i]), 
     .param_data_ready_rd_n(param_data_ready[i]),

        .ird_south_valid(ird_data_valid[i+1]), 
     .ird_south_data(ird_data[i+1]), 
     .ird_south_ready(ird_data_ready[i+1]), 
     
     .param_data_rd_s(param_data[i+1]), 
     .param_data_valid_rd_s(param_data_valid[i+1]), 
     .param_data_ready_rd_s(param_data_ready[i+1]),.* );


     iread_controller_last_pe mpe(
        .ird_north_valid(ird_data_valid[i]), 
     .ird_north_data(ird_data[i]), 
     .ird_north_ready(ird_data_ready[i]), 
     
     .param_data_rd_n(param_data[i]), 
     .param_data_valid_rd_n(param_data_valid[i]), 
     .param_data_ready_rd_n(param_data_ready[i]),.* );
    ;
end


endgenerate

endmodule