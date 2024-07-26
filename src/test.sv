(* top *)
module Test();
	logic       clock;
	logic       reset;
	logic[29:0] bus_addr;
	logic[31:0] bus_data_r;
	logic[31:0] bus_data_w;
	logic[ 3:0] bus_mask_w;

	Ram#(8192) ram(.clock,         .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w);
	Cpu        cpu(.clock, .reset, .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w);

	initial begin
		$readmemh("src/mem.hex", ram.mem);
		clock = 0;
		reset = 1;
		#0.5
		clock = 1;
		#0.5
		clock = 0;
		reset = 0;
		for (int i = 0; i < 65536; ++i) begin
			if (cpu.state[cpu.StExec] && cpu.inst[31:2] == 'b11100) begin
				if (cpu.regs[10] == 0)
					$display("PASS.");
				else
					$display("FAIL: pc = %h, x10 = %h.", 4 * cpu.pc, cpu.regs[10]);
				$finish(0);
			end
			#0.5
			clock = 1;
			#0.5
			clock = 0;
		end
		$display("FAIL: pc = %h, x10 = %h.", 4 * cpu.pc, cpu.regs[10]);
		$finish(0);
	end
endmodule

module Ram#(parameter SIZE)(
	input  logic       clock,
	// verilator lint_off UNUSEDSIGNAL
	input  logic[29:0] bus_addr,
	// verilator lint_on  UNUSEDSIGNAL
	output logic[31:0] bus_data_r,
	input  logic[31:0] bus_data_w,
	input  logic[ 3:0] bus_mask_w
);
	(* ram_style = "block" *)
	logic[31:0] mem[0:SIZE-1];

	always_ff @(posedge clock) begin
		// verilator lint_off WIDTHTRUNC
		if (bus_mask_w[0])
			mem[bus_addr][ 7: 0] <= bus_data_w[ 7: 0];
		if (bus_mask_w[1])
			mem[bus_addr][15: 8] <= bus_data_w[15: 8];
		if (bus_mask_w[2])
			mem[bus_addr][23:16] <= bus_data_w[23:16];
		if (bus_mask_w[3])
			mem[bus_addr][31:24] <= bus_data_w[31:24];
		if (~|bus_mask_w)
			bus_data_r <= mem[bus_addr];
		else
			bus_data_r <= 'x;
		// verilator lint_on  WIDTHTRUNC
	end
endmodule
