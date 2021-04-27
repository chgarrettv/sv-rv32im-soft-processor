// Claude Garrett V, 1/29/2021

package alu_test_pkg;

	`include "uvm_macros.svh"
	import uvm_pkg::*;
	
	// Transaction:
	class alu_transaction extends uvm_sequence_item;
		`uvm_object_utils(alu_transaction)
		
		rand bit[3:0] operation;
		rand bit[31:0] rs1, rs2;
		bit [31:0] result;
		
		// Constraints:
		constraint alu_valid_ops_0_c {operation < 4'h_c;}
		
		function new(input string name = "");
			super.new(name);
		endfunction
		
		function string convert2string;
			return $sformatf("Operation: %h, A: %h, B: %h", operation, rs1, rs2);
		endfunction
	
	endclass
	
	// Sequence:
	class alu_sequence extends uvm_sequence #(alu_transaction); // Req will be the type specified by this parameter.
		`uvm_object_utils(alu_sequence)
		
		function new(input string name = "");
			super.new(name);
		endfunction
		
		task body();
			starting_phase.raise_objection(this);
			
			repeat(8) begin
				req = alu_transaction::type_id::create("req");
				start_item(req); // Handshake with driver.
				if(!req.randomize()) `uvm_error("ERROR", "Randomize failed"); // Randomize before handed to driver.
				
				finish_item(req);
			end
			
			starting_phase.drop_objection(this);
		endtask
	endclass
	
	// Sequencer:
	typedef uvm_sequencer #(alu_transaction) alu_sequencer;
	
	// Driver:
	class alu_driver extends uvm_driver #(alu_transaction);
		`uvm_component_utils(alu_driver)
		
		virtual control_unit_interface cu_vif;
		
		function new(input string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			if(!uvm_config_db #(virtual control_unit_interface)::get(this, "", "cu_if", cu_vif)) `uvm_error("ERROR", "Failed to get virtual control unit interface.")
		endfunction
		
		task run_phase(uvm_phase phase);
			forever begin
				seq_item_port.get_next_item(req); // Wait for start_item. Req is part of the base class, so not declared.
				
				@(posedge cu_vif.clock) begin
				// Setup:
				cu_vif.alu.operation <= req.operation;
				cu_vif.alu.output_enable <= 0;
				
				// Signal control:
				cu_vif.alu.operand <= 0;
				cu_vif.value <= req.rs1;
				cu_vif.send <= 1;
				cu_vif.alu.input_enable <= 1; end
				
				@(posedge cu_vif.clock) begin
				cu_vif.alu.operand <= 1;
				cu_vif.value <= req.rs2;
				cu_vif.send <= 1;
				cu_vif.alu.input_enable <= 1; end
				
				@(posedge cu_vif.clock) begin
				cu_vif.send <= 0;
				cu_vif.alu.input_enable <= 0;
				cu_vif.alu.output_enable <= 1; end
				
				seq_item_port.item_done(); // Returns from finish_item.
			end
		endtask
	endclass
	
	// Monitor:
	class alu_monitor extends uvm_monitor;
		`uvm_component_utils(alu_monitor)
		
		virtual control_unit_interface cu_vif;
		uvm_analysis_port #(alu_transaction) mon_ap;
		
		function new(input string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			if(!uvm_config_db #(virtual control_unit_interface)::get(this, "", "cu_if", cu_vif)) `uvm_error("ERROR", "Failed to get virtual control unit interface.")
			mon_ap = new("mon_ap", this);
		endfunction
		
		task run_phase(uvm_phase phase);
			alu_transaction alu_tx = alu_transaction::type_id::create("alu_tx", this);
			
			forever begin
				@(posedge cu_vif.clock) begin
					if(cu_vif.alu.output_enable) begin
						alu_tx.operation = cu_vif.alu.operation;
						alu_tx.result = cu_vif.bus;
						mon_ap.write(alu_tx);
					end
					if(cu_vif.alu.input_enable) begin
						case(cu_vif.alu.operand)
							0: alu_tx.rs1 = cu_vif.bus;
							1: alu_tx.rs2 = cu_vif.bus;
						endcase
					end
				end
			end
		endtask
	endclass
	
	// Agent:
	class alu_agent extends uvm_agent;
		`uvm_component_utils(alu_agent)
		
		alu_sequencer alu_seqr;
		alu_driver alu_dri;
		alu_monitor alu_mon;
		
		function new(input string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			
			alu_seqr = alu_sequencer::type_id::create("alu_seqr", this);
			alu_dri = alu_driver::type_id::create("alu_dri", this);
			alu_mon = alu_monitor::type_id::create("alu_mon", this);
		endfunction
		
		function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			alu_dri.seq_item_port.connect(alu_seqr.seq_item_export); // Connect driver and sequencer.
		endfunction
		
	endclass
	
	// Scoreboard:
	class alu_scoreboard extends uvm_scoreboard;
		`uvm_component_utils(alu_scoreboard)
		
		uvm_analysis_imp #(alu_transaction, alu_scoreboard) sb_imp; // Listen for exports from monitor.
		
		function new(input string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			sb_imp = new("sb_imp", this);
		endfunction
		
		virtual function void write(alu_transaction alu_tx);
			`uvm_info("WRITE", alu_tx.convert2string(), UVM_MEDIUM);
		endfunction
	endclass
	
	// Environment:
	class alu_environment extends uvm_env;
		`uvm_component_utils(alu_environment)
		
		alu_agent alu_ag;
		alu_scoreboard alu_sb;
		
		
		function new(input string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			alu_ag = alu_agent::type_id::create("alu_ag", this);
			alu_sb = alu_scoreboard::type_id::create("alu_sb", this);
		endfunction
		
		function void connect_phase(uvm_phase phase);
			alu_ag.alu_mon.mon_ap.connect(alu_sb.sb_imp);
		endfunction
	endclass
	
	// Test:
	class alu_test extends uvm_test;
		`uvm_component_utils(alu_test)
		alu_environment alu_env;
		
		function new(input string name, uvm_component parent);
			super.new(name, parent);
		endfunction
		
		function void build_phase(uvm_phase phase);
			alu_env = alu_environment::type_id::create("alu_env", this);
		endfunction
		
		task run_phase(uvm_phase phase);
			// Create a sequence.
			alu_sequence alu_seq;
			alu_seq = alu_sequence::type_id::create("alu_seq");
			
			//if(!alu_seq.randomize()) `uvm_error("ERROR", "Randomize failed.")
			
			alu_seq.starting_phase = phase; // Set the phase of the sequencer - needed for raise/drop_objection.
			alu_seq.start(alu_env.alu_ag.alu_seqr); // Actually starts the seq running on the seqr.
		endtask
	endclass

endpackage

/*

// Driver:
class alu_driver extends uvm_driver;
	`uvm_component_utils(alu_driver)
	
	virtual control_unit_interface cu_vif;
	
	function new(input string name, uvm_component parent);
		super.new(name, parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		if(!uvm_config_db #(virtual control_unit_interface)::get(this, "", "cu_if", cu_vif)) `uvm_error("ERROR", "Failed to get virtual control unit interface.")
	endfunction
	
	task run_phase(uvm_phase phase);
		
		cu_vif.value = 0;
		
		forever begin
			cu_vif.send = ~cu_vif.send;
			@(posedge cu_vif.clock);
			cu_vif.value <= $random;
		end
	endtask
endclass

// Environment:
class alu_environment extends uvm_env;
	`uvm_component_utils(alu_environment)
	
	alu_driver alu_dri;
	
	function new(input string name, uvm_component parent);
		super.new(name, parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		alu_dri = alu_driver::type_id::create("alu_dri", this);
	endfunction
endclass

// Test:
class alu_test extends uvm_test;
	`uvm_component_utils(alu_test);
	alu_environment alu_env;
	
	function new(input string name, uvm_component parent);
		super.new(name, parent);
	endfunction
	
	function void build_phase(uvm_phase phase);
		alu_env = alu_environment::type_id::create("alu_env", this);
	endfunction
	
	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
			#100 `uvm_info("LABEL", "alu_test is running", UVM_HIGH)
		phase.drop_objection(this);
	endtask
endclass

*/