// Claude Garrett V, 2/27/2020

module cpu_wrapper(
		input CLK100MHZ,
		output [2:0] select,
		output [7:0] segments,
		output [3:0] led
	);
	
	reg [3:0] count;
	reg reset;
	
	initial begin
		count = 0;
		reset = 0;
	end
	
	always @(posedge CLK100MHZ) begin
		if(count == 4'h_f) count = 0;
		else count = count + 1;
	end
	
	rv32im_soft_processor rvsp(count[2], reset, select, segments, led);
	
endmodule