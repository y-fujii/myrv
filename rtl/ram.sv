// (c) Yasuhiro Fujii <http://mimosa-pudica.net>, under MIT License.
module Ram#(parameter SIZE, parameter FILE)(
	input  logic       clock,
	input  logic[29:0] bus_addr,
	output logic[31:0] bus_data_r,
	input  logic[31:0] bus_data_w,
	input  logic[ 3:0] bus_mask_w
);
	(* ram_style = "block" *)
	logic[31:0] mem[0:SIZE-1];

	initial $readmemh(FILE, mem);

	wire[$clog2(SIZE)-1:0] phys_addr = $clog2(SIZE)'(bus_addr % 30'(SIZE));

	always_ff @(posedge clock) begin
		if (bus_mask_w[0])
			mem[phys_addr][ 7: 0] <= bus_data_w[ 7: 0];
		if (bus_mask_w[1])
			mem[phys_addr][15: 8] <= bus_data_w[15: 8];
		if (bus_mask_w[2])
			mem[phys_addr][23:16] <= bus_data_w[23:16];
		if (bus_mask_w[3])
			mem[phys_addr][31:24] <= bus_data_w[31:24];
		if (~|bus_mask_w)
			bus_data_r <= mem[phys_addr];
		else
			bus_data_r <= 'x;
	end
endmodule
