module Cpu(
	input  logic       clock,
	input  logic       reset,
	output logic[31:0] bus_addr,
	input  logic[31:0] bus_data_r,
	output logic[31:0] bus_data_w,
	output logic[ 3:0] bus_mask_w
);
	enum logic[1:0] { Execute, Load, Store } state;
	logic[31:0] pc;
	logic[31:0] regs[31:0];
	logic[14:7] load_inst;
	logic[ 1:0] load_align;

	wire[31:2] inst = bus_data_r[31:2];
	wire[ 4:0] rdi = inst[11: 7];
	wire[31:0] rs1 = inst[19:15] == 0 ? 0 : regs[inst[19:15]];
	wire[31:0] rs2 = inst[24:20] == 0 ? 0 : regs[inst[24:20]];
	wire[31:0] rs2_imm = inst[5] ? rs2 : {{20{inst[31]}}, inst[31:20]};

	wire[31:0] alu = (
		inst[14:12] == 'b000 ? (inst[5] & inst[30] ? rs1 - rs2_imm : rs1 + rs2_imm) :
		inst[14:12] == 'b010 ? {31'b0, signed'(rs1) < signed'(rs2_imm)} :
		inst[14:12] == 'b011 ? {31'b0, rs1 < rs2_imm} :
		inst[14:12] == 'b100 ? rs1 ^ rs2_imm :
		inst[14:12] == 'b110 ? rs1 | rs2_imm :
		inst[14:12] == 'b111 ? rs1 & rs2_imm :
		inst[14:12] == 'b001 ? rs1 << rs2_imm[4:0] :
		inst[14:12] == 'b101 ? (inst[30] ? signed'(signed'(rs1) >>> rs2_imm[4:0]) : rs1 >> rs2_imm[4:0]) :
		'x
	);

	wire cmp = (
		inst[14:12] == 'b000 ? rs1 == rs2 :
		inst[14:12] == 'b001 ? rs1 != rs2 :
		inst[14:12] == 'b100 ? signed'(rs1) <  signed'(rs2) :
		inst[14:12] == 'b101 ? signed'(rs1) >= signed'(rs2) :
		inst[14:12] == 'b110 ? rs1 <  rs2 :
		inst[14:12] == 'b111 ? rs1 >= rs2 :
		'x
	);

	wire[31:0] addr_base = (
		inst[6:2] == 'b00000 |
		inst[6:2] == 'b01000 |
		inst[6:2] == 'b11001 ? rs1 :
		inst[6:2] == 'b00101 |
		inst[6:2] == 'b11000 |
		inst[6:2] == 'b11011 ? 4 * pc :
		'x
	);
	wire[31:0] addr_offset = (
		inst[6:2] == 'b00000 |
		inst[6:2] == 'b11001 ? {{20{inst[31]}}, inst[31:20]} :
		inst[6:2] == 'b01000 ? {{20{inst[31]}}, inst[31:25], inst[11:7]} :
		inst[6:2] == 'b00101 ? {inst[31:12], 12'b0} :
		inst[6:2] == 'b11000 ? {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0} :
		inst[6:2] == 'b11011 ? {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0} :
		'x
	);
	wire[31:0] addr = addr_base + addr_offset;

	wire[ 7:0] load_value_08 = (
		load_align == 0 ? bus_data_r[ 7: 0] :
		load_align == 1 ? bus_data_r[15: 8] :
		load_align == 2 ? bus_data_r[23:16] :
		load_align == 3 ? bus_data_r[31:24] :
		'x
	);
	wire[15:0] load_value_16 = (
		load_align == 0 ? bus_data_r[15: 0] :
		load_align == 2 ? bus_data_r[31:16] :
		'x
	);
	wire[31:0] load_value = (
		load_inst[13:12] == 'b00 ? {load_inst[14] ? 24'b0 : {24{load_value_08[ 7]}}, load_value_08} :
		load_inst[13:12] == 'b01 ? {load_inst[14] ? 16'b0 : {16{load_value_16[15]}}, load_value_16} :
		load_inst[13:12] == 'b10 ? bus_data_r :
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
				regs[load_inst[11:7]] <= load_value;
				bus_addr <= pc + 1;
				pc <= pc + 1;
				state <= Execute;
			end
			Store: begin
				bus_mask_w <= 0;
				bus_addr <= pc + 1;
				pc <= pc + 1;
				state <= Execute;
			end
			Execute: case (inst[6:2])
				'b01101: begin // lui
					regs[rdi] <= {inst[31:12], 12'b0};
					bus_addr <= pc + 1;
					pc <= pc + 1;
					state <= Execute;
				end
				'b00101: begin // auipc
					regs[rdi] <= addr;
					bus_addr <= pc + 1;
					pc <= pc + 1;
					state <= Execute;
				end
				'b00100: begin // op reg reg imm
					regs[rdi] <= alu;
					bus_addr <= pc + 1;
					pc <= pc + 1;
					state <= Execute;
				end
				'b01100: begin // op reg reg reg
					regs[rdi] <= alu;
					bus_addr <= pc + 1;
					pc <= pc + 1;
					state <= Execute;
				end
				'b00000: begin // l*
					load_inst <= inst[14:7];
					load_align <= addr[1:0];
					bus_addr <= addr / 4;
					state <= Load;
				end
				'b01000: begin // s*
					bus_mask_w <= (
						inst[13:12] == 'b00 ? 'b1  << addr[1:0] :
						inst[13:12] == 'b01 ? 'b11 << addr[1:0] :
						inst[13:12] == 'b10 ? 'b1111 :
						'x
					);
					bus_data_w <= rs2 << (8 * addr[1:0]);
					bus_addr <= addr / 4;
					state <= Store;
				end
				'b11011, 'b11001: begin // jal*
					regs[rdi] <= 4 * (pc + 1);
					bus_addr <= addr / 4;
					pc <= addr / 4;
					state <= Execute;
				end
				'b11000: begin // b*
					bus_addr <= cmp ? addr / 4 : pc + 1;
					pc <= cmp ? addr / 4 : pc + 1;
					state <= Execute;
				end
				default: begin
					bus_addr <= pc + 1;
					pc <= pc + 1;
					state <= Execute;
				end
			endcase
			default: begin
				// assert (0);
			end
		endcase
	end
endmodule
