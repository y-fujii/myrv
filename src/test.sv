module Test();
	bit       clock;
	bit       reset;
	bit[31:0] bus_addr;
	bit[31:0] bus_data_r;
	bit[31:0] bus_data_w;
	bit[ 3:0] bus_mask_w;
	bit       bus_write;

	BRam ram(.clock(~clock), .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w, .bus_write);
	Cpu  cpu(.clock, .reset, .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w, .bus_write);

	initial begin
		reset = 1;
		#1
		reset = 0;
		for (int i = 0; i < 6; ++i) begin
			#1
			clock = 0;
			#1
			clock = 1;
		end
		#1
		for (int i = 0; i < 16; ++i) begin
			$display(ram.mem[i]);
		end
		$finish;
	end
endmodule

module BRam(
	input  bit       clock,
	// verilator lint_off UNUSEDSIGNAL
   	input  bit[31:0] bus_addr,
	output bit[31:0] bus_data_r,
	input  bit[31:0] bus_data_w,
	input  bit[ 3:0] bus_mask_w,
	input  bit       bus_write
);
	bit[31:0] mem[1023:0];

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
