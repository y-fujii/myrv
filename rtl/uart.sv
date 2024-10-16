// (c) Yasuhiro Fujii <http://mimosa-pudica.net>, under MIT License.
module UartTx#(parameter N_CYCLES)(
	input  logic      clock,
	input  logic      reset,
	input  logic[7:0] data,
	input  logic      valid,
	output logic      ready,
	output logic      tx
);
	logic[                10:0] state;
	logic[$clog2(N_CYCLES)-1:0] count;

	always_comb ready = ~reset & state == 11'b1;
	always_comb tx    =  reset | state[0];

	wire next = count == $size(count)'(N_CYCLES - 1);

	always_ff @(posedge clock) begin
		if (reset | next)
			count <= '0;
		else
			count <= count + 1'b1;

		if (reset)
			state <= '1;
		else if (valid & ready)
			state <= {1'b1, data, 2'b01};
		else if (next & !ready)
			state <= state >> 1'b1;
	end
endmodule
