module fft_ram(
    input clk, rst, load, externalLoad,
    input [9:0] indexA, indexB,
    input  signed [31:0] A_real_i, A_imag_i, B_real_i, B_imag_i,
    output reg signed [31:0] A_real_o, A_imag_o, B_real_o, B_imag_o
);

    genvar i;

    wire signed [31:0] q_imag [0:2048];
    wire signed [31:0] q_real [0:2048];

   assign A_real_o = q_real[2 * indexA];
   assign A_imag_o = q_imag[2 * indexA + 1];
   assign B_real_o = q_real[2 * indexB];
   assign B_imag_o = q_imag[2 * indexB + 1];

    generate
        for (i = 0; i < 1024; i++) begin
            fft_register reg_r(.clk(clk), 
                               .rst(rst), 
                               .d(indexA === i ? A_real_i :
                                  indexB === i ? B_real_i :
                                  32'h00000000), 
                               .q(q_real[2*i]),
                               .en(externalLoad ? indexA === i : 
                                   load && (indexA === i || indexB === i)));
            fft_register reg_i(.clk(clk), 
                               .rst(rst), 
                               .d(indexA === i ? A_imag_i :
                                  indexB === i ? B_imag_i :
                                  32'h00000000), 
                               .q(q_imag[2*i + 1]), 
                               .en(externalLoad ? indexA === i : 
                                   load && (indexA === i || indexB === i)));
        end
    endgenerate

endmodule