`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/09 11:15:29
// Design Name: 
// Module Name: mutiplier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module mutiplier(
	input [31:0] mult1,
	input [31:0] mult2,
	input 		 has_sign,
	output [31:0] mult_result_hi,
	output [31:0] mult_result_lo
    );

	wire [32:0] src1_signed;
	wire [32:0] src2_signed;
	wire [32:0] src1_unsigned;
	wire [32:0] src2_unsigned;
	wire [32:0] src1;
	wire [32:0] src2;
	wire [65:0] tmp_ans;

	assign src1_signed 	 = {mult1[31], mult1};
	assign src2_signed 	 = {mult2[31], mult2};
	assign src1_unsigned = {1'b0, mult1};
	assign src2_unsigned = {1'b0, mult2};
	assign src1 = (has_sign)? src1_signed : src1_unsigned;
	assign src2 = (has_sign)? src2_signed : src2_unsigned;

	assign tmp_ans = $signed(src1) * $signed(src2);
	assign mult_result_hi = tmp_ans[63:32];
	assign mult_result_lo = tmp_ans[31: 0];


endmodule