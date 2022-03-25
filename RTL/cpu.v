//Module: CPU
//Function: CPU is the top design of the RISC-V processor

//Inputs:
//	clk: main clock
//	arst_n: reset 
// enable: Starts the execution
//	addr_ext: Address for reading/writing content to Instruction Memory
//	wen_ext: Write enable for Instruction Memory
// ren_ext: Read enable for Instruction Memory
//	wdata_ext: Write word for Instruction Memory
//	addr_ext_2: Address for reading/writing content to Data Memory
//	wen_ext_2: Write enable for Data Memory
// ren_ext_2: Read enable for Data Memory
//	wdata_ext_2: Write word for Data Memory

// Outputs:
//	rdata_ext: Read data from Instruction Memory
//	rdata_ext_2: Read data from Data Memory



module cpu(
		input  wire			  clk,
		input  wire         arst_n,
		input  wire         enable,
		input  wire	[63:0]  addr_ext,
		input  wire         wen_ext,
		input  wire         ren_ext,
		input  wire [31:0]  wdata_ext,
		input  wire	[63:0]  addr_ext_2,
		input  wire         wen_ext_2,
		input  wire         ren_ext_2,
		input  wire [63:0]  wdata_ext_2,
		
		output wire	[31:0]  rdata_ext,
		output wire	[63:0]  rdata_ext_2

   );

wire              zero_flag;
wire [      63:0] branch_pc,updated_pc,current_pc,jump_pc;
wire [      31:0] instruction, instruction_IF_ID, instruction_MEM_WB, instruction_ID_EX, instruction_EX_MEM;
wire [       1:0] alu_op;
wire [       3:0] alu_control;
wire              reg_dst,branch,mem_read,mem_2_reg,
                  mem_write,alu_src, reg_write, jump;
wire [       4:0] regfile_waddr;
wire [      63:0] regfile_wdata,mem_data,alu_out,
                  regfile_rdata_1,regfile_rdata_2,
                  alu_operand_2;

wire signed [63:0] immediate_extended;

immediate_extend_unit immediate_extend_u(
    .instruction         (instruction),
    .immediate_extended  (immediate_extended)
);


// IF STAGE BEGIN
wire [      31:0] instruction, instruction_IF_ID, instruction_MEM_WB;

pc #(
   .DATA_W(64)
) program_counter (
   .clk       (clk       ),
   .arst_n    (arst_n    ),
   .branch_pc (branch_pc ),
   .jump_pc   (jump_pc   ),
   .zero_flag (zero_flag ),
   .branch    (branch    ),
   .jump      (jump      ),
   .current_pc(current_pc),
   .enable    (enable    ),
   .updated_pc(updated_pc)
);

// The instruction memory.
sram_BW32 #(
   .ADDR_W(9 ),
   .DATA_W(32)
) instruction_memory(
   .clk      (clk           ),
   .addr     (current_pc    ),
   .wen      (1'b0          ),
   .ren      (1'b1          ),
   .wdata    (32'b0         ),
   .rdata    (instruction   ),   
   .addr_ext (addr_ext      ),
   .wen_ext  (wen_ext       ), 
   .ren_ext  (ren_ext       ),
   .wdata_ext(wdata_ext     ),
   .rdata_ext(rdata_ext     )
);

//...// IF STAGE END

// IF_ID REG BEGIN
// IF_ID Pipeline register for instruction signal
reg_arstn_en#(
	.DATA_W(32)
) signal_pipe_IF_ID(
	.clk 	(clk				),
	.arst_n	(arst_n				),
	.din	(instruction		),
	.en		(enable				),
	.d_out	(instruction_IF_ID	)
);
//...// IF_ID REG END


// ID STAGE BEGIN
wire [      31:0] instruction_IF_ID, instruction_ID_EX, instruction_MEM_WB;


register_file #(
   .DATA_W(64)
) register_file(
   .clk      (clk               ),
   .arst_n   (arst_n            ),
   .reg_write(reg_write         ),
   .raddr_1  (instruction_IF_ID[19:15]),
   .raddr_2  (instruction_IF_ID[24:20]),
   .waddr    (instruction_MEM_WB[11:7] ),
   .wdata    (regfile_wdata     ),
   .rdata_1  (regfile_rdata_1   ),
   .rdata_2  (regfile_rdata_2   )
);

control_unit control_unit(
   .opcode   (instruction_IF_ID[6:0]),
   .alu_op   (alu_op          ),
   .reg_dst  (reg_dst         ),
   .branch   (branch          ),
   .mem_read (mem_read        ),
   .mem_2_reg(mem_2_reg       ),
   .mem_write(mem_write       ),
   .alu_src  (alu_src         ),
   .reg_write(reg_write       ),
   .jump     (jump            )
);
//...// ID STAGE END

// ID_EX REG BEGIN
// ID_EX Pipeline register for instruction signal
reg_arstn_en#(
	.DATA_W(32)
) signal_pipe_ID_EX(
	.clk 	(clk				),
	.arst_n	(arst_n				),
	.din	(instruction_IF_ID		),
	.en		(enable				),
	.d_out	(instruction_ID_EX	)
);
//...// ID_EX REG END


