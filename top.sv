// Claude Garrett V, 1/29/2021

module cpu_tb;
	//import uvm_pkg::*;
	//import alu_test_pkg::*;

    logic clock, reset;
    tri [31:0] bus;
    logic [2:0] select;
    logic [7:0] segments;
    
    control_unit_interface cu_if(.clock(clock), .reset(reset), .bus(bus));
	
    control_unit cu(cu_if);
    arithmetic_logic_unit alu(cu_if.alu);
    registers regs(cu_if.regs);
    bram_memory mem(cu_if.mem, select, segments);
	
    initial begin
    	// Initialize General Signals:
    	clock <= 1;
    	reset <= 0;
    	
    	// Initialize Control Signals:
    	cu_if.reset_all_control_signals();
    	
    	// UVM Testing:
    	//uvm_config_db #(virtual control_unit_interface)::set(null, "", "cu_if", cu_if);
    	//uvm_top.finish_on_completion = 1;
    	//run_test("alu_test");
    	
    end
    
	always #5 clock = ~clock;
    
endmodule
