// (c) Yasuhiro Fujii <http://mimosa-pudica.net>, under MIT License.
module Test();
	logic       clock;
	logic       reset;
	logic[29:0] bus_addr;
	logic[31:0] bus_data_r;
	logic[31:0] bus_data_w;
	logic[ 3:0] bus_mask_w;

	Ram#(8192, "build/mem.hex")
	    ram(.clock,         .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w);
	(* keep_hierarchy = "true" *)
	Cpu cpu(.clock, .reset, .bus_addr, .bus_data_r, .bus_data_w, .bus_mask_w);

	initial begin
		clock = 1'b0;
		reset = 1'b1;
		#0.5
		clock = 1'b1;
		#0.5
		clock = 1'b0;
		reset = 1'b0;
		for (int i = 0; i < 65536; ++i) begin
			if (cpu.state[cpu.StExec] && cpu.inst[31:2] == 30'b11100) begin
				if (cpu.regs[10] == 0)
					$display("PASS.");
				else
					$display("FAIL: #%0d.", cpu.regs[10] >> 1);
				$finish(0);
			end
			#0.5
			clock = 1'b1;
			#0.5
			clock = 1'b0;
		end
		$display("FAIL: pc = %h.", 4 * cpu.pc);
		$finish(0);
	end
endmodule
