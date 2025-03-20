`include "coeff_calc.sv"
`include "alpha_blend.sv"

module gaussian_splatting_engine #(
  parameter INPUT_WIDTH = 32,
  parameter OUTPUT_WIDTH = 32,
  parameter FRAC_BITS = 16,
  parameter COLOR_WIDTH = 32,
  parameter OPAC_WIDTH = 32,
  parameter TILE_SIZE = 16,
  parameter MAX_SAMPLES = 32 
)(
  input logic clk,
  input logic rst_n,
  
  // Input interface with valid-ready handshake
  input logic in_valid,
  output logic in_ready,
  input logic end_of_tile,
  
  // Coordinate inputs
  input logic [INPUT_WIDTH-1:0] a,
  input logic [INPUT_WIDTH-1:0] b,
  input logic [INPUT_WIDTH-1:0] c,
  input logic [INPUT_WIDTH-1:0] x,
  input logic [INPUT_WIDTH-1:0] y,
  input logic [INPUT_WIDTH-1:0] mu_x,
  input logic [INPUT_WIDTH-1:0] mu_y,
  
  // Color and opacity
  input logic [COLOR_WIDTH-1:0] color,
  input logic [OPAC_WIDTH-1:0] opacity,
  
  // Output interface with valid-ready handshake
  output logic out_valid,
  input logic out_ready,
  output logic [OUTPUT_WIDTH-1:0] pixel_out [0:TILE_SIZE-1][0:TILE_SIZE-1]
);
  
  logic signed [INPUT_WIDTH-1:0] coef_A [0:TILE_SIZE-1];
  logic signed [INPUT_WIDTH-1:0] coef_B [0:TILE_SIZE-1];
  logic signed [INPUT_WIDTH-1:0] coef_C [0:TILE_SIZE-1];
  logic signed [INPUT_WIDTH-1:0] coef_D [0:TILE_SIZE-1];
  logic coef_calc_out_valid;
  logic coef_calc_out_ready;
  logic end_of_tile_out;
  
  logic [TILE_SIZE*TILE_SIZE-1:0] pixel_out_valid_bits;
  logic [TILE_SIZE*TILE_SIZE-1:0] alpha_blend_ready;
  
  // Coefficient calculator
  coeff_calc #(
    .TILE_SIZE(TILE_SIZE),
    .DATA_WIDTH(INPUT_WIDTH),
    .FRAC_BITS(FRAC_BITS)
  ) coef_calc (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .end_of_tile(end_of_tile),
    .a(a),
    .b(b),
    .c(c),
    .mu_x(mu_x),
    .mu_y(mu_y),
    .x(x),
    .y(y),
    .out_valid(coef_calc_out_valid),
    .out_ready(coef_calc_out_ready),
    .end_of_tile_out(end_of_tile_out),
    .A_values(coef_A),
    .B_values(coef_B),
    .C_values(coef_C),
    .D_values(coef_D)
  );
  
  // Generate alpha blending units for each tile position
  genvar i, j;
  generate
    for (i = 0; i < TILE_SIZE; i = i + 1) begin : row_loop
      for (j = 0; j < TILE_SIZE; j = j + 1) begin : col_loop
        alpha_blend #(
          .DATA_WIDTH(INPUT_WIDTH),
          .TILE_SIZE(TILE_SIZE),
          .FRAC_BITS(FRAC_BITS),
          .MAX_SAMPLES(MAX_SAMPLES)
        ) alpha_blend (
          .clk(clk),
          .rst_n(rst_n),
          .in_valid(coef_calc_out_valid),
          .in_ready(alpha_blend_ready[i*TILE_SIZE + j]),
          .end_of_tile(end_of_tile_out),
          .A_in(coef_A[i]),
          .B_in(coef_B[j]),
          .C_in(coef_C[i]),
          .D_in(coef_D[j]),
          .opacity(opacity),
          .color(color),
          .out_valid(pixel_out_valid_bits[i*TILE_SIZE + j]),
          .out_ready(out_ready),
          .blended_output(pixel_out[i][j])
        );
      end
    end
  endgenerate
  
  // Coefficient calculator is ready when all alpha blending modules are ready
  assign coef_calc_out_ready = &alpha_blend_ready;
  
  // Top-level output is valid when all alpha blending outputs are valid
  assign out_valid = &pixel_out_valid_bits;
  
endmodule
