module iread_controller_mid_pe(
    input logic clk, 
    input logic rst_n, 

    //to pe   data channel
    output logic [ACTIVATION_BIT-1:0]pe_act_data,
    output logic pe_act_data_valid,
    input logic pe_act_data_ready, 

    //to IBRAM_selector( write address info.)
    input logic [NUM_BANKS-1:0][$clog2(WRITE_DEPTH):0]write_addr_pingpong_data, 
    //output logic [NUM_BANKS-1:0]write_addr_pingpong_valid, 
    //input logic [NUM_BANKS-1:0]write_addr_pingpong_ready, 

    //to IBRAM selector ( data and address ) 
    input logic [READ_WIDTH-1:0]doB, 
    output logic enaB, 
    output logic weB, 
    output logic [$clog2(READ_DEPTH):0]addrB_ping_pong,   

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

);
    

logic [$clog2(MAX_NUM_LAYERS)-1:0]num_layers;
logic [$clog2(MAX_NUM_LAYERS)-1:0]layer_count;
typedef enum logic[1:0]{ IDLE,NUM_LAYER_READ, PARAM_READ,BRAM_READ}STATE;
STATE curr_state, next_state; 
logic rd_done;
logic ping_pong_rd;
logic act_first_oc_next;


always_comb begin
    empty = (write_addr_pingpong_data[$clog2(WRITE_DEPTH)] == ping_pong_rd) & ((write_addr_pingpong_data[$clog2(WRITE_DEPTH)-1:0] << (STREAM_WIDTH/ACT_WIDTH)) == addrB)?1:0;
end

//outputs -> pe_act_data and pe_act_data_valid
always_ff @(posedge clk or negedge rst_n) begin
if( !rst_n )begin
    pe_act_data <= 0;
    pe_act_data_valid <= 0;
end
begin
    if( enaB_reg )begin   //enaB_reg acts ready to BRAM 
        pe_act_data <= doB;
        pe_act_data_valid <= 1;
    end
    else 
        pe_act_data_valid <= 0;
end
end

always_ff@(posedge clk)
    enaB_reg <=  enaB;

always_comb begin
    weB = 0; //fixing it to just read 
    if( next_state == BRAM_READ )
        enaB = 1;
    else 
        enaB = 0;
end

//outputs -> addrB_ping_pong
always_comb
    addrB_ping_pong = {addrB, ping_pong_rd};


//outputs -> param_data_ready_rd
always_ff@(posedge clk) begin
    if( curr_state == NUM_LAYER_READ || curr_state == PARAM_READ & param_data_ready_rd_s)
        param_data_ready_rd <=  1;
    else 
        param_data_ready_rd <=  0;
end

/* Outputs

//from rd_controller_north (NORTH)    data  
        input logic [PARAM_WIDTH-1:0]param_data_rd_n,  //considering memory double buffering
    input logic param_data_valid_rd_n, 
    output logic param_data_ready_rd_n 


*/
always_ff@(posedge clk or negedge rst_n)begin
if( !rst_n )begin
    param_data_ready_rd_n <= 0;
end
begin
    param_data_ready_rd_n <= 1;
end
end

/* outputs
//from rd_controller_south (WBRAM_active synchronization)  data channel
    input logic ird_north_valid, 
    input logic ird_north_data, 
    output logic ird_north_ready, 

    //to rd_controller_south (WBRAM_active synchronization)  data channel
    output logic ird_south_valid, 
    output logic ird_south_data, 
    input logic ird_south_ready, 
*/
always_ff @(posedge clk or negedge rst_n)begin
if( !rst_n )begin
    ird_north_ready <= 0;
    ird_south_data <= 0;
    ird_south_valid <= 0;
end
else begin
    ird_north_ready <= ird_south_ready;
    if( ird_north_valid & ird_north_ready )begin
        ird_south_valid <= 1;
        ird_south_data <= 1;
    end
    else begin
        ird_south_valid <= 0;
    end
end

end
/*

//to rd_controller_south (PARAMS) data channel
    //to rd_controller_south (PARAMS) data channel
    output logic [PARAM_WIDTH-1:0]param_data_rd_s,  //considering memory double buffering
    output logic param_data_valid_rd_s, 
    input logic param_data_ready_rd_s, 

    //from rd_controller_north(PARAMS)    data channel
    input logic [PARAM_WIDTH-1:0]param_data_rd_n,  //considering memory double buffering
    input logic param_data_valid_rd_n, 
    output logic param_data_ready_rd_n  
*/
always_ff @(posedge clk or negedge rst_n)begin
if( !rst_n )begin
    param_data_rd_s <= 0;
    param_data_valid_rd_s <= 0;
    param_data_ready_rd_n <= 0;
