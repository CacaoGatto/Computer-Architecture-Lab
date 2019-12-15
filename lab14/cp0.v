`include "mycpu.h"



module cp0(
	input 			clk,
	input 			rst,
	input 			mtc0_we,
	input  [31:0]	cp0_wdata, 
	input  [7:0]	cp0_addr,
	input  			eret_flush,
	input 			wb_ex,
	input  [4:0] 	wb_exccode,
	input 			wb_bd,
	input  [31:0] 	wb_pc,
	input  [5:0]	ext_int_in,
	input  [31:0]	wb_BadVaddr,
	output [31:0]	cp0_rdata,
	output 			has_int
	//output [31:0] 	cp0_status,
	//output [31:0]	cp0_cause,
	//output [31:0]	cp0_epc_wire,
	);
wire [31:0] cp0_status;
wire [31:0] cp0_cause;
wire        count_eq_compare;
reg  [31:0] cp0_epc;
reg  [31:0] cp0_BadVaddr;
reg  [31:0] cp0_count;
reg  [31:0] cp0_compare;

wire       ex_badvaddr;

assign ex_badvaddr = (wb_exccode == 5'b00001) | (wb_exccode == 5'b00101) | (wb_exccode == 5'b00011) | (wb_exccode == 5'b00100) | (wb_exccode == 5'b00010);

//prj13 added
//wire [31:0] cp0_entryhi;
//wire [31:0] cp0_entrylo0;
//wire [31:0] cp0_entrylo1;
//wire [31:0] cp0_index;


/****************************************status****************************************/
/*
|0		|bev|0		|IM7~IM0|0	|EXL|IE |
|31:23	|22	|21:16	|15:8	|7:2|1	|0	|
*/

wire 		cp0_status_bev;
reg [7:0] 	cp0_status_im;
reg 		cp0_status_exl;
reg 		cp0_status_ie;

assign cp0_status = {9'b0,				//31:23
					 cp0_status_bev,	//22
					 6'b0,				//21:16
					 cp0_status_im,		//15:8
					 6'b0,				//7:2
					 cp0_status_exl,	//1
					 cp0_status_ie		//0
					};


assign cp0_status_bev = 1'b1;

always @(posedge clk)
begin
	if(mtc0_we && cp0_addr == `STATUS_ADDR)
		cp0_status_im <= cp0_wdata[15:8];
	
end

always @(posedge clk) 
begin
	if (rst) 
	begin
		// reset
		cp0_status_exl <= 1'b0;	
	end
	else if (wb_ex) 
	begin
		cp0_status_exl <= 1'b1;
	end
	else if (eret_flush)
	begin
		cp0_status_exl <= 1'b0;
	end
	else if (mtc0_we && cp0_addr == `STATUS_ADDR)
	begin
		cp0_status_exl <= cp0_wdata[1];
	end
end

always @(posedge clk)
begin
	if (rst) 
	begin
		// reset
		cp0_status_ie <= 1'b0;
	end
	else if (mtc0_we && cp0_addr == `STATUS_ADDR) 
	begin
		cp0_status_ie <= cp0_wdata[0];
	end
end





/****************************************cause****************************************/
/*
|BD|TI|0		|IP7~IP2|IP1~IP0|0|Exccode	|0		|
|31|30|29:16	|15:10	|9:8	|7|6:2		|1:0	|
*/
reg 		cp0_cause_bd;
reg 		cp0_cause_ti;
reg [7:0]	cp0_cause_ip;
reg [4:0]	cp0_cause_exccode;

assign cp0_cause = {cp0_cause_bd,		//	31
					cp0_cause_ti,		//	30
					14'b0,				//	29:16
					cp0_cause_ip,		//	15:8
					1'b0,				//	7
					cp0_cause_exccode,	//	6:2
					2'b0				//	1:0
					};

always @(posedge clk) 
begin
	if (rst) 
	begin
		// reset
		cp0_cause_bd <= 1'b0;
	end
	else if (wb_ex && !cp0_status_exl) 
	begin
		cp0_cause_bd <= wb_bd;
	end
end

always @(posedge clk) 
begin
	if (rst) 
	begin
		// reset
		cp0_cause_ti <= 1'b0;	
	end
	else if (mtc0_we && cp0_addr == `COMPARE_ADDR) // WARNING: this is not `CAUSE_ADDR
	begin
		cp0_cause_ti <= 1'b0;
	end
	else if (count_eq_compare)
	begin
		cp0_cause_ti <= 1'b1;
	end
end

always @(posedge clk)	// IP7~IP2
begin
	if (rst) 
	begin
		// reset
		cp0_cause_ip[7:2] <= 6'b0;
	end
	else
	begin
		cp0_cause_ip[7] <= ext_int_in[5] | cp0_cause_ti;
		cp0_cause_ip[6:2] <= ext_int_in[4:0];
	end
end

always @(posedge clk)	// IP1 & IP0
begin
	if (rst) 
	begin
		// reset
		cp0_cause_ip[1:0] <= 2'b0;	
	end
	else if (mtc0_we && cp0_addr == `CAUSE_ADDR) 
	begin
		cp0_cause_ip[1:0] <= cp0_wdata[9:8];
	end
end

always @(posedge clk) 
begin
	if (rst) 
	begin
		// reset
		cp0_cause_exccode <= 5'b0;
	end
	else if (wb_ex) 
	begin
		cp0_cause_exccode <= wb_exccode;
	end
end


/****************************************epc****************************************/

//assign cp0_epc_wire = cp0_epc;

always @(posedge clk) 
begin
	if (wb_ex && !cp0_status_exl) 
	begin
		cp0_epc <= wb_bd? wb_pc - 3'h4 : wb_pc;
	end
	else if (mtc0_we && cp0_addr == `EPC_ADDR) 
	begin
		cp0_epc <= cp0_wdata;
	end
end

/****************************************bad_vaddr****************************************/
always @(posedge clk) 
begin
	if (wb_ex && ex_badvaddr)
	begin
		cp0_BadVaddr <= wb_BadVaddr;
	end
end

/****************************************count****************************************/
reg tick;
always @(posedge clk) 
begin
	if (rst) 
	begin
	// reset
		tick <= 1'b0;	
	end
	else
	begin
		tick <= ~tick;
	end
end

always @(posedge clk) 
begin
	if (mtc0_we && cp0_addr == `COUNT_ADDR) 
	begin
	// reset
		cp0_count <= cp0_wdata;	
	end
	else if(tick)
	begin
		cp0_count <= cp0_count + 1;
	end
end


/****************************************compare****************************************/
always @(posedge clk) 
begin
	if (mtc0_we && cp0_addr == `COMPARE_ADDR) 
	begin
		cp0_compare <= cp0_wdata;
	end
end



// to be continued ...



assign cp0_rdata = (cp0_addr == `STATUS_ADDR)   ? cp0_status   :
                   (cp0_addr == `CAUSE_ADDR)    ? cp0_cause    : 
                   (cp0_addr == `BADVADDR_ADDR) ? cp0_BadVaddr : 
                   (cp0_addr == `COUNT_ADDR)    ? cp0_count    : 
                   (cp0_addr == `COMPARE_ADDR)  ? cp0_compare  : cp0_epc;

assign has_int = ((cp0_cause_ip & cp0_status_im)!= 0) && (cp0_status_ie==1'b1) && (cp0_status_exl==1'b0);

assign count_eq_compare = (cp0_count == cp0_compare);
endmodule