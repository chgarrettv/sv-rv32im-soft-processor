// Claude Garrett V, 2/1/2021

interface memory_interface(input logic clock, reset, inout tri [31:0] bus);
	logic read_write; // 0 for read, 1 for write.
	logic data_address; // 0 for data, 1 for address.
	logic input_enable;
	logic output_enable;
	
	logic done_or_valid; // Used to indicate when a write is complete or a read is valid on the bus
	logic [1:0] size; // 00 = byte, 01 = halfword, 10 = word, 11 = doubleword (unused).
	logic sign; // 0 = unsigned, 1 = signed.
endinterface

module memory(memory_interface mem_if
    );
    
    // Procedure:
    	// Read:
    	// Set address on bus, set read_write to 0, data_address is ignored.
    	// Set input_enable HIGH.
    		// Address is captrued from bus.
    		// Hold until done_or_valid is HIGH.
    	// Set output_enable HIGH, input_enable LOW
    		// Data will appear on the bus as long as output_enable is HIGH.
    	
    	// Write:
    	// Set data on bus, set read_write to 1, set data_address to 0.
    	// Set input_enable HIGH.
    		// Data is captured from bus.
    	// Set input_enable LOW.
    	// Set address on bus, read_write remains 1, set data_address to 1.
    	// Set input_enable HIGH.
    		// Address is captured on bus.
    		// done_or_valid will go HIGH when operation is complete.
    		
    	// A positive edge for input_enable will bring done_or_valid LOW.
    
    logic [31:0] address, data;
    byte unsigned memory [2048]; // Should be 256_000_000 for Arty-A7 RAM.
    
    assign mem_if.bus = (mem_if.output_enable) ? data : 'z;
    
    initial begin
    	data <= 0;
    	address <= 0;
    	memory = '{
    	
    	0:8'h_93, // Fibonacci Sequence code.
    	1:8'h_00,
    	2:8'h_00,
    	3:8'h_00,
    	
    	4:8'h_13,
		5:8'h_01,
		6:8'h_10,
		7:8'h_00,
		
		8:8'h_93,
		9:8'h_01,
		10:8'h_00,
		11:8'h_00,
		
		12:8'h_63,
		13:8'h_8A,
		14:8'h_01,
		15:8'h_00,
		
		16:8'h_33,
		17:8'h_81,
		18:8'h_20,
		19:8'h_00,
		
		20:8'h_93,
		21:8'h_01,
		22:8'h_00,
		23:8'h_00,
		
		24:8'h_23,
		25:8'h_28,
		26:8'h_20,
		27:8'h_18,
		
		28:8'h_6F,
		29:8'h_F0,
		30:8'h_1F,
		31:8'h_FF,
		
		32:8'h_B3,
		33:8'h_80,
		34:8'h_20,
		35:8'h_00,
		
		36:8'h_93,
		37:8'h_81,
		38:8'h_11,
		39:8'h_00,
		
		40:8'h_23,
		41:8'h_28,
		42:8'h_10,
		43:8'h_18,
		
		44:8'h_6F,
		45:8'h_F0,
		46:8'h_1F,
		47:8'h_FE,
    	
    	default:0};
    end
    
    always @(negedge mem_if.clock) begin
    	if(mem_if.input_enable) begin
    		case(mem_if.read_write)
    			0: begin // Read.
    				address = mem_if.bus;
    				case(mem_if.size)
    					2'h_0: begin
    						if(mem_if.sign) data = {{24{memory[address][7]}}, memory[address]};
    						else data = {24'b_0, memory[address]};
    					end 2'h_1:begin
    						if(mem_if.sign) data = {{16{memory[address + 1][7]}}, memory[address + 1], memory[address]};
    						else data = {16'b_0, memory[address + 1], memory[address]};
    					end 2'h_2: data = {memory[address + 3], memory[address + 2], memory[address + 1], memory[address]};
    					2'h_3: data = {memory[address + 3], memory[address + 2], memory[address + 1], memory[address]};
    				endcase
    				mem_if.done_or_valid = 1;
    			end 1: begin // Write.
    				case(mem_if.data_address)
    					0: data = mem_if.bus;
    					1: begin
    						address = mem_if.bus; // Will write as soon as the address is captured.
							memory[address] = data;
							case(mem_if.size)
								2'h_0: memory[address] = data[7:0]; // Byte.
								2'h_1: begin // Halfword.
									memory[address] = data[7:0];
									memory[address + 1] = data[15:8];
								end 2'h_2: begin // Word.
									memory[address] = data[7:0]; 
									memory[address + 1] = data[15:8];
									memory[address + 2] = data[23:16];
									memory[address + 3] = data[31:24];
								end 2'h_3: begin // Doubleword (unused in 32 bit ISA).
									memory[address] = data[7:0];
									memory[address + 1] = data[15:8];
									memory[address + 2] = data[23:16];
									memory[address + 3] = data[31:24];
								end
							endcase
							
							mem_if.done_or_valid = 1;
    					end
    				endcase
				end
    		endcase
    	end
    	
    	if(mem_if.reset) begin
    		data <= '0;
    		address <= '0;
    		mem_if.read_write = 0;
    		mem_if.data_address = 0;
    		mem_if.input_enable = 0;
    		mem_if.output_enable = 0;
    		mem_if.done_or_valid = 0;
    	end
    end
    
    always @(posedge mem_if.input_enable) mem_if.done_or_valid = 0; // Invalid data/address if read/write or data/address changes.
    
    
    
endmodule
