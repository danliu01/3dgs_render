`include "exp_fix_point.sv"

module alpha_blend #(
  parameter TILE_SIZE = 16,
  parameter DATA_WIDTH = 32,
  parameter FRAC_BITS = 16,
  parameter MAX_SAMPLES = 32
)(
  input logic clk,
  input logic rst_n,
  
  // Input interface
  input logic in_valid,
  output logic in_ready,
  input logic end_of_tile,
  
  // Input coefficient values
  input logic signed [DATA_WIDTH-1:0] A_in,
  input logic signed [DATA_WIDTH-1:0] B_in,
  input logic signed [DATA_WIDTH-1:0] C_in,
  input logic signed [DATA_WIDTH-1:0] D_in,
  input logic signed [DATA_WIDTH-1:0] opacity,
  input logic signed [DATA_WIDTH-1:0] color,
  
  // Output interface
  output logic out_valid,
  input logic out_ready,
  output logic signed [DATA_WIDTH-1:0] blended_output
);

  localparam INTERNAL_WIDTH = 2 * DATA_WIDTH;
  
  logic stage1_valid, stage2_valid, stage3_valid;
  
  logic signed [INTERNAL_WIDTH-1:0] A_ext, B_ext, C_ext, D_ext;
  logic signed [INTERNAL_WIDTH-1:0] opacity_ext, color_ext;
  logic signed [INTERNAL_WIDTH-1:0] exp_input;
  
  logic signed [INTERNAL_WIDTH-1:0] stage2_exp_result;
  logic signed [INTERNAL_WIDTH-1:0] stage2_opacity;
  logic signed [INTERNAL_WIDTH-1:0] stage2_color;
  
  logic signed [INTERNAL_WIDTH-1:0] alpha;
  logic signed [INTERNAL_WIDTH-1:0] color_contrib;
  logic signed [INTERNAL_WIDTH-1:0] accum_transmittance;
  logic signed [INTERNAL_WIDTH-1:0] accum_color;
  
  logic signed [INTERNAL_WIDTH-1:0] alpha_comb;
  logic signed [INTERNAL_WIDTH-1:0] weighted_color_comb;
  logic signed [INTERNAL_WIDTH-1:0] one_minus_alpha_comb;
  logic signed [INTERNAL_WIDTH-1:0] trans_times_alpha_comb;
  logic signed [INTERNAL_WIDTH-1:0] new_accum_color_comb;
  logic signed [INTERNAL_WIDTH-1:0] new_accum_trans_comb;
  logic signed [DATA_WIDTH-1:0] output_value_comb;
  
  localparam signed [INTERNAL_WIDTH-1:0] ONE = (1 << FRAC_BITS);
  
  logic exp_valid_in;
  logic signed [INTERNAL_WIDTH-1:0] exp_output;
  
  exp_fix_point #(
    .INPUT_WIDTH(INTERNAL_WIDTH),
    .FRAC_BITS(FRAC_BITS),
    .OUTPUT_WIDTH(INTERNAL_WIDTH)
  ) exp_inst (
    .clk(clk),
    .rst_n(rst_n),
    .valid_in(exp_valid_in),
    .x_in(exp_input),
    .valid_out(),
    .exp_out(exp_output)
  );
  
  // Utility functions
  function logic signed [INTERNAL_WIDTH-1:0] extend(
    input logic signed [DATA_WIDTH-1:0] value
  );
    return {{(INTERNAL_WIDTH-DATA_WIDTH){value[DATA_WIDTH-1]}}, value};
  endfunction
  
  function logic signed [INTERNAL_WIDTH-1:0] multiply(
    input logic signed [INTERNAL_WIDTH-1:0] a,
    input logic signed [INTERNAL_WIDTH-1:0] b
  );
    logic signed [2*INTERNAL_WIDTH-1:0] result_temp;
    result_temp = a * b;
    return result_temp[INTERNAL_WIDTH+FRAC_BITS-1:FRAC_BITS]; // Scale back
  endfunction
  
  function logic signed [DATA_WIDTH-1:0] saturate(
    input logic signed [INTERNAL_WIDTH-1:0] value
  );
    logic signed [DATA_WIDTH-1:0] max_pos, max_neg;
    max_pos = {1'b0, {(DATA_WIDTH-1){1'b1}}};  // Maximum positive value
    max_neg = {1'b1, {(DATA_WIDTH-1){1'b0}}};  // Maximum negative value
    
    if (value > extend(max_pos))
      return max_pos;
    else if (value < extend(max_neg))
      return max_neg;
    else
      return value[DATA_WIDTH-1:0];
  endfunction
  
  // Stage 1: Input registration and exponent calculation
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      stage1_valid <= 1'b0;
      A_ext <= '0;
      B_ext <= '0;
      C_ext <= '0;
      D_ext <= '0;
      opacity_ext <= '0;
      color_ext <= '0;
      exp_input <= '0;
      exp_valid_in <= 1'b0;
    end else begin
      // Pipeline control
      if (in_ready && in_valid) begin
        A_ext <= extend(A_in);
        B_ext <= extend(B_in);
        C_ext <= extend(C_in);
        D_ext <= extend(D_in);
        opacity_ext <= extend(opacity);
        color_ext <= extend(color);
        exp_input <= extend(A_in) + extend(B_in) + multiply(extend(C_in), extend(D_in));
        exp_valid_in <= 1'b1;
        stage1_valid <= 1'b1;
      end else begin
        exp_valid_in <= 1'b0;
        if (stage1_valid && in_ready) begin
          stage1_valid <= 1'b0;
        end
      end
    end
  end
  
  // Stage 2: Exponential calculation and preparation
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      stage2_valid <= 1'b0;
      stage2_exp_result <= '0;
      stage2_opacity <= '0;
      stage2_color <= '0;
    end else begin
      if (stage1_valid) begin
        stage2_exp_result <= exp_output;
        stage2_opacity <= opacity_ext;
        stage2_color <= color_ext;
        stage2_valid <= 1'b1;
      end else if (stage2_valid && in_ready) begin
        stage2_valid <= 1'b0;
      end
    end
  end
  
  // Combinational calculations for stage 3
  always_comb begin
    alpha_comb = multiply(stage2_opacity, stage2_exp_result);
    one_minus_alpha_comb = ONE - alpha_comb;
    trans_times_alpha_comb = multiply(accum_transmittance, alpha_comb);
    weighted_color_comb = multiply(trans_times_alpha_comb, stage2_color);
    new_accum_color_comb = accum_color + weighted_color_comb;
    new_accum_trans_comb = multiply(accum_transmittance, one_minus_alpha_comb);
    output_value_comb = saturate(new_accum_color_comb);
  end
  
  // Stage 3: Final blending calculation with accumulation
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      stage3_valid <= 1'b0;
      blended_output <= '0;
      accum_transmittance <= ONE;  // Initialize to 1.0
      accum_color <= '0;
      alpha <= '0;
      color_contrib <= '0;
    end else begin
      if (end_of_tile && in_ready) begin
        accum_transmittance <= ONE;  // Reset to 1.0
        accum_color <= '0;
      end
      if (stage2_valid) begin
        alpha <= alpha_comb;
        color_contrib <= weighted_color_comb;
        accum_color <= new_accum_color_comb;
        accum_transmittance <= new_accum_trans_comb;
        blended_output <= output_value_comb;
        stage3_valid <= 1'b1;
      end else if (stage3_valid && out_ready) begin
        stage3_valid <= 1'b0;
      end
    end
  end
  
  // Output assignments
  assign in_ready = !stage1_valid || (stage1_valid && out_ready);
  assign out_valid = stage3_valid;
  
endmodule
