`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2019/10/10 07:08:59
// Design Name: 
// Module Name: divide_controller
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


module divide_controller(
	input		  clk,
	input		  reset,
	input 		  div_en,			// 表示此刻是否是除法指令
	input 		  use_sign, 		// 表示此刻的除法是不是带符号除法
	input  [31:0] dividend,
	input  [31:0] divisor,
	output [31:0] div_result_hi,
	output [31:0] div_result_lo,
	output 		  div_finished		// 表示除法运算完毕

    );

wire dividend_sign;
wire divisor_sign;
wire quotient_sign;
wire remainder_sign;


wire [31:0] abs_dividend;
wire [31:0] abs_divisor;
wire [31:0] tmp_quotient;		// 商
wire [31:0] tmp_remainder;		// 余数
wire [63:0] tmp_out;

wire [31:0] input_dividend;
wire [31:0] input_divisor;


wire dividend_ready;
wire divisor_ready;
wire out_valid;

reg dividend_valid;
reg divisor_valid;
reg has_handshaked;
reg [5:0] clk_counter;



assign dividend_sign  = dividend[31];
assign divisor_sign   = divisor[31];
assign quotient_sign  = divisor_sign ^ dividend_sign;
assign remainder_sign = dividend_sign;


assign abs_dividend  = (dividend ^ {32{dividend_sign}}) + dividend_sign;
assign abs_divisor   = (divisor  ^ {32{divisor_sign}})  + divisor_sign;

assign input_dividend = (use_sign)? abs_dividend : dividend;
assign input_divisor  = (use_sign)? abs_divisor  : divisor;

assign {tmp_quotient, tmp_remainder} = (out_valid)? tmp_out : 0 ;
//assign div_result_hi = (out_valid)? ((tmp_remainder ^ remainder_sign) + remainder_sign) : 0 ;
//assign div_result_lo = (out_valid)? ((tmp_quotient  ^ quotient_sign)  + quotient_sign)  : 0 ;
assign div_result_hi = (!out_valid)? 0 :
					   (use_sign)  ? ((tmp_remainder ^ {32{remainder_sign}}) + remainder_sign) : tmp_remainder;
assign div_result_lo = (!out_valid)? 0 :
					   (use_sign)  ? ((tmp_quotient  ^ {32{quotient_sign}})  + quotient_sign)  : tmp_quotient;

assign div_finished = (clk_counter >= 8)? out_valid : 0;


divider d1(
	.aclk(clk),
	.s_axis_dividend_tdata(input_dividend),
	.s_axis_divisor_tdata(input_divisor),
	.m_axis_dout_tdata(tmp_out),
	
	.s_axis_dividend_tvalid(dividend_valid),
	.s_axis_dividend_tready(dividend_ready),
	.s_axis_divisor_tvalid(divisor_valid),
	.s_axis_divisor_tready(divisor_ready),
	.m_axis_dout_tvalid(out_valid)
	);


always @(posedge clk) 
begin
	if (reset) begin
		// reset
		dividend_valid <= 1'b0;
	end
	else if (div_en)
	begin
		if(!dividend_ready & !has_handshaked)
			dividend_valid <= 1'b1;
		else
			dividend_valid <= 1'b0;
	end
	else
		dividend_valid <= 1'b0;
end

always @(posedge clk) 
begin
	if (reset) 
	begin
		// reset
		divisor_valid <= 1'b0;
	end
	else if (div_en)
	begin
		if(!divisor_ready & !has_handshaked)
			divisor_valid <= 1'b1;
		else
			divisor_valid <= 1'b0;
	end
	else
		divisor_valid <= 1'b0;
end

always @(posedge clk) 
begin
	if (reset) 
	begin
		has_handshaked <= 1'b0; // reset
		
	end
	else if (!div_en) 
	begin
		has_handshaked <= 1'b0;
	end
	else if (div_en & divisor_valid & divisor_ready)
		has_handshaked <= 1'b1;
end

always @(posedge clk) 
begin
	if (reset) begin
		clk_counter <= 6'b0;	// reset
		
	end
	else if (has_handshaked) 
	begin
		clk_counter <= clk_counter + 1;
	end
	else 
	begin
		clk_counter <= 6'b0;
	end
end

endmodule