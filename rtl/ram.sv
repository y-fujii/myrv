// (c) Yasuhiro Fujii <http://mimosa-pudica.net>, under MIT License.
module Ram#(parameter SIZE, parameter FILE)(
	input  logic       clock,
	input  logic[29:0] bus_addr,
	output logic[31:0] bus_data_r,
	input  logic[31:0] bus_data_w,
	input  logic[ 3:0] bus_mask_w
);
	localparam BITS = $clog2(SIZE);

	(* ram_style = "block" *)
	logic[31:0] mem[0:SIZE-1];

	initial $readmemh(FILE, mem);

	wire[BITS-1:0] phys_addr = bus_addr[BITS-1:0];
	wire en = bus_addr[29:BITS] == '0 | bus_addr[29:BITS] == '1;

	always_ff @(posedge clock) begin
		if (en & bus_mask_w[0])
			mem[phys_addr][ 7: 0] <= bus_data_w[ 7: 0];
		if (en & bus_mask_w[1])
			mem[phys_addr][15: 8] <= bus_data_w[15: 8];
		if (en & bus_mask_w[2])
			mem[phys_addr][23:16] <= bus_data_w[23:16];
		if (en & bus_mask_w[3])
			mem[phys_addr][31:24] <= bus_data_w[31:24];
		if (en & ~|bus_mask_w)
			bus_data_r <= mem[phys_addr];
		else
			bus_data_r <= 'x;
	end
endmodule
