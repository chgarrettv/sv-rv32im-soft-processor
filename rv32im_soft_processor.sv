// Claude Garrett V, 2/27/2020


module rv32im_soft_processor(
		input logic clock, reset,
		output [2:0] select,
		output [7:0] segments,
		output [3:0] led
    );
	tri [31:0] bus;
	
	control_unit_interface cu_if(.clock(clock), .reset(reset), .bus(bus));
	
	assign led[0] = cu_if.mem.input_enable;
	assign led[1] = cu_if.mem.done_or_valid;
	assign led[3:2] = 0;
	
	control_unit cu(cu_if);
	arithmetic_logic_unit alu(cu_if.alu);
	registers regs(cu_if.regs);
	bram_memory mem(cu_if.mem, select, segments);
	
	initial begin
		cu_if.reset_all_control_signals();
	end
endmodule
