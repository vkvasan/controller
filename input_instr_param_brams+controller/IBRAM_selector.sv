module IBRAM_selector#(
    parameter NUM_BANKS = 16, 
    parameter WRITE_WIDTH = 128, 
    parameter WRITE_DEPTH = 128,
    parameter READ_WIDTH = 8,
    parameter READ_DEPTH = WRITE_WIDTH* WRITE_DEPTH/ READ_WIDTH 
)
(
    
    input logic clk,
    input logic rst_n, 

    //from iwrite controller 1
    input logic [STREAM_WIDTH-1:0]diA_1, //act_data
    input logic enaA_1, 
    input logic weA_1, 
    input logic [NUM_BANKS-1:0]bank_idx_1,
    input logic wr_done1,

     //from iwrite controller 2
    input logic [NUM_BANKS-1:0][ACT_WIDTH-1:0]diA_2, //act_data
    input logic [NUM_BANKS-1:0]enaA_2, 
    input logic [NUM_BANKS-1:0]weA_2, 
    input logic [NUM_BANKS-1:0]bank_idx_2,
    input logic wr_done2,

    //to ibram_controller_rd ( write address info.)
    output logic [NUM_BANKS-1:0][$clog2(WRITE_DEPTH):0]write_addr_pingpong_data, 
    //output logic [NUM_BANKS-1:0]write_addr_pingpong_valid, 
    //input logic [NUM_BANKS-1:0]write_addr_pingpong_ready, 

    //to ibram_controller_rd ( data stream )
    output logic [NUM_BANKS-1:0][READ_WIDTH-1:0]doB, 
    input logic [NUM_BANKS-1:0]enaB, 
    input logic [NUM_BANKS-1:0]weB, 
    input logic [NUM_BANKS-1:0][$clog2(READ_DEPTH):0]addrB_ping_pong
);


logic [NUM_BANKS-1:0][$clog2(WRITE_DEPTH)-1:0]wr_addr_counter;  //write address to each Bank(BRAM).  //it's comb
logic [NUM_BANKS-1:0]ping_pong;
typedef enum  logic[1:0] {IDLE, INIT_WRITE, WRITE  } STATE;
STATE curr_state,next_state;

//bram_xilinx array ( 2 * NUM_BANKS = TOTAL BANKS )
genvar i;
generate
    for(  i =0; i < NUM_BANKS;i++)begin
        bram_xilinx ibx(.clkA(clk), 
                        .clkB(clk), 
                        .enaA(!ping_pong[i] & ((curr_state == WRITE) ? enaA_2[i]:(enaA_1 & bank_idx_1[i]) ) ), 
                        .weA(!ping_pong[i] & ((curr_state == WRITE) ? weA_2[i]:(weA_1 & bank_idx_1[i]))), 
                        .enaB(enaB & !addrB_ping_pong[i][READ_DEPTH]), 
                        .weB(weB & !addrB_ping_pong[i][READ_DEPTH] ), 
                        .addrA(wr_addr_counter[i]), 
                        .addrB(addrB_ping_pong[i][$clog2(READ_DEPTH) -1 :0]), 
                        .diA((curr_state == WRITE) ? diA_2[i]: diA_1), 
                        .doA(),  //not used 
                        .diB(),  //not used 
                        .doB(doB_ping[i]));
        bram_xilinx ibx(.clkA(clk), 
                        .clkB(clk), 
                        .enaA( ping_pong[i] & ((curr_state == WRITE) ? enaA_2[i]:(enaA_1 & bank_idx_1[i]) )), 
                        .weA(ping_pong[i] & ((curr_state == WRITE) ? weA_2[i]:(weA_1 & bank_idx_1[i]) )), 
                        .enaB(enaB & addrB_ping_pong[i][READ_DEPTH]), 
                        .weB(weB & addrB_ping_pong[i][READ_DEPTH]), 
                        .addrA(wr_addr_counter[i]), 
                        .addrB(addrB_ping_pong[i][$clog2(READ_DEPTH) -1 :0]), 
                        .diA((curr_state == WRITE) ? diA_2[i]: diA_1[i] ), 
                        .doA(),  //not used 
                        .diB(),  //not used 
                        .doB(doB_pong[i]));

        assign dob[i] = !addrB_ping_pong[i][READ_DEPTH] ? doB_ping[i] ? doB_pong[i];
    end
endgenerate

always_ff begin
    write_addr_pingpong_data = {wr_addr_counter, ping_pong};
end

//update write address counter, 
always_ff @(posedge clk or negedgr rst_n)begin
    if( next_state == INIT_WRITE)begin
        wr_addr_counter[i] <= 0;
    end
    if  ( curr_state == INIT_WRITE)begin
        for( int i=0; i< NUM_BANKS;i++)begin
            if( next_state == IDLE)
                wr_addr_counter[i] <= 0;
            else if(bank_idx_1[i] & enaA_1 & weA_1 &!ping_pong[i])
                wr_addr_counter[i] <= wr_addr_counter[i] + 1;
        end
    end
    if(( curr_state == WRITE)) begin
        for( int i=0; i< NUM_BANKS;i++)begin
            if(bank_idx_2[i] & enaA_2 & weA_2 & ping_pong[i])
                wr_addr_counter[i] <= wr_addr_counter[i] + 1;
            if( wr_done2[i])
                wr_addr_counter[i] <= 0;
        end
    end
end

always_ff @(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    ping_pong <= 0;
end
else begin
    if( curr_state == INIT_WRITE)
        if(wr_done1)begin
            for( int i = 0; i < NUM_BANKS;i++)begin
                ping_pong[i]  <=  !ping_pong[i];
            end
        end
    else if (curr_state == WRITE)begin
        for( int i = 0; i < NUM_BANKS;i++)begin
            if( wr_done2[NUM_BANKS-1] )
                ping_pong[i]  <=  !ping_pong[i];
        end

    end
end

end

always_comb begin
case(curr_state)
IDLE: begin
        if( enaA_1 & weA_1 )
            next_state = INIT_WRITE;
        if( enaA_2[i] & weA_2[i] )
            next_state = WRITE;
      end
INIT_WRITE : if( wr_done1 ) 
                next_state =  IDLE;
WRITE: if( wr_done2[NUM_BANKS-1] ) 
            next_state =  IDLE;

    


endcase

end





endmodule