// EX STAGE BEGIN
wire [      31:0] instruction_EX_MEM, instruction_MEM_WB;
alu#(
   .DATA_W(64)
) alu(
   .alu_in_0 (regfile_rdata_1 ),
   .alu_in_1 (alu_operand_2   ),
   .alu_ctrl (alu_control     ),
   .alu_out  (alu_out         ),
   .zero_flag(zero_flag       ),
   .overflow (                )
);

mux_2 #(
   .DATA_W(64)
) regfile_data_mux (
   .input_a  (mem_data     ),
   .input_b  (alu_out      ),
   .select_a (mem_2_reg    ),
   .mux_out  (regfile_wdata)
);


alu_control alu_ctrl(
   .func7          (instruction_ID_EX[31:25]),
   .func3          (instruction_ID_EX[14:12]),
   .alu_op         (alu_op            ),
   .alu_control    (alu_control       )
);

//...// EX STAGE END


// EX_MEM REG BEGIN
// EX_MEM Pipeline register for instruction signal
reg_arstn_en#(
	.DATA_W(32)
) signal_pipe_EX_MEM(
	.clk 	(clk				),
	.arst_n	(arst_n				),
	.din	(instruction_ID_EX		),
	.en		(enable				),
	.d_out	(instruction_EX_MEM	)
);
//...// EX_MEM REG END


// MEM STAGE BEGIN
wire [      31:0] instruction_EX_MEM, instruction_MEM_WB, instruction_IF_ID;
// The data memory.
sram_BW64 #(
   .ADDR_W(10),
   .DATA_W(64)
) data_memory(
   .clk      (clk            ),
   .addr     (alu_out        ),
   .wen      (mem_write      ),
   .ren      (mem_read       ),
   .wdata    (regfile_rdata_2),
   .rdata    (mem_data       ),   
   .addr_ext (addr_ext_2     ),
   .wen_ext  (wen_ext_2      ),
   .ren_ext  (ren_ext_2      ),
   .wdata_ext(wdata_ext_2    ),
   .rdata_ext(rdata_ext_2    )
);


branch_unit#(
   .DATA_W(64)
)branch_unit(
   .updated_pc         (updated_pc        ),
   .immediate_extended (immediate_extended),
   .branch_pc          (branch_pc         ),
   .jump_pc            (jump_pc           )
);
//...// MEM STAGE END

// EX_MEM REG BEGIN
// EX_MEM Pipeline register for instruction signal
reg_arstn_en#(
	.DATA_W(32)
) signal_pipe_MEM_WB(
	.clk 	(clk				),
	.arst_n	(arst_n				),
	.din	(instruction_EX_MEM		),
	.en		(enable				),
	.d_out	(instruction_MEM_WB	)
);
//...// EX_MEM REG END


// WB STAGE BEGIN
wire [      31:0] instruction_MEM_WB, instruction;
mux_2 #(
   .DATA_W(64)
) alu_operand_mux (
   .input_a (immediate_extended),
   .input_b (regfile_rdata_2    ),
   .select_a(alu_src           ),
   .mux_out (alu_operand_2     )
);
//...// WB STAGE END


// MEM_WB REG BEGIN
// MEM_WB Pipeline register for instruction signal
reg_arstn_en#(
	.DATA_W(32)
) signal_pipe_MEM_WB(
	.clk 	(clk				),
	.arst_n	(arst_n				),
	.din	(instruction_MEM_WB		),
	.en		(enable				),
	.d_out	(instruction	)
);
//...// MEM_WB REG END



endmodule

























