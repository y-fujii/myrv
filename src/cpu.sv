module Cpu(
	input  logic       clock,
	input  logic       reset,
	output logic[29:0] bus_addr,
	input  logic[31:0] bus_data_r,
	output logic[31:0] bus_data_w,
	output logic[ 3:0] bus_mask_w
);
	localparam logic[1:0] StExec = 0, StWait = 1, StLoad = 2;
	localparam logic[4:0] OpLui    = 'b01101;
	localparam logic[4:0] OpAuipc  = 'b00101;
	localparam logic[4:0] OpRegImm = 'b00100;
	localparam logic[4:0] OpRegReg = 'b01100;
	localparam logic[4:0] OpLoad   = 'b00000;
	localparam logic[4:0] OpStore  = 'b01000;
	localparam logic[4:0] OpJal    = 'b11011;
	localparam logic[4:0] OpJalr   = 'b11001;
	localparam logic[4:0] OpBranch = 'b11000;

	(* onehot *)
	logic[ 2:0] state;      // dff.
	logic[29:0] pc;         // dffe.
	logic[31:0] regs[31:0]; // dffe.
	logic[14:7] load_inst;  // dff.
	logic[ 1:0] load_align; // dff.

	wire[31:2] inst = bus_data_r[31:2];
	wire[ 4:0] rdi = state[StExec] ? inst[11:7] : load_inst[11:7];
	wire[31:0] rs1 = |inst[19:15] ? regs[inst[19:15]] : 0;
	wire[31:0] rs2 = |inst[24:20] ? regs[inst[24:20]] : 0;
	wire[31:0] rs2_imm = inst[5] ? rs2 : {{20{inst[31]}}, inst[31:20]};

	wire cmp_lts = signed'(rs1) < signed'(rs2_imm);
	wire cmp_ltu = rs1 < rs2_imm;
	wire cmp = inst[12] ^ (
		inst[14:13] == 'b10 ? cmp_lts :
		inst[14:13] == 'b11 ? cmp_ltu :
		inst[14:13] == 'b00 ? rs1 == rs2_imm :
		'x
	);

	wire[31:0] alu = (
		inst[14:12] == 'b000 ? (inst[5] & inst[30] ? rs1 - rs2_imm : rs1 + rs2_imm) :
		inst[14:12] == 'b010 ? {31'b0, cmp_lts} :
		inst[14:12] == 'b011 ? {31'b0, cmp_ltu} :
		inst[14:12] == 'b100 ? rs1 ^ rs2_imm :
		inst[14:12] == 'b110 ? rs1 | rs2_imm :
		inst[14:12] == 'b111 ? rs1 & rs2_imm :
		inst[14:12] == 'b001 ? rs1 << rs2_imm[4:0] :
		inst[14:12] == 'b101 ? 32'(signed'({inst[30] & rs1[31], rs1}) >>> rs2_imm[4:0]) :
		'x
	);

	wire[31:0] addr_reg = (
		inst[6:2] == OpLoad   |
		inst[6:2] == OpStore  |
		inst[6:2] == OpJalr   ? rs1 :
		inst[6:2] == OpAuipc  |
		inst[6:2] == OpJal    |
		inst[6:2] == OpBranch ? {pc, 2'b0} :
		inst[6:2] == OpLui    ? 0 :
		'x
	);
	wire[31:0] addr_imm = (
		inst[6:2] == OpLui    |
		inst[6:2] == OpAuipc  ? {inst[31:12], 12'b0} :
		inst[6:2] == OpLoad   |
		inst[6:2] == OpJalr   ? {{20{inst[31]}}, inst[31:20]} :
		inst[6:2] == OpStore  ? {{20{inst[31]}}, inst[31:25], inst[11:7]} :
		inst[6:2] == OpJal    ? {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0} :
		inst[6:2] == OpBranch ? {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0} :
		'x
	);
	wire[31:0] addr = addr_reg + addr_imm;

	wire[29:0] pc_succ = pc + 1;

	wire[31:0] load_value_s = bus_data_r >> {load_align, 3'b0};
	wire[31:0] load_value = (
		load_inst[13:12] == 'b00 ? {load_inst[14] ? 24'b0 : {24{load_value_s[ 7]}}, load_value_s[ 7:0]} :
		load_inst[13:12] == 'b01 ? {load_inst[14] ? 16'b0 : {16{load_value_s[15]}}, load_value_s[15:0]} :
		load_inst[13:12] == 'b10 ? load_value_s :
		'x
	);

	wire is_exec = ~reset & state[StExec];
	wire[2:0] next_state = (
		is_exec & inst[6:2] == OpLoad  ? 1 << StLoad :
		is_exec & inst[6:2] == OpStore ? 1 << StWait :
		1 << StExec
	);

	assign bus_data_w = rs2 << {addr[1:0], 3'b0};
	assign bus_mask_w = (
		is_exec & inst[6:2] == OpStore ? {inst[13], inst[13], inst[13] | inst[12], 1'b1} << addr[1:0] : 0
	);
	assign bus_addr = (
		reset ? 0 :
		state[StExec] & (
			 inst[6:2] == OpLoad   |
			 inst[6:2] == OpStore  |
			 inst[6:2] == OpJal    |
			 inst[6:2] == OpJalr   |
			(inst[6:2] == OpBranch & cmp)
		) ? addr[31:2] : pc_succ
	);

	always_ff @(posedge clock) begin
		load_inst  <= inst[14:7];
		load_align <= addr[1:0];
		state      <= next_state;

		if (reset) begin
			pc <= 0;
		end
		else unique case (1)
			state[StLoad]: begin
				regs[rdi] <= load_value;
				pc <= pc_succ;
			end
			state[StWait]: begin
				pc <= pc_succ;
			end
			state[StExec]: unique case (inst[6:2])
				OpLui, OpAuipc: begin
					regs[rdi] <= addr;
					pc <= pc_succ;
				end
				OpRegImm, OpRegReg: begin
					regs[rdi] <= alu;
					pc <= pc_succ;
				end
				OpLoad, OpStore: begin
				end
				OpJal, OpJalr: begin
					regs[rdi] <= {pc_succ, 2'b0};
					pc <= addr[31:2];
				end
				OpBranch: begin
					pc <= cmp ? addr[31:2] : pc_succ;
				end
				default: begin
					pc <= pc_succ;
				end
			endcase
		endcase
	end
endmodule
