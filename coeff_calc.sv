module coeff_calc #(
  parameter TILE_SIZE = 16,
  parameter DATA_WIDTH = 32,
  parameter FRAC_BITS = 16
)(
  input logic clk,
  input logic rst_n,
    
  // Input
  input logic                            in_valid,
  output logic                           in_ready,
  input logic                            end_of_tile,
  input logic signed [DATA_WIDTH-1:0]    a,
  input logic signed [DATA_WIDTH-1:0]    b,
  input logic signed [DATA_WIDTH-1:0]    c,
  input logic signed [DATA_WIDTH-1:0]    mu_x,
  input logic signed [DATA_WIDTH-1:0]    mu_y,
  input logic signed [DATA_WIDTH-1:0]    x,
  input logic signed [DATA_WIDTH-1:0]    y,
    
  // Output
  output logic                           out_valid,
  input logic                            out_ready,
  output logic                           end_of_tile_out,
  output logic signed [DATA_WIDTH-1:0]   A_values [0:TILE_SIZE-1],
  output logic signed [DATA_WIDTH-1:0]   B_values [0:TILE_SIZE-1],
  output logic signed [DATA_WIDTH-1:0]   C_values [0:TILE_SIZE-1],
  output logic signed [DATA_WIDTH-1:0]   D_values [0:TILE_SIZE-1]
);

  logic signed [DATA_WIDTH-1:0] a_reg, b_reg, c_reg, mu_x_reg, mu_y_reg, x_reg, y_reg;
  logic input_registered;
  logic out_valid_next;
  logic end_of_tile_reg;
    
  localparam logic signed [DATA_WIDTH-1:0] MINUS_HALF = -(1 << (FRAC_BITS-1));
    
  // Fixed-point multiplier
  function logic signed [DATA_WIDTH-1:0] multiply(
    input logic signed [DATA_WIDTH-1:0] a,
    input logic signed [DATA_WIDTH-1:0] b
  );
    logic signed [2*DATA_WIDTH-1:0] result_temp;
    result_temp = a * b;
    return result_temp[DATA_WIDTH+FRAC_BITS-1:FRAC_BITS]; // Scale back
  endfunction
    
  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      a_reg <= '0;
      b_reg <= '0;
      c_reg <= '0;
      mu_x_reg <= '0;
      mu_y_reg <= '0;
      x_reg <= '0;
      y_reg <= '0;
      input_registered <= 1'b0;
      out_valid <= 1'b0;
      end_of_tile_reg <= 1'b0;
  end else begin
    if (in_valid && in_ready) begin
      a_reg <= a;
      b_reg <= b;
      c_reg <= c;
      mu_x_reg <= x - mu_x;
      mu_y_reg <= y - mu_y;
      input_registered <= 1'b1;
      end_of_tile_reg <= end_of_tile;
    end 
    out_valid <= input_registered && !out_valid;

    if (out_valid && out_ready) begin
      out_valid <= 1'b0;
      input_registered <= 1'b0;
    end
  end
end

    
  // Ready signal generation
  assign in_ready = ~input_registered || (out_valid && out_ready);
  assign end_of_tile_out = end_of_tile_reg;
    
  // Calculate all outputs combinationally
  generate
    for (genvar x_inc = 0; x_inc < TILE_SIZE; x_inc++) begin : x_gen
      logic signed [DATA_WIDTH-1:0] x_diff;
      logic signed [DATA_WIDTH-1:0] x_diff_squared;
      logic signed [DATA_WIDTH-1:0] a_times_x_diff_squared;
            
      // Calculate x differences and coefficients
      assign x_diff = x_inc + mu_x_reg;
      assign x_diff_squared = multiply(x_diff, x_diff);
      assign a_times_x_diff_squared = multiply(a_reg, x_diff_squared);
      assign A_values[x_inc] = multiply(a_times_x_diff_squared, MINUS_HALF);
      assign C_values[x_inc] = multiply(c_reg, x_diff);
    end
        
    for (genvar y_inc = 0; y_inc < TILE_SIZE; y_inc++) begin : y_gen
      logic signed [DATA_WIDTH-1:0] y_diff;
      logic signed [DATA_WIDTH-1:0] y_diff_squared;
      logic signed [DATA_WIDTH-1:0] b_times_y_diff_squared;
            
      // Calculate y differences and coefficients
      assign y_diff = y_inc + mu_y_reg;
      assign y_diff_squared = multiply(y_diff, y_diff);
      assign b_times_y_diff_squared = multiply(b_reg, y_diff_squared);
      assign B_values[y_inc] = multiply(b_times_y_diff_squared, MINUS_HALF);
      assign D_values[y_inc] = y_diff;
    end
  endgenerate
    
endmodule
