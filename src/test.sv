module Test();
	reg        clock;
	reg        reset;
	wire[31:0] bus_addr;
	wire[31:0] bus_data_r;
	wire[31:0] bus_data_w;
	wire[ 3:0] bus_mask_w;

	BRam ram(.clock(~clock), .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w);
	Cpu  cpu(.clock, .reset, .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w);

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
				if (cpu.regs[10] == 0)
					$display("PASS.");
				else
					$display("FAIL.");
				$finish;
			end
			#0.5
			clock = 1;
			#1
			clock = 0;
		end
		$display("FAIL.", cpu.pc);
		$finish;
	end
endmodule

module BRam(
	input  wire       clock,
	// verilator lint_off UNUSEDSIGNAL
	input  wire[31:0] bus_addr,
	output reg [31:0] bus_data_r,
	input  wire[31:0] bus_data_w,
	input  wire[ 3:0] bus_mask_w
);
	logic[31:0] mem[0:1024];

	initial begin
		$readmemh("src/mem.hex", mem);
	end

	always_ff @(posedge clock) begin
		if (bus_mask_w[0])
			mem[bus_addr][ 7: 0] <= bus_data_w[ 7: 0];
		if (bus_mask_w[1])
			mem[bus_addr][15: 8] <= bus_data_w[15: 8];
		if (bus_mask_w[2])
			mem[bus_addr][23:15] <= bus_data_w[23:15];
		if (bus_mask_w[3])
			mem[bus_addr][31:24] <= bus_data_w[31:24];
		bus_data_r <= mem[bus_addr];
	end
endmodule
