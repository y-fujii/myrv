module Cpu(
	input  logic       clock,
	input  logic       reset,
	output logic[29:0] bus_addr,
	input  logic[31:0] bus_data_r,
	output logic[31:0] bus_data_w,
	output logic[ 3:0] bus_mask_w
);
	localparam logic[1:0] StExec = 0, StWait = 1, StLoad = 2;

	(* onehot *)
	logic[ 2:0] state;      // dff.
	logic[29:0] pc;         // dffe.
	logic[31:0] regs[31:0]; // dffe.
	logic[14:7] load_inst;  // dff.
	logic[ 1:0] load_align; // dff.

	wire[31:2] inst = bus_data_r[31:2];
	wire op_lui    = inst[6:2] == 5'b01101;
	wire op_auipc  = inst[6:2] == 5'b00101;
	wire op_regimm = inst[6:2] == 5'b00100;
	wire op_regreg = inst[6:2] == 5'b01100;
	wire op_load   = inst[6:2] == 5'b00000;
	wire op_store  = inst[6:2] == 5'b01000;
	wire op_jal    = inst[6:2] == 5'b11011;
	wire op_jalr   = inst[6:2] == 5'b11001;
	wire op_branch = inst[6:2] == 5'b11000;

	wire[ 4:0] rdi = state[StExec] ? inst[11:7] : load_inst[11:7];
	wire[31:0] rs1 = |inst[19:15] ? regs[inst[19:15]] : '0;
	wire[31:0] rs2 = |inst[24:20] ? regs[inst[24:20]] : '0;
	wire[31:0] rs2_imm = inst[5] ? rs2 : {{20{inst[31]}}, inst[31:20]};

	wire cmp_lts = signed'(rs1) < signed'(rs2_imm);
	wire cmp_ltu = rs1 < rs2_imm;
	wire branch = op_branch & (inst[12] ^ (
		inst[14:13] == 2'b10 ? cmp_lts :
		inst[14:13] == 2'b11 ? cmp_ltu :
		inst[14:13] == 2'b00 ? rs1 == rs2_imm :
		'x
	));

	wire[31:0] alu = (
		inst[14:12] == 3'b000 ? (inst[5] & inst[30] ? rs1 - rs2_imm : rs1 + rs2_imm) :
		inst[14:12] == 3'b010 ? {31'b0, cmp_lts} :
		inst[14:12] == 3'b011 ? {31'b0, cmp_ltu} :
		inst[14:12] == 3'b100 ? rs1 ^ rs2_imm :
		inst[14:12] == 3'b110 ? rs1 | rs2_imm :
		inst[14:12] == 3'b111 ? rs1 & rs2_imm :
		inst[14:12] == 3'b001 ? rs1 << rs2_imm[4:0] :
		inst[14:12] == 3'b101 ? 32'(signed'({inst[30] & rs1[31], rs1}) >>> rs2_imm[4:0]) :
		'x
	);

	wire[31:0] addr_reg = (
		op_load | op_store | op_jalr  ? rs1 :
		op_auipc | op_jal | op_branch ? {pc, 2'b0} :
		op_lui                        ? '0 :
		'x
	);
	wire[31:0] addr_imm = (
		op_lui | op_auipc ? {inst[31:12], 12'b0} :
		op_load | op_jalr ? {{20{inst[31]}}, inst[31:20]} :
		op_store          ? {{20{inst[31]}}, inst[31:25], inst[11:7]} :
		op_jal            ? {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0} :
		op_branch         ? {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0} :
		'x
	);
	wire[31:0] addr = addr_reg + addr_imm;

	wire[31:0] load_value_s = bus_data_r >> {load_align, 3'b0};
	wire[31:0] load_value = (
		load_inst[13:12] == 2'b00 ? {load_inst[14] ? 24'b0 : {24{load_value_s[ 7]}}, load_value_s[ 7:0]} :
		load_inst[13:12] == 2'b01 ? {load_inst[14] ? 16'b0 : {16{load_value_s[15]}}, load_value_s[15:0]} :
		load_inst[13:12] == 2'b10 ? load_value_s :
		'x
	);

	wire is_exec = ~reset & state[StExec];
	wire[2:0] state_next = (
		is_exec & op_load  ? 3'b1 << StLoad :
		is_exec & op_store ? 3'b1 << StWait :
		3'b1 << StExec
	);

	wire[29:0] pc_succ = pc + 30'b1;
	wire[30:0] pc_next = (
		reset                                       ? {1'b1, 30'b0} :
		state[StExec] & (op_load | op_store)        ? {1'b0, 30'bx} :
		state[StExec] & (op_jal | op_jalr | branch) ? {1'b1, addr[31:2]} :
		{1'b1, pc_succ}
	);

	wire[32:0] rd_next = (
		state[StLoad]                           ? {1'b1, load_value} :
		state[StExec] & (op_lui | op_auipc)     ? {1'b1, addr} :
		state[StExec] & (op_regimm | op_regreg) ? {1'b1, alu} :
		state[StExec] & (op_jal | op_jalr)      ? {1'b1, pc_succ, 2'b0} :
		{1'b0, 32'bx}
	);

	assign bus_data_w = rs2 << {addr[1:0], 3'b0};
	assign bus_mask_w = (
		is_exec & op_store ? {inst[13], inst[13], inst[13] | inst[12], 1'b1} << addr[1:0] : '0
	);
	assign bus_addr = (
		reset ? '0 :
		state[StExec] & (op_load | op_store | op_jal | op_jalr | branch) ? addr[31:2] :
		pc_succ
	);

	always_ff @(posedge clock) begin
		load_inst <= inst[14:7];
		load_align <= addr[1:0];
		state <= state_next;
		if (pc_next[30])
			pc <= pc_next[29:0];
		if (rd_next[32])
			regs[rdi] <= rd_next[31:0];
	end
endmodule
