// VERSION: 4.1

/*
Design a floating point multiplier.  This are inspired by IEEE 754-2019 (See the SJSU library to download the specification)

The Floating point is 1 bit sign, 5 bits exponent biased at +15 (6'b01111), and 6 bits fraction (with a hidden 1, 7 effective bits)

The multiplier and adder do not generate overflow or underflow, but "saturate" at +/- 11110_110000. Below 00010_000000 are set to true zero.

There is no need for NAN or infinities in the design due to the saturation applied at all steps.

A true Zero is represented by all zero bits in the exponent and fraction. Any other coding of the 12 bits represents a non zero value.

A true Zero is positive (sign bit is zero) when created by the multiplier. (-0 becomes 0)

You can find the test bench in ~morris/272/f25/hw1There is also a header file that shows how the test bench expects the interface.The test generation and checking are encrypted to keep you focused on original design.

*/

// 12 bit floating point multiplier module
//  - 1 sign
//  - 5 exponent
//  - 6 mantissa
`timescale 1ns/10ps

module fpm(input  reg clk,
           input  reg reset,
           input  reg [11:0] A,
           input  reg [11:0] B,
           input  reg pushin,
           output reg pushout,
           output reg [11:0] Z
);

  localparam SATURATIOn = 11'b11110_110000;
  localparam ROUND_TO_ZERo = 11'b00010_000000;

  typedef struct packed{
    logic signbit;
    logic [4:0] exponent;
    logic [5:0] mantissa;
  } fp_12b;

  fp_12b a;
  fp_12b b;

  assign a = A;
  assign b = B;

  // stage 0 - partial multiply part 1
  reg s0_signbit;
  reg [5:0] s0_unnormal_exponent;
  reg [13:0] s0_partial_mantissa; // 7bits * 7bits can be up to 14 bits
  reg s0_pushout;
  reg [13:0] s0_reg_addend4;
  reg [13:0] s0_reg_addend5;
  reg [13:0] s0_reg_addend6;

  logic detect_zero_flag;
  logic signed [6:0] temp_exp;
  wire [6:0] a_mantissa;
  wire [6:0] b_mantissa;
  assign a_mantissa = {1'b1, a.mantissa};
  assign b_mantissa = {1'b1, b.mantissa};
  wire [13:0] addends0;
  wire [13:0] addends1;
  wire [13:0] addends2;
  wire [13:0] addends3;
  wire [13:0] addends4;
  wire [13:0] addends5;
  wire [13:0] addends6;
  logic [13:0] partial_product_part1;

  assign addends0 = (b_mantissa[0] == 1'b1) ? {7'b0000000, a_mantissa} : 0;
  assign addends1 = (b_mantissa[1] == 1'b1) ? {7'b0000000, a_mantissa} << 1 : 0;
  assign addends2 = (b_mantissa[2] == 1'b1) ? {7'b0000000, a_mantissa} << 2 : 0;
  assign addends3 = (b_mantissa[3] == 1'b1) ? {7'b0000000, a_mantissa} << 3 : 0;
  assign addends4 = (b_mantissa[4] == 1'b1) ? {7'b0000000, a_mantissa} << 4 : 0;
  assign addends5 = (b_mantissa[5] == 1'b1) ? {7'b0000000, a_mantissa} << 5 : 0;
  assign addends6 = (b_mantissa[6] == 1'b1) ? {7'b0000000, a_mantissa} << 6 : 0;

  always@(*) begin
    temp_exp = a.exponent + b.exponent - 15;
    if(({a.signbit, a.exponent, a.mantissa} == 0) | ({b.signbit, b.exponent, b.mantissa} == 0)) begin
      detect_zero_flag = 1;
    end
    else if(temp_exp < 0) begin
      detect_zero_flag = 1;
    end
    else begin
      detect_zero_flag = 0;
    end
  end

  always@(*) begin
    partial_product_part1 = addends0 + addends1 + addends2 + addends3;
  end

  always@(posedge clk) begin
    if(reset | !pushin) begin
      s0_signbit <= 0;
      s0_unnormal_exponent <= 0;
      s0_partial_mantissa <= 0;
      s0_pushout <= 0;

      s0_reg_addend4 <= 0;
      s0_reg_addend5 <= 0;
      s0_reg_addend6 <= 0;
    end

    else if(detect_zero_flag) begin
      s0_signbit <= 0;
      s0_unnormal_exponent <= 0;
      s0_partial_mantissa <= 0;
      s0_pushout <= 1;

      s0_reg_addend4 <= 0;
      s0_reg_addend5 <= 0;
      s0_reg_addend6 <= 0;
    end

    else begin
      s0_signbit <= a.signbit ^ b.signbit;
      s0_unnormal_exponent <= a.exponent + b.exponent - 15;
      s0_partial_mantissa <= partial_product_part1;
      s0_pushout <= 1;

      s0_reg_addend4 <= addends4;
      s0_reg_addend5 <= addends5;
      s0_reg_addend6 <= addends6;
    end
  end

  // stage 1 - partial multiply part 2
  reg s1_signbit;
  reg [5:0] s1_unnormal_exponent;
  reg [13:0] s1_unnormal_mantissa; // 7bits * 7bits can be up to 14 bits
  reg s1_pushout;

  logic [13:0] partial_product_part2;
  always@(*) begin
    partial_product_part2 = s0_partial_mantissa + s0_reg_addend4 + s0_reg_addend5 + s0_reg_addend6;
  end
  always@(posedge clk) begin
    if(reset)
    begin
      s1_signbit <= 0;
      s1_unnormal_exponent <= 0;
      s1_unnormal_mantissa <= 0;
      s1_pushout <= 0;
    end

    else 
    begin
      s1_signbit <= s0_signbit;
      s1_unnormal_exponent <= s0_unnormal_exponent;
      s1_unnormal_mantissa <= partial_product_part2;
      s1_pushout <= s0_pushout;
    end
  end

  // stage 2 - normalize
  reg s2_signbit;
  reg [5:0] s2_exponent;
  reg [5:0] s2_mantissa; // mantissa should be 6 bits after normalization
  reg s2_pushout;

  logic [3:0] position_first_one;
  logic [5:0] normal_mantissa;
  logic [13:0] shifted_mantissa;
  logic [5:0] unnormal_exponent;
  logic [5:0] normal_exponent;
  always@(*) begin  // combinational logic to normalize mantissa
    if((s1_unnormal_mantissa == 0) && (s1_unnormal_exponent == 0))begin
      position_first_one = 0;
      normal_mantissa = 0;
      shifted_mantissa = 0;
      unnormal_exponent = 0;
      normal_exponent = 0;
    end

    else begin
      if(s1_unnormal_mantissa[13] == 1) begin
        position_first_one = 13;
      end
      else begin
        position_first_one = 12;
      end  

      normal_mantissa = s1_unnormal_mantissa[position_first_one - 1 -:6];
      shifted_mantissa = 0;

      if({s1_unnormal_exponent, normal_mantissa} > SATURATIOn) begin
        normal_exponent = SATURATIOn[10:6];
        normal_mantissa = SATURATIOn[5:0];
      end

      else begin
        if(position_first_one == 13) begin
          unnormal_exponent = s1_unnormal_exponent + 1;
        end
        else begin
          unnormal_exponent = s1_unnormal_exponent;
        end

        if({unnormal_exponent, normal_mantissa} > SATURATIOn) begin
          normal_exponent = SATURATIOn[10:6];
          normal_mantissa = SATURATIOn[5:0];
        end
        else begin
          normal_exponent = unnormal_exponent[4:0];
        end
      end
    end


  end

  always@(posedge clk) begin
    if(reset | !s1_pushout)
    begin
      s2_signbit <= 0;
      s2_exponent <= 0;
      s2_mantissa <= 0;
      s2_pushout <= 0;
    end

    else begin
      s2_signbit <= s1_signbit;
      s2_exponent <= normal_exponent;
      s2_mantissa <= normal_mantissa;
      s2_pushout <= 1;
    end
  end

  // stage 3 - handle exceptions
  logic result_is_zero;
  
  always@(posedge clk) begin
    if(reset | !s2_pushout)
    begin
      Z <= 0;
      pushout <= 0;
    end

    else if((s2_exponent == 0) & (s2_mantissa == 0)) begin
      Z <= 0;
      pushout <= 1;
    end

    else if({s2_exponent, s2_mantissa} < ROUND_TO_ZERo) begin
      Z <= 0;
      pushout <= 1;
    end

    else begin
      Z[11] <= s2_signbit;
      Z[10:6] <= s2_exponent;
      Z[5:0] <= s2_mantissa;
      pushout <= 1;
    end
  end

endmodule : fpm

