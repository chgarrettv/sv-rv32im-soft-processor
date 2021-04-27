`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/27/2021 08:35:37 AM
// Design Name: 
// Module Name: bram_memory
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

module bram_wrapper(
		input logic [31:0] count,
		output logic [2:0] select,
		output logic [7:0] segments
	);
	
	tri [31:0] bus;
	logic [31:0] address;
	enum {READ1, READ2} state;
	
	assign bus = (mem_if.input_enable) ? address : 'z;
	
	memory_interface mem_if(count[31], 1'b_0, bus);
	
	bram_memory(mem_if);//, select, segments);
	Octo7Segment octo(count[17], bus, select, segments);
	
	initial begin
		address = 0;
		mem_if.read_write <= 0; // 0 for read, 1 for write.
		mem_if.data_address <= 1; // 0 for data, 1 for address. Ignored for read, always address.
		mem_if.input_enable <= 0;
		mem_if.output_enable <= 0;
		mem_if.size <= 2;
		mem_if.sign <= 0;
	end
	
	always @(count[31]) begin
		case(state)
			READ1: begin
				if(count[31]) begin
					mem_if.output_enable <= 0;
					mem_if.input_enable <= 1;
					state <= READ2;
				end
			end READ2: begin
				if(mem_if.done_or_valid) begin
					mem_if.input_enable <= 0;
					mem_if.output_enable <= 1;
					if(address == 32'h_2c) address <= 0;
					else address <= address + 4;
					state <= READ1;
				end
			end
		endcase
	end

endmodule

module bram_memory(
		memory_interface mem_if//,
		//logic [2:0] select,
		//logic [7:0] segments
    );
    
    wire [31:0] doa, dob;
	logic [31:0] dia, dib;
	logic ena, enb;
	logic [9:0] addra, addrb;
	logic [3:0] wea, web;
	
	logic [31:0] delay;
	
	logic [31:0] data;
	
	enum {READ_CAPTURE, READ_WAIT, READ_RESULT} read_state;
		
	//enum {} write_state;
	
	//Octo7Segment octo(mem_if.clock, doa, select, segments);
	
	initial begin
		mem_if.read_write <= 0;
		mem_if.data_address <= 0;
		mem_if.input_enable <= 0;
		mem_if.output_enable <= 0;
		mem_if.done_or_valid <= 0;
		delay <= 0;
		
		dia <= 0; dib <= 0;
		ena <= 0; enb <= 1; // Always reading on b port.
		addra <= 0; addrb <= 100; // Remember to divide the wanted address by 4 since reads/writes are 32 bits. // Read constantly from 100 for the program.
		wea = 0; web = 0;
		
		data <= 0;
		
		read_state = READ_CAPTURE;
	end
    
    BRAM_TDP_MACRO #(
		.BRAM_SIZE("36Kb"),
		.DEVICE("7SERIES"),
		.DOA_REG(1),
		.DOB_REG(0),
		.INIT_A(32'h_0), // Initial value after configuration.
		.INIT_B(32'h_0),
		//.INIT_FILE(),
		.READ_WIDTH_A(32),
		.READ_WIDTH_B(32),
		.SIM_COLLISION_CHECK("ALL"),
		.SRVAL_A(32'h_0), // Initial port value on reset.
		.SRVAL_B(32'h_0),
		.WRITE_MODE_A("READ_FIRST"),
		.WRITE_MODE_B("READ_FIRST"),
		.WRITE_WIDTH_A(32),
		.WRITE_WIDTH_B(32),
		.INIT_00(256'h_FF1FF06F_18202823_00000193_00208133_00018A63_00000193_00100113_00000093), // First 8 instructions.
		.INIT_01(256'h_00000000_00000000_00000000_00000000_FE1FF06F_18102823_00100193_002080B3) // Last 4 instructions.
	) BRAM_TDP_MACRO_inst(
		.DOA(doa), // Data output, address specified by ADDR. 32 bits wide.
		.DOB(dob),
		.ADDRA(addra), // 10 address bits for 36kb by 32.
		.ADDRB(addrb),
		.CLKA(mem_if.clock), // Clocks for each port.
		.CLKB(mem_if.clock),
		.DIA(dia), // Data input, address specified by ADDR. 32 bits wide.
		.DIB(dib),
		.ENA(ena), // Port enable.
		.ENB(1'b_1),
		.REGCEA(1'b_1), // Output registed clock enable, valid only when DO_REG == 1.
		.REGCEB(1'b_0),
		.RSTA(1'b_0), // Ouput Register synchronous reset.
		.RSTB(1'b_0),
		.WEA(wea), // Write enable for each byte. 4 bits for 36kb by 32.
		.WEB(4'h_0) // Keep HIGH when writing, LOW when reading.
	);
	
	// Start of memory logic:
	
	assign mem_if.bus = (mem_if.output_enable) ? data : 'z;
	
	always @(!mem_if.clock) begin
		/*if(mem_if.output_enable) begin
			mem_if.done_or_valid <= 0;
			read_state = READ_CAPTURE;
			ena <= 0;
		end*/
		
		if(mem_if.input_enable) begin
			case(mem_if.read_write)
				0: begin // Read.
					case(read_state)
						READ_CAPTURE: begin
							mem_if.done_or_valid <= 0;
							addra <= {2'h_0, mem_if.bus[31:2]};
							wea <= 0; // Indicates a read.
							ena <= 1;
							read_state <= READ_WAIT;
							delay <= 3;
						end READ_WAIT: begin
							if(delay == 0) read_state = READ_RESULT;
							else delay <= delay - 1;
						end READ_RESULT: begin
							case(mem_if.size)
								2'h_0: begin // Byte.
									if(mem_if.sign) data <= {{24{doa[7]}}, doa[7:0]};
									else data <= {24'b_0, doa[7:0]};
								end 2'h_1: begin // Halfword.
									if(mem_if.sign) data <= {{16{doa[15]}}, doa[15:0]};
									else data <= {16'b_0, doa[15:0]};
								end 2'h_2: data <= doa; // Word.
								2'h_3: data <= doa;
							endcase
							mem_if.done_or_valid <= 1;
						end
					endcase
				end 1: begin // Write.
					read_state = READ_CAPTURE;
					mem_if.done_or_valid <= 1;
				end
			endcase
		
			/*
			case(mem_if.read_write)
				0: begin // Read.
					if(delay == 0 || delay == 1) begin
						addra <= {2'h_0, mem_if.bus[31:2]};
						wea <= 0; // Indicates a read.
						ena <= 1;
						delay <= delay + 1;
					end else if(delay == 2) begin
						case(mem_if.size)
							2'h_0: begin // Byte.
								if(mem_if.sign) data <= {{24{doa[7]}}, doa[7:0]};
								else data <= {24'b_0, doa[7:0]};
							end 2'h_1: begin // Halfword.
								if(mem_if.sign) data <= {{16{doa[15]}}, doa[15:0]};
								else data <= {16'b_0, doa[15:0]};
							end 2'h_2: data <= doa; // Word.
							2'h_3: data <= doa;
						endcase
						mem_if.done_or_valid <= 1;
						delay <= 0;
					end
				end 1: begin // Write.
					case(mem_if.data_address)
						0: dia <= mem_if.bus;
						1: begin
							addra <= {2'h_0, mem_if.bus[31:2]}; // Will write as soon as the address is captured.
							ena <= 1;
							case(mem_if.size)
								2'h_0: begin // Byte.
									wea <= 4'h_1; // Only write the lowest byte.
								end 2'h_1: begin // Halfword.
									wea <= 4'h_3; // Only write the lowest byte.
								end 2'h_2: begin // Word.
									wea <= 4'h_f;
								end 2'h_3: begin // Doubleword (unused in 32 bit ISA).
									wea <= 4'h_f;
								end
							endcase
							mem_if.done_or_valid <= 1;
							//delay = 5;
						end
					endcase
				end
			endcase*/
		end
		
		/*if(mem_if.reset) begin
			dia <= 0; dib <= 0;
			ena <= 0; enb <= 1; // Always reading on b port.
			addra <= 0; addrb <= 100; // 100 is mapped to the 7 segment display.
			wea = 0; web = 0;
		
			data <= '0;
			mem_if.read_write <= 0;
			mem_if.data_address <= 0;
			mem_if.input_enable <= 0;
			mem_if.output_enable <= 0;
			mem_if.done_or_valid <= 0;
		end*/
		
		/*if(delay == 32'h_1) begin
			mem_if.done_or_valid = 1'h_1;
			delay = 32'h_0;
			ena = 0;
		end else if(delay != 32'h_0) delay = delay - 1;
		*/
	end
    
endmodule