end
begin
    param_data_ready_rd_n <= param_data_ready_rd_s;
    if( param_data_valid_rd_n & param_data_ready_rd_n )begin
        param_data_valid_rd_s <= 1;
        param_data_rd_s <= param_data_rd;
    end
    else 
        param_data_valid_rd_s <= 0;
end

end


//next state
always_comb begin
case(curr_state)
IDLE: if( param_addr_ready_rd ) 
        next_state = NUM_LAYER_READ;
NUM_LAYER_READ: if( param_data_valid_rd  & param_data_ready_rd )
                    next_state = PARAM_READ;
                else 
                    next_state = NUM_LAYER_READ;
PARAM_READ : if( param_data_valid_rd & param_data_ready_rd)   
                    next_state = BRAM_READ;
            else 
                    next_state = PARAM_READ;
BRAM_READ:  if( rd_done & layer_count == num_layer-1  )
                next_state = IDLE;
            else if( rd_done )
                next_state = PARAM_READ;
            else 
                next_state = BRAM_READ;

endcase
end

//logic for rd_done and layer_count( logic for accum_count, accum_total,out_chan_count. out_chan_size pending )
always_ff @(posedge clk) begin
if( !rst_n )begin
    rd_done <= 0;
    layer_count <= 0;
end
else begin
    if( curr_state == BRAM_READ )begin
        rd_done <=  ((out_chan_count == ((out_chan_size + NUM_COLS-1)>> $clog2(NUM_COLS))-1) & ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1)& (accum_count == accum_total - 2)) ? 1 :0 ;  
        layer_count <=  ((out_chan_count == (out_chan_size >> NUM_COLS)-1) & (accum_count == accum_total - 1)) ? (layer_count + 1) :layer_count;
    end
    else if( curr_state == IDLE) begin
        rd_done <= 0;
        layer_count <= 0;
    end
    else
        rd_done <= 0;
end
end


//obtaining the parameters
always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    out_chan_size <= 0;
    accum_total <= 0; 
    act_first_oc_next <= 0;
    num_layer <= 0;
    kernel_size <= 0;
    in_chan_size <= 0;
    in_seq_length <= 0;
end
else begin
    if( param_data_valid_rd & param_data_ready_rd )
        {act_first_oc_next, out_chan_size,accum_total, num_layer, kernel_size, in_chan_size,in_seq_length} <= param_data_rd;
end
end

