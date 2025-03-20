module exp_fix_point #(
  parameter INPUT_WIDTH = 16,    // Total width of input
  parameter FRAC_BITS = 8,       // Fractional bits in fixed-point representation
  parameter OUTPUT_WIDTH = 16    // Total width of output
)(
  input wire clk,                // Clock signal (not used, kept for interface compatibility)
  input wire rst_n,              // Reset signal (not used, kept for interface compatibility)
  input wire valid_in,           // Input valid signal (passed through)
  input wire [INPUT_WIDTH-1:0] x_in,  // Fixed-point input
  output wire valid_out,         // Output valid signal (passed through)
  output wire [OUTPUT_WIDTH-1:0] exp_out  // Fixed-point output
);
  // Constants for polynomial approximation (in fixed-point)
  // exp(r) ≈ 1 + r + (r²/2) + (r³/6)
  // Coefficients are scaled by 2^FRAC_BITS
  localparam COEF_1 = (1 << FRAC_BITS);              // 1
  localparam COEF_2 = (1 << FRAC_BITS);              // 1
  localparam COEF_3 = (1 << (FRAC_BITS-1));          // 1/2
  localparam COEF_4 = ((1 << FRAC_BITS) / 6);        // 1/6
    
  wire signed [INPUT_WIDTH-1:0] int_part;
  wire signed [INPUT_WIDTH-1:0] frac_part;
  wire signed [2*INPUT_WIDTH-1:0] r_squared, r_cubed;
  wire signed [2*INPUT_WIDTH-1:0] term1, term2, term3, term4;
  wire signed [2*INPUT_WIDTH-1:0] poly_result;
  wire [OUTPUT_WIDTH-1:0] scaled_result;
    
  // Range reduction
  assign int_part = x_in >>> FRAC_BITS;
  assign frac_part = x_in & ((1 << FRAC_BITS) - 1);
    
  // Calculate terms
  assign r_squared = (frac_part * frac_part) >>> FRAC_BITS;
  assign r_cubed = ((frac_part * frac_part) >>> FRAC_BITS) * frac_part >>> FRAC_BITS;
    
  // Calculate polynomial terms
  assign term1 = COEF_1;
  assign term2 = COEF_2 * frac_part;
  assign term3 = COEF_3 * r_squared;
  assign term4 = COEF_4 * r_cubed;
    
  // Sum the polynomial terms
  assign poly_result = term1 + (term2 >>> FRAC_BITS) + (term3 >>> FRAC_BITS) + (term4 >>> FRAC_BITS);
    
  // Scale by 2^int_part (combinational implementation)
  assign scaled_result = (int_part >= 0) ? 
                           // Positive exponent: left shift
                           ((int_part < OUTPUT_WIDTH - FRAC_BITS) ? (poly_result << int_part) : {OUTPUT_WIDTH{1'b1}}) : // Saturate if too large
                           // Negative exponent: right shift
                           ((-int_part < FRAC_BITS) ? (poly_result >> (-int_part)) : 0); // Result approaches zero
  
  // Output assignments
  assign valid_out = valid_in;
  assign exp_out = scaled_result;
    
endmodule
