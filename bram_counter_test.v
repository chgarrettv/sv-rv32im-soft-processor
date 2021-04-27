`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/25/2021 05:47:21 PM
// Design Name: 
// Module Name: bram_counter_test
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

module bram_counter_tb();
	
	reg clock;
	wire [2:0] select;
	wire [7:0] segments;
	wire [3:0] led;
	
	bram_counter_module test(clock, select, segments, led);
	
	initial clock <= 0;
	
	always #10 clock = ~clock;
	
endmodule

module bram_counter_module(
		input CLK100MHZ,
		output [2:0] select,
		output [7:0] segments,
		output [3:0] led
    );
    
    
    // Port A is the input, port B is the display output.
    
    wire [31:0] doa, dob;
    reg [31:0] dia, dib;
    reg [9:0] addra, addrb;
    assign led = {dia[20], dia[21], dia[22], dia[23]};
    
    reg [31:0] count;
    
    initial begin
		dia = 0;
		dib = 0;
    	addra = 0;
    	addrb = 0;
    	count = 0;
    end
    
    always @(posedge CLK100MHZ) begin
    	addra = addra + 1;
	end
    
    BRAM_TDP_MACRO #(
    	.BRAM_SIZE("36Kb"),
    	.DEVICE("7SERIES"),
    	.DOA_REG(0),
    	.DOB_REG(0),
    	.INIT_A(32'h_0), // Initial value after configuration.
    	.INIT_B(32'h_ffffffff),
    	//.INIT_FILE(),
    	.READ_WIDTH_A(32),
    	.READ_WIDTH_B(32),
    	.SIM_COLLISION_CHECK("ALL"),
    	.SRVAL_A(32'h_ffffffff), // Initial port value on reset.
    	.SRVAL_B(32'h_ffffffff),
    	.WRITE_MODE_A("READ_FIRST"),
    	.WRITE_MODE_B("READ_FIRST"),
    	.WRITE_WIDTH_A(32),
    	.WRITE_WIDTH_B(32),
    	.INIT_00(256'h_FF1FF06F_18202823_00000193_00208133_00018A63_00000193_00100113_00000093)
    ) BRAM_TDP_MACRO_inst(
    	.DOA(doa), // Data output, address specified by ADDR. 32 bits wide.
    	.DOB(dob),
    	.ADDRA(addra), // 10 address bits for 36kb by 32.
    	.ADDRB(addrb),
    	.CLKA(CLK100MHZ), // Clocks for each port.
    	.CLKB(CLK100MHZ),
    	.DIA(dia), // Data input, address specified by ADDR. 32 bits wide.
    	.DIB(dib),
    	.ENA(1'b_1), // Port enable.
    	.ENB(1'b_1),
    	//.REGCEA(), // Output registed clock enable, valid only when DO_REG == 1.
    	//.REGCEB(),
    	.RSTA(1'b_0), // Ouput Register synchronous reset.
    	.RSTB(1'b_0),
    	.WEA(4'h_f), // Write enable for each byte. 4 bits for 36kb by 32.
    	.WEB(4'h_0) // Keep HIGH when writing, LOW when reading.
    );
    //module Octo7Segment(refresh_clock, [31:0] value, [2:0] select, [7:0] segments);
    Octo7Segment octo(count[9], dob, select, segments);
    
endmodule
