module forward_unit #(	parameter integer DATA_W = 64	)
(
	input wire [DATA_W-1:0] rs1, rs2,
	input wire [DATA_W-1:0] rd_EX_MEM, rd_MEM_WB,
	//ex_mem writeback control signals
	input wire reg_write_EX_MEM,
	
	//mem_wb writeback control signals
	input wire reg_write_MEM_WB,

	output reg [1:0] op1_sel, op2_sel
);

	always @(*) begin
	//default:
	op1_sel = 2'b00;
	op2_sel = 2'b00;

	if(rd_EX_MEM == rs1 && reg_write_EX_MEM) begin
		op1_sel = 2'b10; //op1 = alu_out_EX_MEM
	end else if(rd_MEM_WB == rs1 && reg_write_MEM_WB) begin
		op1_sel = 2'b01; //op1 = regfile_data
	end

	if(rd_EX_MEM == rs2 && reg_write_EX_MEM) begin
		op2_sel = 2'b10; //op2 = alu_out_EX_MEM
	end else if(rd_MEM_WB == rs2 && reg_write_MEM_WB) begin
		op2_sel = 2'b01; //op2 = regfile_data
	end

	end

endmodule
