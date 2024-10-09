// (c) Yasuhiro Fujii <http://mimosa-pudica.net>, under MIT License.
module Cpu(
	input  logic       clock,
	input  logic       reset,
	output logic[29:0] bus_addr,   // comb.
	input  logic[31:0] bus_data_r,
	output logic[31:0] bus_data_w, // comb.
	output logic[ 3:0] bus_mask_w  // comb.
);
	localparam logic[1:0] StExec = 0, StWait = 1, StLoad = 2;

	(* onehot *)
	logic[ 2:0] state;      // dff.
	logic[29:0] pc;         // dffe.
	logic[31:0] regs[1:31]; // dffe.
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
	//wire[31:0] rs2_imm = inst[5] ? rs2 : {{20{inst[31]}}, inst[31:20]};
	wire[31:0] rs2_imm = op_regimm ? {{20{inst[31]}}, inst[31:20]} : rs2; // reduce fan-out.

	wire cmp_ltu = rs1 < rs2_imm;
	wire cmp_lts = (rs1[31] ^ rs2_imm[31]) ^ cmp_ltu;
	logic cmp;
	always_comb unique case (inst[14:13])
		2'b10   : cmp = cmp_lts;
		2'b11   : cmp = cmp_ltu;
		2'b00   : cmp = rs1 == rs2_imm;
		default : cmp = 'x;
	endcase
	wire branch = op_branch & (inst[12] ^ cmp);

	logic[31:0] alu;
	always_comb unique case (inst[14:12])
		3'b000  : alu = inst[5] & inst[30] ? rs1 - rs2_imm : rs1 + rs2_imm;
		3'b010  : alu = {31'b0, cmp_lts};
		3'b011  : alu = {31'b0, cmp_ltu};
		3'b100  : alu = rs1 ^ rs2_imm;
		3'b110  : alu = rs1 | rs2_imm;
		3'b111  : alu = rs1 & rs2_imm;
		3'b001  : alu = rs1 << rs2_imm[4:0];
		3'b101  : alu = 32'(signed'({inst[30] & rs1[31], rs1}) >>> rs2_imm[4:0]);
		default : alu = 'x;
	endcase

	logic[31:0] addr_reg;
	always_comb unique case (1'b1)
		op_load | op_store | op_jalr  : addr_reg = rs1;
		op_auipc | op_jal | op_branch : addr_reg = {pc, 2'b0};
		op_lui                        : addr_reg = '0;
		default                       : addr_reg = 'x;
	endcase
	logic[31:0] addr_imm;
	always_comb unique case (1'b1)
		op_lui | op_auipc : addr_imm = {inst[31:12], 12'b0};
		op_load | op_jalr : addr_imm = {{20{inst[31]}}, inst[31:20]};
		op_store          : addr_imm = {{20{inst[31]}}, inst[31:25], inst[11:7]};
		op_jal            : addr_imm = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};
		op_branch         : addr_imm = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
		default           : addr_imm = 'x;
	endcase
	wire [31:0] addr = addr_reg + addr_imm;

	wire [31:0] load_value_s = bus_data_r >> {load_align, 3'b0};
	logic[31:0] load_value;
	always_comb unique case (load_inst[13:12])
		2'b00   : load_value = {{24{~load_inst[14] & load_value_s[ 7]}}, load_value_s[ 7:0]};
		2'b01   : load_value = {{16{~load_inst[14] & load_value_s[15]}}, load_value_s[15:0]};
		2'b10   : load_value = load_value_s;
		default : load_value = 'x;
	endcase

	wire is_exec = ~reset & state[StExec];
	logic[2:0] state_next;
	always_comb unique case (1'b1)
		is_exec & op_load  : state_next = 3'b1 << StLoad;
		is_exec & op_store : state_next = 3'b1 << StWait;
		default            : state_next = 3'b1 << StExec;
	endcase

	wire [29:0] pc_succ = pc + 30'b1;
	logic[30:0] pc_next;
	always_comb unique case (1'b1)
		reset                                 : pc_next = {1'b1, 30'b0};
		is_exec & (op_load | op_store)        : pc_next = {1'b0, 30'bx};
		is_exec & (op_jal | op_jalr | branch) : pc_next = {1'b1, addr[31:2]};
		default                               : pc_next = {1'b1, pc_succ};
	endcase

	logic[32:0] rd_next;
	always_comb unique case (1'b1)
		state[StLoad]                           : rd_next = {1'b1, load_value};
		state[StExec] & (op_lui | op_auipc)     : rd_next = {1'b1, addr};
		state[StExec] & (op_regimm | op_regreg) : rd_next = {1'b1, alu};
		state[StExec] & (op_jal | op_jalr)      : rd_next = {1'b1, pc_succ, 2'b0};
		default                                 : rd_next = {1'b0, 32'bx};
	endcase

	always_comb bus_data_w = rs2 << {addr[1:0], 3'b0};
	always_comb bus_mask_w = is_exec & op_store ?
		{{2{inst[13]}}, inst[13] | inst[12], 1'b1} << addr[1:0] : '0;
	always_comb unique case (1'b1)
		reset                                                      : bus_addr = '0;
		is_exec & (op_load | op_store | op_jal | op_jalr | branch) : bus_addr = addr[31:2];
		default                                                    : bus_addr = pc_succ;
	endcase

	always_ff @(posedge clock) begin
		load_inst <= inst[14:7];
		load_align <= addr[1:0];
		state <= state_next;
		if (pc_next[30])
			pc <= pc_next[29:0];
		if (rd_next[32] & |rdi)
			regs[rdi] <= rd_next[31:0];
	end
endmodule
