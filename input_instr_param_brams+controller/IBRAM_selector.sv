module IBRAM_selector(
    
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

    //to ibram_controller_rd
    output logic [NUM_BANKS-1:0][ACT_WIDTH-1:0]doB, 
    input logic [NUM_BANKS-1:0]enaB, 
    input logic [NUM_BANKS-1:0]weB, 
    input logic [NUM_BANKS-1:0][$clog2(ACT_DEPTH)-1:0]addrB
);


logic [NUM_BANKS-1:0][$clog2(WR_ACT_DEPTH)-1:0]wr_addr_counter;  //write address to each Bank(BRAM). 
//logic [NUM_BANKS-1:0]ping_pong; //choose the BRAM to be written/read ( will be used by read and write phases )
logic [NUM_BANKS-1:0][1:0]wr_pointer; // ping pong can be inferred from here 
logic [NUM_BANKS-1:0][1:0]rd_pointer; // ping pong can be inferred from here 

typedef enum  logic[2:0] {IDLE, INIT_WRITE, WRITE  } STATE;
STATE curr_state,next_state;

//bram_xilinx array ( 2 * NUM_BANKS = TOTAL BANKS )
genvar i;
generate
    for(  i =0; i < NUM_BANKS;i++)begin
        bram_xilinx ibx(.clkA(clk), 
                        .clkB(clk), 
                        .enaA(), 
                        .weA(), 
                        .enaB(), 
                        .weB(0), 
                        .addrA(), 
                        .addrB(), 
                        .diA(), 
                        .doA(), 
                        .diB(), 
                        .doB(diB[i]));
    end
endgenerate



always_ff begin
    if( next_state == INIT_WRITE)begin
        wr_addr_counter[i] <= 0;
        enaA_1 <= 1;
        weA_1 <= 1;
    end
    if  ( curr_state == INIT_WRITE)begin
        for( int i=0; i< NUM_BANKS;i++)begin
            if( wr_done1)
                wr_addr_counter[i] <= 0;
            else if(bank_idx_1[i] & enaA_1 & weA_1)
                wr_addr_counter[i] <= wr_addr_counter[i] + 1;
        end
    end
    else if(( curr_state == WRITE)) begin
        for( int i=0; i< NUM_BANKS;i++)begin
            if(bank_idx_2[i] & enaA_2 & !ping_pong)
                wr_addr_counter[i] <= wr_addr_counter[i] + 1;
            if( wr_done1 || wr_done2)
                wr_addr_counter[i] <= 0;
        end
    end
    else begin


    end
end









endmodule
