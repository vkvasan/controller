module pe#(
    PE_ID = 4
)(
    input logic clk, 
    input logic rst_n, 

    //activation interface ( west )
    input logic [ACT_BIT-1:0]actin_w, 
    input logic [NUM_COLS-1:0]actin_w_valid,
    output logic actin_w_ready,

    //activation interface ( east )
    output logic [ACT_BIT-1:0]actout_e, 
    output logic [NUM_COLS-1:0]actout_e_valid,
    input logic actout_e_ready,

    //weight interface ( north )
    input logic [ACCUM_BIT-1:0]win_n, 
    input logic [NUM_ROWS-1:0]win_n_valid,
    output logic win_n_ready,

    //weight interface ( south )
    output logic [ACCUM_BIT-1:0]wout_s, 
    output logic [NUM_ROWS-1:0]wout_s_valid,
    input logic wout_s_ready,

    //to accum bus 
    output logic [ACCUM_BIT-1:0]accum_out_s, 
    output logic accum_out_s_valid,
    input logic accum_out_s_ready,

    //control stream(west)
    input logic change_w_instr,
    input logic [NUM_COLS-1:0]change_instr_w_valid,
    output logic change_instr_w_ready,

    //control stream(east)
    output logic change_e_instr,
    output logic [NUM_COLS-1:0]change_instr_e_valid,
    input logic change_instr_e_ready,


    //instruction stream ( west )
    input logic [INSTR_BIT-1:0]instr_w, 
    input logic [NUM_COLS-1:0]instr_w_valid,
    output logic instr_w_ready, 

    //instruction stream ( east )
    output logic [INSTR_BIT-1:0]instr_e, 
    output logic [NUM_COLS-1:0]instr_e_valid,
    input logic instr_e_ready

);

typedef enum logic[1:0]{IDLE, DECODE, EXECUTE }STATE;
STATE curr_state,next_state;

typedef enum logic[1:0]{COMPARE_STORE, MAC_REDUCE_SOUTH_BROADCAST, REDUCE_OFFSET_SEND }Instructions;
Instructions instr;

logic [31:0]accum; 
logic full_instr;
logic empty_instr;
logic [1:0]wr_pointer;
logic [1:0]rd_pointer;
/*

    //instruction stream ( west )
    input logic [INSTR_BIT-1:0]instr_w, 
    input logic [NUM_COLS-1:0]instr_w_valid,
    output logic instr_w_ready, 

    //instruction stream ( east )
    output logic [INSTR_BIT-1:0]instr_e, 
    output logic [NUM_COLS-1:0]instr_e_valid,
    input logic instr_e_ready,
*/


always_comb begin
    full_instr = ((wr_pointer[1] != rd_pointer[1]) & (wr_pointer[0] != rd_pointer[0]))?1:0;
    empty_instr =(wr_pointer == rd_pointer) ? 1:0;
end

always_ff@(posedge clk or negedge rst_n) begin
if(!rst_n)begin
    instr_w_ready<= 1;
    instr_e <= 0;
    instr_e_valid <= 0;
    wr_pointer <= 0;
end
else begin

    if( full_instr ) begin
        instr_w_ready <= 0;
    end
    else 
        instr_w_ready <= instr_e_ready;

    if( instr_w_ready )begin
        instr_e <= instr_w;
        instr_e_valid <= instr_w_valid;
    end 
    else 
        instr_e_valid <= 0;

    if( instr_w_ready & instr_w_valid[i])begin
        instr[wr_pointer[0]] <= instr_w;
        wr_pointer <= wr_pointer + 1;
    end

end
end
/*
    //control stream(west)
    input logic change_w_instr,
    input logic [NUM_COLS-1:0]change_instr_w_valid,
    output logic change_instr_w_ready,

    //control stream(east)
    output logic change_e_instr,
    output logic [NUM_COLS-1:0]change_instr_e_valid,
    input logic change_instr_e_ready,

*/

always_ff@(posedge clk or negedge rst_n) begin
if(!rst_n)begin
    change_instr_w_ready<= 1;
    change_e_instr <= 0;
    change_instr_e_valid <= 0;
    //rd_pointer <= 0;
end
else begin

    if( empty_instr )
        change_instr_w_ready <= 0;
    else 
        change_instr_w_ready <= change_instr_e_ready;

    if(  change_instr_w_ready )begin
        change_e_instr <= change_w_instr;
        change_instr_e_valid <= change_instr_w_valid;
        //if(change_instr_w_valid[PE_ID])
        //    rd_pointer <= rd_pointer + 1;
    end
    else 
        change_instr_e_valid <= 0;
     
end
end



//rd_pointer
always_ff@(posedge clk or negedge rst_n)begin
if( !rst_n )begin
    rd_pointer <=  0;
end
else begin
case(curr_state)
IDLE : begin
        if( next_state == DECODE)begin
            rd_pointer <= 0;
        end
    end
EXECUTE: begin
            if( next_state == DECODE)begin
                rd_pointer <= rd_pointer + 1;
            end
        end

endcase
end
end

//
always_ff@(posedge clk or negedge rst_n)begin
if( !rst_n )begin
    rd_pointer <=  0;
end
else begin
case(curr_state)
IDLE : begin
        if( next_state == DECODE)begin
            rd_pointer <= 0;
        end
    end
DECODE: begin
        if( !empty_instr)begin
            op_code <= instr[rd_pointer[0]]
        end
        end
EXECUTE: begin
            if( next_state == DECODE)begin
                rd_pointer <= rd_pointer + 1;
            end
        end

endcase
end
end


endmodule 