// ping_pong_rd, accum_count, outchan_count, 
always_ff@(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    ping_pong_rd <= 0;
    accum_count <= 0;
    out_chan_count <= 0;
end
else begin
    if( curr_state == IDLE )begin
        addrB <= 0;
        ping_pong_rd <= 0;
        accum_count <= 0;
        out_chan_count <= 0;
    end
    else if( curr_state == PARAM_READ )begin
        addrB <= 0;
        accum_count <= 0;
        out_chan_count <= 0;
    end
    else if ( curr_state == BRAM_READ)begin
        if( enaB_reg & accum_count == accum_total -1 )begin
            accum_count <= 0;
            if(!act_first_oc_next)begin
                if( act_tile_count != ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count == ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    act_tile_count <= act_tile_count + 1;
                    out_chan_count <=  0;
                    //addrB <= addrB +1 ;
                end
                else if( act_tile_count != ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count != ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    out_chan_count <= out_chan_count + 1;
                    //addrB <= addrB +1 ;
                end
                else if( act_tile_count == ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count == ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    act_tile_count <= 0;
                    out_chan_count <=  0;
                    ping_pong_rd <= !ping_pong_rd;
                    //addrB <= addrB +1 ;
                end 
            end
            else begin
                if( act_tile_count == ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count != ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    act_tile_count <= 0;
                    out_chan_count <=  out_chan_count + 1;
                    //addrB <= addrB +1 ;
                end
                else if( act_tile_count != ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count != ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    act_tile_count <= act_tile_count + 1;
                    //addrB <= addrB +1 ;
                end
                else if( act_tile_count == ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count == ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    act_tile_count <= 0;
                    out_chan_count <=  0;
                    ping_pong_rd <= !ping_pong_rd;
                    //addrB <= addrB +1 ;
                end 
            end
        end
        else begin
            accum_count <= accum_count + 1;
        end
    end
end
end

//addrB
always_ff @(posedge clk or negedge rst_n)begin
if(!rst_n)begin
    addrB <= 0;
    in_channel_tile_count <= 0;
end
else begin
    if( curr_state != BRAM_READ )
        addrB  <= addrB + 1;
    else 
        if( mem_layout_act_first ) begin
            if( rd_done )
                addrB<=0;
            else if( act_tile_count != ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count != ((out_chan_size +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                if(accum_count == accum_total - 1 )begin
                    if( act_first_oc_next )
                        addrB <=  addrB + 1;
                    else 
                        addrB <=  0;
                end
                else 
                    addrB <=  addrB + 1;
            end
            else if( act_tile_count == ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count != ((out_chan_size +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                if(accum_count == accum_total - 1 )begin
                        addrB <=  0;
                end
                else 
                    addrB <=  addrB + 1;
            end
            else if( act_tile_count != ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count == ((out_chan_size +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    addrB <=  addrB + 1;
            end
            else begin
                if( accum_count == accum_total - 1)
                    addrB <=  0;
                else 
                    addrB <=  addrB + 1;
            end
        end 
        else begin
            if( rd_done )
                addrB<=0;
            else if( act_tile_count != ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count != ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                if( accum_count == accum_total -1)begin
                    if(act_first_oc_next)
                        addrB <=  addrB +1 ;
                    else
                        addrB <=  addrB - accum_total + 1 ; 
                end
                else if(accum_count[$clog2(NUM_COLS)-1:0] == NUM_COLS-1   )begin
                        
                        if( in_channel_tile_count == in_chan_size>>$clog2(NUM_COLS) -1  )begin
                            addrB <=  addrB - (in_channel_tile_count+1)<<$clog2(NUM_COLS) + 1;
                        end
                        else begin
                            addrB <=  addrB + (kernel_size+1)<<$clog2(NUM_COLS);
                            in_channel_tile_count <= in_channel_tile_count + 1;
                        end
                    
                end
                else 
                    addrB <=  addrB + 1;
            end
            else if( act_tile_count == ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count != ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                if( accum_count == accum_total -1)begin
                        addrB <=  0 ;        
                        in_channel_tile_count <= 0;            
                end
                else if(accum_count[$clog2(NUM_COLS)-1:0] == NUM_COLS-1   )begin
                        
                        if( in_channel_tile_count == in_chan_size>>$clog2(NUM_COLS) -1  )begin
                            addrB <=  addrB - (in_channel_tile_count+1)<<$clog2(NUM_COLS) + 1;
                        end
                        else begin
                            addrB <=  addrB + (kernel_size+1)<<$clog2(NUM_COLS);
                            in_channel_tile_count <= in_channel_tile_count + 1;
                        end
                    
                end
                else 
                    addrB <=  addrB + 1;
            end
            else if( act_tile_count != ((in_seq_length +NUM_BANKS-1) >> $clog2(NUM_BANKS) -1) & out_chan_count == ((out_chan_count +NUM_COLS-1) >> $clog2(NUM_COLS) -1))begin
                    if(accum_count[$clog2(NUM_COLS)-1:0] == NUM_COLS-1   )begin
                        
                        if( in_channel_tile_count == in_chan_size>>$clog2(NUM_COLS) -1  )begin
                            addrB <=  addrB - (in_channel_tile_count+1)<<$clog2(NUM_COLS) + 1;
                        end
                        else begin
                            addrB <=  addrB + (kernel_size+1)<<$clog2(NUM_COLS);
                            in_channel_tile_count <= in_channel_tile_count + 1;
                        end
                    
                     end
                     else 
                        addrB <=  addrB + 1;
            end
            else begin
                if( accum_count == accum_total - 1)
                    addrB <=  0;
                else if(accum_count[$clog2(NUM_COLS)-1:0] == NUM_COLS-1   )begin
                        
                        if( in_channel_tile_count == in_chan_size>>$clog2(NUM_COLS) -1  )begin
                            addrB <=  addrB - (in_channel_tile_count+1)<<$clog2(NUM_COLS) + 1;
                        end
                        else begin
                            addrB <=  addrB + (kernel_size+1)<<$clog2(NUM_COLS);
                            in_channel_tile_count <= in_channel_tile_count + 1;
                        end
                    
                     end
                else 
                    addrB <=  addrB + 1;
            end


        end

end

end

endmodule