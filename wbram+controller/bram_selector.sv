module bram_selector(input logic [$clog2(WBRAM_DEPTH)-1:0]addrA, 
    input logic [STREAM_WIDTH-1:0]diA, 
    input logic enaA, 
    input logic weA, 
    input logic [$clog2(NUM_BANKS)-1:0]bank_counter, 
    input logic ping_pong 

    output logic [$clog2(WBRAM_DEPTH)-1:0]addrA_o, 
    output logic [STREAM_WIDTH-1:0]diA_o, 
    output logic [NUM_BANKS-1:0]enaA_o, 
    output logic [NUM_BANKS-1:0]weA_o 
    );



// a simple decoder cum mux
always_comb begin
    enaA_o = '0;
    weA_o = '0;
    enaA_o[bank_counter] = enaA;
    weA_o[bank_counter] = weA;
    addrA_o = addrA;
    diA_o = diA;

end

endmodule




