package alu_pkg;
	import uvm_pkg::*;
	`include "uvm_macros.svh"
	`include "alu_sequence.sv"
	`include "alu_environment.sv"
	
	// Transaction:
	class alu_transaction extends uvm_sequence_item;
		// Transaction variables:
		bit[3:0] operation;
		bit[31:0] rs1, rs2;
		bit [31:0] result;
		
		function new(string name = "");
			super.new(name);
		endfunction
		
		// Constraints:
		//constraint alu_valid_ops_0_c {operation inside {[4'h_0:4'h_c]};}
		
		// Macros:
		`uvm_object_utils_begin(alu_transaction)
		`uvm_field_int(operation, UVM_ALL_ON)
		`uvm_field_int(rs1, UVM_ALL_ON)
		`uvm_field_int(rs2, UVM_ALL_ON)
		`uvm_field_int(result, UVM_ALL_ON)
		`uvm_object_utils_end
	endclass
	
	// Sequence:
	class alu_sequence extends uvm_sequence#(alu_transaction);
		`uvm_object_utils(alu_sequence); // Registed the class.
		
		function new(string name = "");
			super.new(name);
		endfunction
		
		task body();
			alu_transaction alu_tx;
			
			repeat(10) begin
				
				alu_tx = alu_transaction::type_id::create("alu_tx", null);
				
				start_item(alu_tx);
					alu_tx.operation = $random%11;
					alu_tx.rs1 = $random;
					alu_tx.rs2 = $random;
				finish_item(alu_tx);
			end
		endtask
	endclass
	
	// Sequencer:
	typedef uvm_sequencer#(alu_transaction) alu_sequencer;
	
	// Driver:
	class alu_driver extends uvm_driver#(alu_transaction);
		`uvm_component_utils(alu_driver) // Add to factory.
		
		protected virtual testbench_interface tb_vif;
		
		function new(string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			void'(uvm_resource_db#(virtual testbench_interface)::read_by_name(.scope("interfaces"), .name("tb_vif"), .val(tb_vif))); // Get interface from factory.
		endfunction
		
		task run_phase(uvm_phase phase);
			// Operation = rand operation, Operand = 0, inputEnable = 1, rs1 on bus
			// Clock high
			// Clock low
			// Operation = rand operation, Operand = 1, inputEnable = 1, rs2 on bus
			// High/low
			// inputEnable = 0, outputEnable = 1, bus = 'z
			// High/low
			
			alu_transaction alu_tx;
			
			enum {IN_RS1, IN_RS2, OUT_RESULT} alu_test_state;
			alu_test_state = IN_RS1;
			
			
			forever begin
				if(alu_test_state == IN_RS1) seq_item_port.get_next_item(alu_tx);
				
				@(negedge tb_vif.alu.clock) begin
					case(alu_test_state)
						IN_RS1: begin 
							tb_vif.alu.operation <= alu_tx.operation;
							tb_vif.alu.operand <= 1'b_0;
							tb_vif.alu.inputEnable <= 1'b_1;
							
							tb_vif.value <= alu_tx.rs1;
							tb_vif.send <= '1;
							
							alu_test_state = IN_RS2;
						end IN_RS2: begin
							tb_vif.alu.operation <= alu_tx.operation;
							tb_vif.alu.operand <= 1'b_1;
							tb_vif.alu.inputEnable <= 1'b_1;
							
							tb_vif.value <= alu_tx.rs1;
							tb_vif.send <= '1;
							
							alu_test_state = OUT_RESULT;
						end OUT_RESULT: begin
							tb_vif.alu.inputEnable <= 1'b_0;
							tb_vif.alu.outputEnable <= 1'b_1;
							
							tb_vif.value <= 'z;
							tb_vif.send <= '0;
							
							alu_test_state = IN_RS1;
						end
					endcase
				end
			end
		endtask
	endclass
	
	// Monitor:
	class alu_monitor extends uvm_monitor;
		`uvm_component_utils(alu_monitor)
		
		uvm_analysis_port#(alu_transaction) monitor_ap;
		
		protected virtual testbench_interface tb_vif;
		
		alu_transaction alu_tx_cg;
		
		function new(string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			
			void'(uvm_resource_db#(virtual testbench_interface)::read_by_name(.scope("interfaces"), .name("tb_vif"), .val(tb_vif))); // Get interface from factory.
			monitor_ap = new(.name("monitor_ap"), .parent(this));
		endfunction
		
		task run_phase(uvm_phase phase);
			
			@(posedge tb_vif.clock && tb_vif.alu.inputEnable) begin
				alu_tx_cg.rs1 = tb_vif.alu.bus;
				alu_tx_cg.operation = tb_vif.alu.operation;
			end
			
			#5 // Cautionary delay.
			
			@(posedge tb_vif.clock && tb_vif.alu.inputEnable) alu_tx_cg.rs2 = tb_vif.alu.bus;
			
			@(posedge tb_vif.clock && tb_vif.alu.outputEnable) alu_tx_cg.result = tb_vif.alu.bus;
			
			monitor_ap.write(alu_tx_cg);
			
		endtask
	endclass
	
	// Agent:
	class alu_agent extends uvm_agent;
		`uvm_component_utils(alu_agent);
		
		uvm_analysis_port#(alu_transaction) agent_ap;
		
		alu_sequencer	alu_seqr;
		alu_driver		alu_dri;
		alu_monitor		alu_mon;
		
		function new(string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			
			agent_ap = new(.name("agent_ap"), .parent(this));
			
			alu_seqr = alu_sequencer::type_id::create("alu_seqr", this);
			alu_dri = alu_driver::type_id::create("alu_dri", this);
			alu_mon = alu_monitor::type_id::create("alu_mon", this);
		endfunction
		
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			
			alu_dri.seq_item_port.connect(alu_seqr.seq_item_export);
			alu_mon.monitor_ap.connect(agent_ap);
		endfunction
	endclass
	
	// Scoreboard:
	class alu_scoreboard extends uvm_scoreboard;
		`uvm_component_utils(alu_scoreboard)
		
		uvm_analysis_export#(alu_transaction) sb_export;
	
		uvm_tlm_analysis_fifo#(alu_transaction) fifo;
		
		alu_transaction alu_tx;
		
		logic [31:0] prediction;
		
		function new(string name, uvm_component parent);
			super.new(name, parent);
			alu_tx = new("alu_tx");
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			sb_export = new("sb_export");
			
			fifo = new("fifo", this);
		endfunction
		
		function void connect_phase(uvm_phase phase);
			sb_export.connect(fifo.analysis_export);
		endfunction
		
		task run();
			forever begin
				fifo.get(alu_tx);
				
				prediction = 0;
		
				case(alu_tx.operation)
					4'h_0: prediction = alu_tx.rs1 + alu_tx.rs2;
					4'h_1: prediction = alu_tx.rs1 - alu_tx.rs2;
					4'h_2: prediction = alu_tx.rs1 | alu_tx.rs2;
					4'h_3: prediction = alu_tx.rs1 & alu_tx.rs2;
					4'h_4: prediction = alu_tx.rs1 ^ alu_tx.rs2;
					4'h_5: prediction = alu_tx.rs1 << alu_tx.rs2;
					4'h_6: prediction = alu_tx.rs1 >> alu_tx.rs2;
					4'h_7: prediction = alu_tx.rs1 >>> alu_tx.rs2;
					4'h_8: prediction = ($signed(alu_tx.rs1) < $signed(alu_tx.rs2)) ? 32'h_1 : '0;
					4'h_9: prediction = (alu_tx.rs1 < alu_tx.rs2) ? 32'h_1 : '0;
					4'h_a: prediction = alu_tx.rs1 * alu_tx.rs2;
					4'h_b: prediction = alu_tx.rs1 / alu_tx.rs2;
					4'h_c: prediction = alu_tx.rs1 % alu_tx.rs2;
					default: `uvm_info("run", {"Unused operation"}, UVM_HIGH)
				endcase
				
				if(alu_tx.result == prediction) `uvm_info("run", {"Passed."/* Operation = %h, RS1 = %h RS2 = %h, Result = %h", alu_tx.operation, alu_tx.rs1, alu_tx.rs2, alu_tx.result*/}, UVM_LOW)
				else `uvm_info("run", {"FAILED."/* Operation = %h, RS1 = %h RS2 = %h, Result = %h", alu_tx.operation, alu_tx.rs1, alu_tx.rs2, alu_tx.result*/}, UVM_HIGH);
			end
		endtask
	endclass
	
	// Environment:
	class alu_env extends uvm_env;
		`uvm_component_utils(alu_env)
		
		alu_agent alu_ag;
		alu_scoreboard alu_sb;
		
		function new(string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			alu_ag = alu_agent::type_id::create("alu_ag", this);
			alu_sb = alu_scoreboard::type_id::create("alu_sb", this);
		endfunction
		
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			alu_ag.agent_ap.connect(alu_sb.sb_export);
		endfunction
	endclass
	
	class alu_test extends uvm_test;
		`uvm_component_utils(alu_test)
		
		alu_env env;
		
		function new(string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			env = alu_env::type_id::create("env", this);
		endfunction
		
		virtual task run_phase(uvm_phase phase);
			alu_sequence alu_seq;
			
			phase.raise_objection(.obj(this));
				alu_seq = alu_sequence::type_id::create("alu_seq", this);
				alu_seq.start(env.alu_ag.alu_seqr);
			phase.drop_objection(.obj(this));
		endtask
	endclass

endpackage
