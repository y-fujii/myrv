// (c) Yasuhiro Fujii <http://mimosa-pudica.net>, under MIT License.
module UartTx#(parameter N_CYCLES)(
	input  logic      clock,
	input  logic      reset,
	input  logic[7:0] data,
	input  logic      valid,
	output logic      ready,
	output logic      tx
);
	logic[11:0] n_clks;
	logic[ 3:0] n_bits;

	always_comb ready = n_bits == 4'b1000;

	always_comb unique casez (n_bits)
		4'b1111 : tx = 1'b0;
		4'b0??? : tx = data[n_bits[2:0]];
		default : tx = 1'b1;
	endcase

	always_ff @(posedge clock) begin
		if (reset)
			n_clks <= 0;
		else if (n_clks == N_CYCLES - 1)
			n_clks <= 0;
		else
			n_clks <= n_clks + 12'b1;

		if (reset)
			n_bits <= 4'b1000;
		else if (valid & ready)
			n_bits <= 4'b1110;
		else if (n_clks == N_CYCLES - 1 & !ready)
			n_bits <= n_bits + 4'b1;
	end
endmodule
