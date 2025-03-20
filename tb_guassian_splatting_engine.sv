module tb_gaussian_splatting_engine;

  // Testbench Parameters
  parameter INPUT_WIDTH = 32;
  parameter OUTPUT_WIDTH = 32;
  parameter FRAC_BITS = 16;
  parameter COLOR_WIDTH = 32;
  parameter OPAC_WIDTH = 32;
  parameter TILE_SIZE = 16;
  parameter MAX_SAMPLES = 32;

  reg clk;
  reg rst_n;
  
  reg in_valid;
  wire in_ready;
  reg end_of_tile;
  
  reg [INPUT_WIDTH-1:0] a;
  reg [INPUT_WIDTH-1:0] b;
  reg [INPUT_WIDTH-1:0] c;
  reg [INPUT_WIDTH-1:0] x;
  reg [INPUT_WIDTH-1:0] y;
  reg [INPUT_WIDTH-1:0] mu_x;
  reg [INPUT_WIDTH-1:0] mu_y;
  reg [COLOR_WIDTH-1:0] color;
  reg [OPAC_WIDTH-1:0] opacity;
  
  wire out_valid;
  reg out_ready;
  wire [OUTPUT_WIDTH-1:0] pixel_out [0:TILE_SIZE-1][0:TILE_SIZE-1];

  // DUT
  gaussian_splatting_engine #(
    .INPUT_WIDTH(INPUT_WIDTH),
    .OUTPUT_WIDTH(OUTPUT_WIDTH),
    .FRAC_BITS(FRAC_BITS),
    .COLOR_WIDTH(COLOR_WIDTH),
    .OPAC_WIDTH(OPAC_WIDTH),
    .TILE_SIZE(TILE_SIZE),
    .MAX_SAMPLES(MAX_SAMPLES)
  ) dut (
    .clk(clk),
    .rst_n(rst_n),
    .in_valid(in_valid),
    .in_ready(in_ready),
    .end_of_tile(end_of_tile),
    .a(a),
    .b(b),
    .c(c),
    .x(x),
    .y(y),
    .mu_x(mu_x),
    .mu_y(mu_y),
    .color(color),
    .opacity(opacity),
    .out_valid(out_valid),
    .out_ready(out_ready),
    .pixel_out(pixel_out)
  );

  // Clock Generation
  always #5 clk = ~clk; // 10ns period (100MHz)

  // Test Procedure
  initial begin
    // Initialize VCD Dump (Selective Dumping)
    $dumpfile("gaussian_splatting_selected.vcd"); // VCD filename

    // Dump signals from the top level
    $dumpvars(1, tb_gaussian_splatting_engine.clk);
    $dumpvars(1, tb_gaussian_splatting_engine.rst_n);
    $dumpvars(1, tb_gaussian_splatting_engine.in_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.in_ready);
    $dumpvars(1, tb_gaussian_splatting_engine.end_of_tile);
    $dumpvars(1, tb_gaussian_splatting_engine.out_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.out_ready);
    $dumpvars(1, tb_gaussian_splatting_engine.a);
    $dumpvars(1, tb_gaussian_splatting_engine.b);
    $dumpvars(1, tb_gaussian_splatting_engine.pixel_out[0][0]);

    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.accum_transmittance);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.accum_color);

    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.in_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.in_ready);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.out_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.out_ready);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.A_values[0]);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.B_values[0]);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.C_values[0]);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.D_values[0]);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.a_reg);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.b_reg);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.c_reg);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.mu_x_reg);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.mu_y_reg);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.coef_calc.input_registered);

    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.in_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.in_ready);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.opacity);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.color);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.stage1_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.stage2_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.stage3_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.A_ext);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.B_ext);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.C_ext);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.D_ext);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.opacity_ext);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.color_ext);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.exp_output);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.alpha);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.color_contrib);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.accum_transmittance);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.accum_color);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.blended_output);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.out_valid);
    $dumpvars(1, tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.out_ready);
    
    // Initialize Signals
    clk = 0;
    rst_n = 0;
    in_valid = 0;
    end_of_tile = 0;
    out_ready = 1;
    a = 0;
    b = 0;
    c = 0;
    x = 0;
    y = 0;
    mu_x = 0;
    mu_y = 0;
    color = 0;
    opacity = 0;

    // Apply Reset
    #20 rst_n = 1;
    
    // Wait for a few cycles after reset
    #10;
    
    // Stimulus: Provide first input (end_of_tile = 0)
    @(posedge clk);
    in_valid = 1;
    end_of_tile = 0;
    a = 32'h00010000;
    b = 32'h00010000;
    c = 32'h00000000;
    x = 32'h00000000;
    y = 32'h00000000;
    mu_x = 32'h00000000;
    mu_y = 32'h00000000;
    color = 32'h00FF0000;
    opacity = 32'h00010000; // Fixed-point opacity (0.5)
    
    // Wait until input is accepted
    @(posedge clk);
    while (!in_ready) @(posedge clk);
    
    // Deassert valid after input is accepted
    in_valid = 0;
    
    // Wait until output is valid and accepted
    @(posedge clk);
    while (!out_valid) @(posedge clk);
    $display("=== Debug Values ===");
    $display("alpha: %h", tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.alpha_comb);
    $display("color_contrib: %h", tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.weighted_color_comb);
    $display("accum_transmittance: %h", tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.accum_transmittance);
    $display("accum_color: %h", tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.accum_color);
    $display("blended_output: %h", tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.blended_output);
    $display("color_ext: %h", tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.stage2_color);
    $display("stage2_exp_result: %h", tb_gaussian_splatting_engine.dut.row_loop[0].col_loop[0].alpha_blend.stage2_exp_result);
    @(posedge clk);
    
    // Provide second input (end_of_tile = 0)
    @(posedge clk);
    in_valid = 1;
    end_of_tile = 0; // Not end of tile
    a = 32'h000A0A00;
    b = 32'h000B0B00;
    c = 32'h000C0C00;
    x = 32'h00050500;
    y = 32'h00060600;
    mu_x = 32'h00010100;
    mu_y = 32'h00020200;
    color = 32'hFF8000FF;
    opacity = 32'h00800000; // Fixed-point opacity (0.5)
    
    // Wait until input is accepted
    @(posedge clk);
    while (!in_ready) @(posedge clk);
    
    // Deassert valid after input is accepted
    in_valid = 0;
    
    // Wait until output is valid and accepted
    @(posedge clk);
    while (!out_valid) @(posedge clk);
    @(posedge clk);
    
    // Provide third input (end_of_tile = 0)
    #10;
    @(posedge clk);
    in_valid = 1;
    end_of_tile = 0;
    a = 32'h00050500;
    b = 32'h00060600;
    c = 32'h00070700;
    x = 32'h00080800;
    y = 32'h00090900;
    mu_x = 32'h00030300;
    mu_y = 32'h00040400;
    color = 32'h00FF00FF;
    opacity = 32'h00400000; // Different opacity (0.25)
    
    // Wait until input is accepted
    @(posedge clk);
    while (!in_ready) @(posedge clk);
    
    // Deassert valid after input is accepted
    in_valid = 0;
    
    // Wait until output is valid and accepted
    @(posedge clk);
    while (!out_valid) @(posedge clk);
    @(posedge clk);
    
    // Provide fourth input (end_of_tile = 1)
    #10;
    @(posedge clk);
    in_valid = 1;
    end_of_tile = 1; // End of tile for this input
    a = 32'h00030300;
    b = 32'h00040400;
    c = 32'h00050500;
    x = 32'h00060600;
    y = 32'h00070700;
    mu_x = 32'h00020200;
    mu_y = 32'h00030300;
    color = 32'h0000FFFF;  // Different color (blue)
    opacity = 32'h00200000; // Different opacity (0.125)
    
    // Wait until input is accepted
    @(posedge clk);
    while (!in_ready) @(posedge clk);
    
    // Deassert valid after input is accepted
    in_valid = 0;
    end_of_tile = 0; // Reset end_of_tile signal
    
    // Wait until output is valid
    @(posedge clk);
    while (!out_valid) @(posedge clk);
    
    // Wait some additional cycles to observe output
    #50;

    // End simulation
    $finish;
  end

  // Monitor the results
  initial begin
    $monitor("Time=%0t, in_valid=%b, in_ready=%b, end_of_tile=%b, out_valid=%b, pixel[0][0]=%h",
             $time, in_valid, in_ready, end_of_tile, out_valid, pixel_out[0][0]);
  end
endmodule
