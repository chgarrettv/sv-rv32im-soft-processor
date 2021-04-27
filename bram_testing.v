// Claude Garrett V, 3/2/2021


module bram_testing(
		input CLK100MHZ,
		output [2:0] select,
		output [7:0] segments
    );
    
    reg [31:0] count;
    
    bram_wrapper(count, select, segments);
    
    initial count = 0;
    
    always @(posedge CLK100MHZ) count = count + 1;
    
endmodule
