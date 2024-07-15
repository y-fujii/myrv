module Cpu(
	input  wire       clock,
	input  wire       reset,
	output reg [29:0] bus_addr,
	input  wire[31:0] bus_data_r,
	output reg [31:0] bus_data_w,
	output reg [ 3:0] bus_mask_w
);
	enum reg[1:0] { Execute, Load, Store } state;
	reg[29:0] pc;
	reg[31:0] regs[31:0];
	reg[14:7] load_inst;
	reg[ 1:0] load_align;

	wire[31:2] inst = bus_data_r[31:2];
	wire[ 4:0] rdi = state == Execute ? inst[11: 7] : load_inst[11:7];
	wire[31:0] rs1 = inst[19:15] == 0 ? 0 : regs[inst[19:15]];
	wire[31:0] rs2 = inst[24:20] == 0 ? 0 : regs[inst[24:20]];
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

	wire[31:0] addr_base = (
		inst[6:2] == 'b00101 |
		inst[6:2] == 'b11011 |
		inst[6:2] == 'b11000 ? {pc, 2'b0} :
		inst[6:2] == 'b00000 |
		inst[6:2] == 'b01000 |
		inst[6:2] == 'b11001 ? rs1 :
		inst[6:2] == 'b01101 ? 0 :
		'x
	);
	wire[31:0] addr_offset = (
		inst[6:2] == 'b01101 |
		inst[6:2] == 'b00101 ? {inst[31:12], 12'b0} :
		inst[6:2] == 'b00000 |
		inst[6:2] == 'b11001 ? {{20{inst[31]}}, inst[31:20]} :
		inst[6:2] == 'b01000 ? {{20{inst[31]}}, inst[31:25], inst[11:7]} :
		inst[6:2] == 'b11011 ? {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0} :
		inst[6:2] == 'b11000 ? {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0} :
		'x
	);
	wire[31:0] addr = addr_base + addr_offset;

	wire[29:0] pc_succ = pc + 1;

	wire[31:0] load_value_s = bus_data_r >> {load_align, 3'b0};
	wire[31:0] load_value = (
		load_inst[13:12] == 'b00 ? {load_inst[14] ? 24'b0 : {24{load_value_s[ 7]}}, load_value_s[ 7:0]} :
		load_inst[13:12] == 'b01 ? {load_inst[14] ? 16'b0 : {16{load_value_s[15]}}, load_value_s[15:0]} :
		load_inst[13:12] == 'b10 ? load_value_s :
		'x
	);

	always_ff @(posedge clock) begin
		if (reset) begin
			bus_mask_w <= 0;
			bus_addr <= 0;
			pc <= 0;
			state <= Execute;
		end else case (state)
			Load: begin
				regs[rdi] <= load_value;
				bus_addr <= pc_succ;
				pc <= pc_succ;
				state <= Execute;
			end
			Store: begin
				bus_mask_w <= 0;
				bus_addr <= pc_succ;
				pc <= pc_succ;
				state <= Execute;
			end
			Execute: case (inst[6:2])
				'b01101, 'b00101: begin // *ui*
					regs[rdi] <= addr;
					bus_addr <= pc_succ;
					pc <= pc_succ;
					state <= Execute;
				end
				'b00100, 'b01100: begin
					regs[rdi] <= alu;
					bus_addr <= pc_succ;
					pc <= pc_succ;
					state <= Execute;
				end
				'b00000: begin // l*
					load_inst <= inst[14:7];
					load_align <= addr[1:0];
					bus_addr <= addr[31:2];
					state <= Load;
				end
				'b01000: begin // s*
					bus_mask_w <= {inst[13], inst[13], inst[13] | inst[12], 1'b1} << addr[1:0];
					bus_data_w <= rs2 << {addr[1:0], 3'b0};
					bus_addr <= addr[31:2];
					state <= Store;
				end
				'b11011, 'b11001: begin // jal*
					regs[rdi] <= {pc_succ, 2'b0};
					bus_addr <= addr[31:2];
					pc <= addr[31:2];
					state <= Execute;
				end
				'b11000: begin // b*
					bus_addr <= cmp ? addr[31:2] : pc_succ;
					pc <= cmp ? addr[31:2] : pc_succ;
					state <= Execute;
				end
				default: begin
					bus_addr <= pc_succ;
					pc <= pc_succ;
					state <= Execute;
				end
			endcase
			default: begin
				// assert (0);
			end
		endcase
	end
endmodule
