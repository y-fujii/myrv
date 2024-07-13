module Test();
	logic       clock;
	logic       reset;
	logic[31:0] bus_addr;
	logic[31:0] bus_data_r;
	logic[31:0] bus_data_w;
	logic[ 3:0] bus_mask_w;
	logic       bus_write;

	BRam ram(.clock(~clock), .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w, .bus_write);
	Cpu  cpu(.clock, .reset, .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w, .bus_write);

	initial begin
		clock = 0;
		#0.5
		reset = 1;
		#0.5
		clock = 1;
		#0.5
		reset = 0;
		#0.5
		clock = 0;
		//forever begin
		for (int i = 0; i < 65536; ++i) begin
			#0.5
			if (cpu.state == cpu.Execute && cpu.inst[31:2] == 'b11100) begin
				$display("ecall: x10 = %h.", cpu.regs[10]);
				$finish;
			end
			#0.5
			clock = 1;
			#1
			clock = 0;
		end
		$display("terminated: pc = %h.", cpu.pc);
		$finish;
	end
endmodule

module BRam(
	input  logic       clock,
	// verilator lint_off UNUSEDSIGNAL
	input  logic[31:0] bus_addr,
	output logic[31:0] bus_data_r,
	input  logic[31:0] bus_data_w,
	input  logic[ 3:0] bus_mask_w,
	input  logic       bus_write
);
	logic[31:0] mem[0:1024];

	initial begin
		$readmemh("src/mem.hex", mem);
	end

	always_ff @(posedge clock) begin
		if (bus_write) begin
			if (bus_mask_w[0])
				mem[bus_addr][ 7: 0] <= bus_data_w[ 7: 0];
			if (bus_mask_w[1])
				mem[bus_addr][15: 8] <= bus_data_w[15: 8];
			if (bus_mask_w[2])
				mem[bus_addr][23:15] <= bus_data_w[23:15];
			if (bus_mask_w[3])
				mem[bus_addr][31:24] <= bus_data_w[31:24];
		end
		bus_data_r <= mem[bus_addr];
	end
endmodule
