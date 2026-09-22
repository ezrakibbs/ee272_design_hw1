`timescale 1ns / 1ps
module fpm_tb;
  reg clk;
  reg reset;
  reg [11:0] input_1;
  reg [11:0] input_2;
  reg pushin;
  wire pushout;
  wire [11:0] output_1;


  fpm test(
      .clk(clk),
      .reset(reset),
      .A(input_1), 
      .B(input_2),
      .pushin(pushin),
      .pushout(pushout),
      .Z(output_1));
  
  initial begin
    clk = 0;
    reset = 1;
    #15
    reset = 0;
    pushin = 0;
  end

  always #10 clk = ~clk;

  initial begin
    #25
    input_1 = 12'b0_10101_100011; // 99
    input_2 = 12'b1_10101_011001; // -89
    pushin = 1;
    #20
    input_1 = 12'b1_10101_101110; // -110.125
    input_2 = 12'b0_10101_100011; // 99.875
    #20
    input_1 = 12'b0_00000_000000; // 0
    input_2 = 12'b1_10101_100011; // -99
    #20
    input_1 = 12'b0_11111_000000;
    input_2 = 12'b1_10111_100011;
    #20
    input_1 = 12'b0_01111_000000;
    input_2 = 12'b0_01111_000000;
    #20
    input_1 = 12'b0_10000_100000;
    input_2 = 12'b0_10000_100000;
  end

  initial begin
    #200
    $finish();
  end


  


endmodule : fpm_tb

