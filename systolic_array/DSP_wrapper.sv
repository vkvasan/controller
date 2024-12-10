(* use_dsp = "yes" *)
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/09/2024 07:38:00 PM
// Design Name: 
// Module Name: DSP_block
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

// DSP48E2: 48-bit Multi-Functional Arithmetic Block
//          UltraScale
// Xilinx HDL Language Template, version 2021.1

module DSP_block #(
    parameter ACT_BIT = 8,         // Bit-width for MAC activation input
    parameter WEIGHT_BIT = 8,      // Bit-width for MAC weight input
    parameter ACCUM_BIT = 32       // Bit-width for MAC accumulator
)(
    input  logic clk,
    input  logic rst_n,
    input  logic mode,               // Mode: 0 = addition, 1 = MAC
    input  logic [47:0] a,           // Input A for addition (48 bits)
    input  logic [47:0] b,           // Input B for addition (48 bits)
    input  logic [ACT_BIT-1:0] in1,  // Activation input for MAC
    input  logic [WEIGHT_BIT-1:0] in2, // Weight input for MAC
    input  logic [ACCUM_BIT-1:0] c,  // Accumulator input for MAC
    output logic [ACCUM_BIT-1:0] mac_out, // MAC operation result
    output logic [47:0] add_out      // Addition operation result
);

    // DSP block signals
    logic [29:0] dsp_a;         // A input to DSP
    logic [17:0] dsp_b;         // B input to DSP
    logic [47:0] dsp_c;         // C input to DSP
    logic [26:0] dsp_d;         // D input to DSP
    logic [8:0] opmode;         // Operation mode
    logic [4:0] inmode;         // Input mode
    logic [47:0] dsp_p;         // DSP output

    always_comb begin
        if (mode == 0) begin
            // Addition mode: a + b
            dsp_a = a[47:18];           // Upper 30 bits of `a`
            dsp_b = a[17:0];            // Lower 18 bits of `a`
            dsp_c = b;                  // Full 48 bits of `b`
            dsp_d = 27'b0;              // Zero to bypass multiplier
            opmode = 9'b000011111;      // Add A + B + C
            inmode = 5'b00000;          // Direct input
        end else begin
            // MAC mode: in1 * in2 + c
            dsp_a = {{(30-ACT_BIT){1'b0}}, in1}; // Zero-extend `in1` to 30 bits
            dsp_b = {{(18-WEIGHT_BIT){1'b0}}, in2}; // Zero-extend `in2` to 18 bits
            dsp_c = {{(48-ACCUM_BIT){1'b0}}, c};    // Zero-extend `c` to 48 bits
            dsp_d = 27'b0;              // Zero to bypass D input
            opmode = 9'b000110101;      // Multiply A * B + C
            inmode = 5'b00000;          // Direct input
        end
    end

    // DSP block instantiation
    DSP48E2 #(
        .AMULTSEL("A"),
        .A_INPUT("DIRECT"),
        .BMULTSEL("B"),
        .B_INPUT("DIRECT"),
        .USE_MULT("MULTIPLY"),
        .USE_SIMD("ONE48"),
        .USE_WIDEXOR("FALSE")
    ) DSP_inst (
        .CLK(clk),
        .A(dsp_a),
        .B(dsp_b),
        .C(dsp_c),
        .D(dsp_d),
        .OPMODE(opmode),
        .INMODE(inmode),
        .P(dsp_p)
    );

    // Assign output based on mode
    assign add_out = (mode == 0) ? dsp_p : 48'b0;           // Addition result (48 bits)
    assign mac_out = (mode == 1) ? dsp_p[ACCUM_BIT-1:0] : 0; // MAC result (truncated to ACCUM_BIT)

endmodule

