module pe_mod#(
    PE_ROW_ID = 4,
    PE_COL_ID = 4
)(
    input logic clk, 
    input logic rst_n, 

    //activation interface ( west )
    input logic [ACT_BIT-1:0]actin_w1, 
    input logic [NUM_COLS-1:0]actin_w1_valid,
    output logic actin_w1_ready,

    //activation interface ( west )
    input logic [ACT_BIT-1:0]actin_w2, 
    input logic [NUM_COLS-1:0]actin_w2_valid,
    output logic [NUM_COLS-1:0]actin_w2_ready,
    
    //activation interface ( east )
    output logic [ACT_BIT-1:0]actout_e1, 
    output logic [NUM_COLS-1:0]actout_e1_valid,
    input logic [NUM_COLS-1:0]actout_e1_ready,

    //activation interface ( east )
    output logic [ACT_BIT-1:0]actout_e2, 
    output logic [NUM_COLS-1:0]actout_e2_valid,
    input logic [NUM_COLS-1:0]actout_e2_ready,

    //weight interface ( north )
    input logic [ACCUM_BIT-1:0]win_n, 
    input logic [NUM_ROWS-1:0]win_n_valid,
    output logic [NUM_ROWS-1:0]win_n_ready,

    //weight interface ( south )
    output logic [ACCUM_BIT-1:0]wout_s, 
    output logic [NUM_ROWS-1:0]wout_s_valid,
    input logic [NUM_ROWS-1:0]wout_s_ready,

    //to accum bus 
    output logic [ACCUM_BIT-1:0]accum_out_s, 
    output logic accum_out_s_valid,
    input logic accum_out_s_ready,

    //control stream(west)
    input logic [1:0]change_instr_act_w,
    input logic [NUM_COLS-1:0]change_instr_act_w_valid,
    output logic change_instr_act_w_ready,

    //control stream(east)
    output logic change_instr_act_e,
    output logic [NUM_COLS-1:0]change_instr_act_e_valid,
    input logic change_instr_act_e_ready,


    //instruction stream ( west )
    input logic [INSTR_BIT-1:0]instr_w, 
    input logic [NUM_COLS-1:0]instr_w_valid,
    output logic instr_w_ready, 

    //instruction stream ( east )
    output logic [INSTR_BIT-1:0]instr_e, 
    output logic [NUM_COLS-1:0]instr_e_valid,
    input logic instr_e_ready

);


axi_stream_backpressure_simd#(.VALID_WIDTH(NUM_COLS), .DATA_WIDTH(INSTR_BIT), .PE_ID(PE_COL_ID))
                            instr_bp(.i_data(instr_w), 
                                    .i_data_valid(instr_w_valid), 
                                    .i_data_ready(instr_w_ready), 
                                    .o_data(instr_e), 
                                    .o_data_valid(instr_e_valid), 
                                    .o_data_ready(instr_e_ready),
                                    .full(full_instr_buffer), .*);

axi_stream_backpressure_simd#(.VALID_WIDTH(NUM_COLS), .DATA_WIDTH(ACT_BIT), .PE_ID(PE_COL_ID))
                            act1_bp(.i_data(actin_w1), 
                                    .i_data_valid(actin_w1_valid), 
                                    .i_data_ready(actin_w1_ready), 
                                    .o_data(actout_e1), 
                                    .o_data_valid(actout_e1_valid), 
                                    .o_data_ready(actout_e1_ready),
                                    .full(full_act1_buffer), .*);



axi_stream_backpressure_simd#(.VALID_WIDTH(NUM_COLS), .DATA_WIDTH(ACT_BIT), .PE_ID(PE_COL_ID))
                            act2_bp(.i_data(actin_w2), 
                                    .i_data_valid(actin_w2_valid), 
                                    .i_data_ready(actin_w2_ready), 
                                    .o_data(actout_e2), 
                                    .o_data_valid(actout_e2_valid), 
                                    .o_data_ready(actout_e2_ready),
                                    .full(full_act2_buffer), .*);



axi_stream_backpressure_simd#(.VALID_WIDTH(NUM_ROWS), .DATA_WIDTH(WEIGHT_BIT), .PE_ID(PE_ROW_ID))
                            weight_bp(.i_data(win_n), 
                                    .i_data_valid(win_n_valid), 
                                    .i_data_ready(win_n_ready), 
                                    .o_data(wout_s), 
                                    .o_data_valid(wout_s_valid), 
                                    .o_data_ready(wout_s_ready),
                                    .full(full_weight_buffer), .*);

axi_stream_backpressure_simd#(.VALID_WIDTH(NUM_ROWS), .DATA_WIDTH(WEIGHT_BIT), .PE_ID(PE_ROW_ID))
                            control_bp(.i_data(change_instr_act_w), 
                                    .i_data_valid(change_instr_act_w_valid), 
                                    .i_data_ready(change_instr_act_w_ready), 
                                    .o_data(change_instr_act_e), 
                                    .o_data_valid(change_instr_act_e_valid), 
                                    .o_data_ready(change_instr_act_e_ready),
                                    .full(full_control_buffer), .*);

//instruction buffer,act_buffer1,weight_buffer- 
logic [1:0][INSTR_BIT-1:0]instruction_buffer;
logic [1:0][ACT_BIT-1:0]act_buffer1;
logic [1:0][ACT_BIT-1:0]act_buffer2;
logic [1:0][WEIGHT_BIT-1:0]weight_buffer;
logic [1:0][1:0]control_buffer;
logic [1:0]wr_pointer_instr;
logic [1:0]wr_pointer_act1;
logic [1:0]wr_pointer_act2;
logic [1:0]wr_pointer_weight;
logic [1:0]wr_pointer_change;

always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    instruction_buffer <= 0;
    act_buffer1 <= 0;
    weight_buffer <= 0;
    wr_pointer_instr <= 0;
    act_buffer2 <= 0;
    control_buffer <= 0;
end
else begin
    if( instr_w_valid[PE_ID] & instr_w_ready )begin
        instruction_buffer[wr_pointer_instr[0]] <= instr_w;
        wr_pointer_instr <=  wr_pointer_instr + 1;
    end
    if( actin_w1_valid[PE_ID] & actin_w1_ready )begin
        act_buffer1[wr_pointer_act1[0]] <= actin_w1;
        wr_pointer_act1 <=  wr_pointer_act1 + 1;
    end
    if( actin_w2_valid[PE_ID] & actin_w2_ready )begin
        act_buffer2[wr_pointer_act2[0]] <= actin_w2;
        wr_pointer_act2 <=  wr_pointer_act2 + 1;
    end
    if( win_n_valid[PE_ID] & win_n_ready )begin
        weight_buffer[wr_pointer_weight[0]] <= win_n;
        wr_pointer_weight <=  wr_pointer_weight + 1;
    end
    if( change_instr_act_w_valid[PE_ID] & change_instr_act_w_ready )begin
        control_buffer[wr_pointer_change[0]] <= change_instr_act_w;
        wr_pointer_change <=  wr_pointer_change + 1;
    end
end
end




endmodule