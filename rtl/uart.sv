// (c) Yasuhiro Fujii <http://mimosa-pudica.net>, under MIT License.
module UartTx#(parameter N_CYCLES)(
	input  logic      clock,
	input  logic      reset,
	input  logic[7:0] data,
	input  logic      valid,
	output logic      ready,
	output logic      tx
);
	(* onehot *)
	logic[10:0] state;
	logic[$clog2(N_CYCLES)-1:0] count;

	always_comb ready = state[10];
	always_comb tx = reset | |(state & {1'b1, data, 2'b01});

	always_ff @(posedge clock) begin
		if (reset | ~|count)
			count <= $size(count)'(N_CYCLES - 1);
		else
			count <= count - 1'b1;

		if (reset)
			state <= 11'b1_0000_0000_00;
		else if (valid & ready)
			state <= 11'b0_0000_0000_01;
		else if (~|count)
			state <= {|state[10:9], state[8:0], 1'b0};
	end
endmodule
