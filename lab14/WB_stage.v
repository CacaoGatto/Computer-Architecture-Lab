`include "mycpu.h"

module wb_stage#
(
    parameter TLBNUM = 16
)
(
    input  [ 5:0]                   ext_int_in    ,
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [36:0]                   back_to_mem_stage_bus_from_wb,
    output [31:0]                   debug_wb_pc     ,
    output [ 3:0]                   debug_wb_rf_wen ,
    output [ 4:0]                   debug_wb_rf_wnum,
    output [31:0]                   debug_wb_rf_wdata,
    output [`EXECEPTION_BUS_WD-1:0] exception_bus,
    //output [`WS_TO_FS_BUS_WD -1:0]  ws_to_fs_bus,
    //output [`WS_TO_ES_BUS_WD -1:0] ws_to_es_bus,
    output [`WS_CP0_BUS_WD -1:0]  ws_cp0_bus,

    // tlb
    // write port
    output                       we         ,
    output  [$clog2(TLBNUM)-1:0] w_index    ,
    output  [              18:0] w_vpn2     ,
    output  [               7:0] w_asid     ,
    output                       w_g        ,
    output  [              19:0] w_pfn0     ,
    output  [               2:0] w_c0       ,
    output                       w_d0       ,
    output                       w_v0       ,
    output  [              19:0] w_pfn1     ,
    output  [               2:0] w_c1       ,
    output                       w_d1       ,
    output                       w_v1       ,
    // read port
    output [$clog2(TLBNUM)-1:0] r_index    ,
    input  [              18:0] r_vpn2     ,
    input  [               7:0] r_asid     ,
    input                       r_g        ,
    input  [              19:0] r_pfn0     ,
    input  [               2:0] r_c0       ,
    input                       r_d0       ,
    input                       r_v0       ,
    input  [              19:0] r_pfn1     ,
    input  [               2:0] r_c1       ,
    input                       r_d1       ,
    input                       r_v1

);

reg         ws_valid;
wire        ws_ready_go;

reg [ 4:0]  ws_dest_r;
reg [31:0]  ws_final_result_r;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire [31:0] ws_final_result_from_mem;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

wire        ws_inst_mfc0; // prj8 added
wire        ws_inst_mtc0; // prj8 added
wire        ws_inst_eret; // prj8 added

wire [7:0]  ws_cp0_addr;  // prj8 added
wire [31:0] ws_cp0_wdata; // prj8 added
wire [31:0] ws_cp0_rdata; // prj8 added

wire [14:0] ws_exception;       // prj9 added, prj14 extended from 7 to 14
wire [31:0] ws_cp0_rdata_final; // prj13 added
wire [7:0]  ws_cp0_final_addr;  // prj14 added
wire        ws_exception_tlb;   // prj14 added

wire        ws_exception_addr_if; //prj14 added for all inst addr exception.

/*
wire        exception_adel_if;  // prj9 added
wire        exception_adel_exe; // prj9 added
wire        exception_syscall;  // prj9 added
wire        exception_break;    // prj9 added
wire        exception_ades;     // prj9 added
wire        exception_overflow; // prj9 added
wire        exception_rsv;      // prj9 added
wire        exception_int;      // prj9 added
*/

wire        ws_in_slot;   // prj8 added
wire        flush;        // prj8 added
//reg         flush;        // prj8 added
wire [31:0] new_pc;       // prj8 added
wire [4:0]  wb_exccode;   // prj8 added
wire        mtc0_we;      // prj8 added
wire        wb_ex;        // prj9 added
wire        wb_has_int;   // prj9 added

wire [31:0] bad_vaddr_from_mem; //prj9 added
wire [31:0] wb_BadVaddr;

//prj13 added
wire [31:0] cp0_entryhi;
wire [31:0] cp0_entrylo0;
wire [31:0] cp0_entrylo1;
wire [31:0] cp0_index;
wire        ws_inst_tlbp;
wire        ws_inst_tlbr;
wire        ws_inst_tlbwi;
wire        ws_after_tlb;
reg         previous_inst_is_tlb;

assign exception_bus = {flush,
                        new_pc,
                        wb_has_int
                        };
/*
assign ws_exception = {exception_int,
                       exception_adel_if,
                       exception_adel_exe,
                       exception_rsv,
                       exception_overflow,   
                       exception_syscall,
                       exception_break,
                       exception_ades
                      };
*/

assign flush = (!ws_valid)? 0 :
               (ws_exception != 15'b0)? 1 : 
               (ws_inst_eret)? 1 : 
               (ws_after_tlb && previous_inst_is_tlb)? 1 : 0;

assign new_pc = (ws_exception_tlb_refill/* & ~ws_cp0_rdata[1]*/) ? 32'hbfc00200 : 
                (ws_exception != 15'b0) ? 32'hbfc00380 : 
                (ws_inst_eret)? ws_cp0_rdata_final :
                (ws_after_tlb && previous_inst_is_tlb)? ws_pc : 0;

/*
assign {bad_vaddr_from_mem,         //121:90
        ws_in_slot     ,            //89:89
        exception_int,              //88:88
        exception_adel_if,          //87:87
        exception_adel_exe,         //86:86
        exception_rsv,              //85:85
        exception_overflow,         //84:84
        exception_syscall,          //83:83
        exception_break,            //82:82
        exception_ades,             //81:81
        ws_cp0_addr    ,            //80:73
        ws_inst_eret   ,            //72:72
        ws_inst_mfc0   ,            //71:71
        ws_inst_mtc0   ,            //70:70
        ws_gr_we       ,            //69:69
        ws_dest        ,            //68:64
        ws_final_result_from_mem,   //63:32
        ws_pc                       //31:0
       } = ms_to_ws_bus_r;
*/


assign {//bad_vaddr_from_mem,         //121:90
        ws_after_tlb,               //100:100
        ws_in_slot     ,            //99:99
        ws_exception   ,            //98:84
        ws_cp0_addr    ,            //83:76
        ws_inst_tlbp   ,            //75:75
        ws_inst_tlbr   ,            //74:74
        ws_inst_tlbwi  ,            //73:73
        ws_inst_eret   ,            //72:72
        ws_inst_mfc0   ,            //71:71
        ws_inst_mtc0   ,            //70:70
        ws_gr_we       ,            //69:69
        ws_dest        ,            //68:64
        ws_final_result_from_mem,   //63:32
        ws_pc                       //31:0
       } = ms_to_ws_bus_r;


assign ws_final_result = (ws_inst_mfc0)? ws_cp0_rdata_final : ws_final_result_from_mem;
assign ws_cp0_final_addr = (ws_exception_tlb_refill) ? `STATUS_ADDR : ws_cp0_addr;

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };//给寄存器堆的总线信号

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
/*
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end
*/
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (flush) begin
        ws_valid <= 1'b0;
    end

    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end
end

always @(posedge clk) begin
    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end


always @(posedge clk) begin
    if (reset) begin
        ws_dest_r <= 5'b0;
        ws_final_result_r <= 32'b0;
    end
    else if (ws_valid) begin
        ws_dest_r <= (ws_dest & {5{ws_gr_we}});
        ws_final_result_r <= ws_final_result;
    end
end

assign back_to_mem_stage_bus_from_wb = (ws_valid) ? {(ws_dest & {5{ws_gr_we}}), ws_final_result} :
                                                    {ws_dest_r, ws_final_result_r} ;

assign rf_we    = (flush)? 0 : ws_gr_we && ws_valid; // 如果本级已经查出了例外，不要写寄存器
assign rf_waddr = ws_dest;
assign rf_wdata = ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = ws_final_result;


// cp0 signal
/*
exception:
| interrput | AdEL | reserved | integer overflow | syscall | break | AdES |
*/
//assign wb_exccode = (ws_exception)? 5'b01000 : 5'b00000; // 0x08 => syscall
assign wb_exccode = (ws_exception[14]) ? 5'b00000 :                         //0x00 => interrupt
                    (ws_exception[13]) ? 5'b00100 :                         //0x04 => AdEL_if
                    (ws_exception[12]) ? 5'b00010 :                         //0x02 => tlbl_refill_if
                    (ws_exception[11]) ? 5'b00010 :                         //0x02 => tlbl_invalid_if
                    (ws_exception[10]) ? 5'b01010 :                         //0x0a => reserved instruction
                    (ws_exception[ 9]) ? 5'b01100 :                         //0x0c => integer overflow
                    (ws_exception[ 8]) ? 5'b01000 :                         //0x08 => syscall
                    (ws_exception[ 7]) ? 5'b01001 :                         //0x09 => break
                    (ws_exception[ 6]) ? 5'b00100 :                         //0x00 => AdEL_exe
                    (ws_exception[ 5]) ? 5'b00101 :                         //0x05 => AdES_exe
                    (ws_exception[ 4]) ? 5'b00010 :                         //0x02 => tlbl_refill_exe
                    (ws_exception[ 3]) ? 5'b00011 :                         //0x03 => tlbs_refill_exe
                    (ws_exception[ 2]) ? 5'b00010 :                         //0x02 => tlbl_invalid_exe
                    (ws_exception[ 1]) ? 5'b00011 :                         //0x03 => tlbs_invalid_exe
                    (ws_exception[ 0]) ? 5'b00001 :                         //0x01 => mod
                                         5'b00000 ;

assign ws_exception_tlb = (|ws_exception[12:11]) | (|ws_exception[4:0]);
assign ws_exception_addr_if = |ws_exception[13:11];
assign ws_exception_tlb_refill = ws_exception[12] | ws_exception[4] | ws_exception[3];

assign mtc0_we     = ws_valid && ws_inst_mtc0 && (~ws_after_tlb);//&& ws_exception; // 暂时先不考虑WB阶段的例外试试
assign wb_ex       = (!ws_valid)? 0 :               // 如果失效的话，例外信号也失效了
                     (ws_exception == 15'b0)? 0 : 1; // 只要有1位出现例外错误就触发wb_ex
assign wb_BadVaddr = (ws_exception_addr_if)? ws_pc : ws_final_result_from_mem; // bad_vaddr的两个来源。优先级高点的是if级产生的badvaddr，其次再考虑exe级产生的badvaddr

assign ws_cp0_wdata = ws_final_result;

/*
assign ws_to_fs_bus = {
                        cp0_entryhi
};
*/
always @(posedge clk) 
begin
  if (reset) 
  begin
    // reset
    previous_inst_is_tlb <= 1'b0;
  end
  else if (flush)
  begin
    previous_inst_is_tlb <= 1'b0;
  end

  else if (ws_allowin && ms_to_ws_valid) 
  begin
    previous_inst_is_tlb <= (ws_inst_tlbwi | ws_inst_tlbr);
  end
end

/****************************************normal cp0 register****************************************/

cp0 c0(
    .clk(clk),
    .rst(reset),
    .mtc0_we(mtc0_we),
    .cp0_wdata(ws_cp0_wdata),
    .cp0_addr(ws_cp0_addr),
    .eret_flush(ws_inst_eret),
    .wb_ex(wb_ex),
    .wb_exccode(wb_exccode),
    .wb_bd(ws_in_slot),
    .wb_pc(ws_pc),
    .ext_int_in(ext_int_in),  // 暂时用不到
    .wb_BadVaddr(wb_BadVaddr),
    .cp0_rdata(ws_cp0_rdata),
    .has_int(wb_has_int)
    );

// 由于有外部cp0寄存器，因此这里还需考虑mfc0的读地址是外部4个寄存器的情况
assign ws_cp0_rdata_final = (ws_inst_eret)?  ws_cp0_rdata :
                            (ws_cp0_addr == `ENTRYHI_ADDR)?  cp0_entryhi :
                            (ws_cp0_addr == `ENTRYLO0_ADDR)? cp0_entrylo0:
                            (ws_cp0_addr == `ENTRYLO1_ADDR)? cp0_entrylo1:
                            (ws_cp0_addr == `INDEX_ADDR)?    cp0_index   : ws_cp0_rdata;

assign ws_cp0_bus   = {
                        cp0_entryhi, //41:10
                        ws_valid,       //9:9
                        ws_inst_mtc0,   //8:8
                        ws_cp0_addr     //7:0
                      };


/****************************************entryhi****************************************/
/*
|VPN2   |0      |ASID   |
|31:13  |12:8   |7:0    |
*/

reg [18: 0] cp0_entryhi_vpn2;
reg [ 7: 0] cp0_entryhi_asid;

assign cp0_entryhi = {
                      cp0_entryhi_vpn2,
                      5'b0,
                      cp0_entryhi_asid
                     };

//vpn2
always @(posedge clk) 
begin
    if (reset) begin
        // reset
        cp0_entryhi_vpn2 <= 19'b0;
    end
    
    else if (ws_exception_tlb && ws_valid)
    begin
        cp0_entryhi_vpn2 <= wb_BadVaddr[31:13];
    end
    
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entryhi_vpn2 <= r_vpn2;
    end

    else if (mtc0_we && (ws_cp0_addr == `ENTRYHI_ADDR))
    begin
        cp0_entryhi_vpn2 <= ws_cp0_wdata[31:13];
    end
end

//asid
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entryhi_asid <= 8'b0;    
    end
//    else if (ws_exception_tlb && ws_valid)
//    begin
        
//    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entryhi_asid <= r_asid; 
    end
    else if(mtc0_we && (ws_cp0_addr == `ENTRYHI_ADDR))
    begin
        cp0_entryhi_asid <= ws_cp0_wdata[7:0];
    end
end
/****************************************entrylo0****************************************/
/*
|0      |PFN0   |C0 |D0 |V0 |G0 |
|31:26  |25:6   |5:3|2  |1  |0  |
*/

reg [19: 0] cp0_entrylo0_pfn0;
reg [ 2: 0] cp0_entrylo0_c0;
reg         cp0_entrylo0_d0;
reg         cp0_entrylo0_v0;
reg         cp0_entrylo0_g0;

//pfn0
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo0_pfn0 <= 20'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo0_pfn0 <= r_pfn0;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO0_ADDR)) 
    begin
        cp0_entrylo0_pfn0 <= ws_cp0_wdata[25:6];
    end
end

//c0
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo0_c0 <= 3'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo0_c0 <= r_c0;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO0_ADDR)) 
    begin
        cp0_entrylo0_c0 <= ws_cp0_wdata[5:3];
    end
end

//d0
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo0_d0 <= 1'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo0_d0 <= r_d0;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO0_ADDR)) 
    begin
        cp0_entrylo0_d0 <= ws_cp0_wdata[2];
    end
end

//v0
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo0_v0 <= 1'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo0_v0 <= r_v0;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO0_ADDR)) 
    begin
        cp0_entrylo0_v0 <= ws_cp0_wdata[1];
    end
end

//g0
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo0_g0 <= 1'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo0_g0 <= r_g;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO0_ADDR)) 
    begin
        cp0_entrylo0_g0 <= ws_cp0_wdata[0];
    end
end


assign cp0_entrylo0 = {6'b0,
                       cp0_entrylo0_pfn0,
                       cp0_entrylo0_c0,
                       cp0_entrylo0_d0,
                       cp0_entrylo0_v0,
                       cp0_entrylo0_g0
                      };        


/****************************************entrylo1****************************************/
/*
|0      |PFN1   |C1 |D1 |V1 |G1 |
|31:26  |25:6   |5:3|2  |1  |0  |
*/

reg [19: 0] cp0_entrylo1_pfn1;
reg [ 2: 0] cp0_entrylo1_c1;
reg         cp0_entrylo1_d1;
reg         cp0_entrylo1_v1;
reg         cp0_entrylo1_g1;

//pfn1
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo1_pfn1 <= 20'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo1_pfn1 <= r_pfn1;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO1_ADDR)) 
    begin
        cp0_entrylo1_pfn1 <= ws_cp0_wdata[25:6];
    end
end

//c1
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo1_c1 <= 3'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo1_c1 <= r_c1;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO1_ADDR)) 
    begin
        cp0_entrylo1_c1 <= ws_cp0_wdata[5:3];
    end
end

//d1
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo1_d1 <= 1'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo1_d1 <= r_d1;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO1_ADDR)) 
    begin
        cp0_entrylo1_d1 <= ws_cp0_wdata[2];
    end
end

//v1
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo1_v1 <= 1'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo1_v1 <= r_v1;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO1_ADDR)) 
    begin
        cp0_entrylo1_v1 <= ws_cp0_wdata[1];
    end
end

//g1
always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_entrylo1_g1 <= 1'b0;
    end
    else if (ws_inst_tlbr && ws_valid) 
    begin
        cp0_entrylo1_g1 <= r_g;
    end
    else if (mtc0_we && (ws_cp0_addr == `ENTRYLO1_ADDR)) 
    begin
        cp0_entrylo1_g1 <= ws_cp0_wdata[0];
    end
end


assign cp0_entrylo1 = {6'b0,
                       cp0_entrylo1_pfn1,
                       cp0_entrylo1_c1,
                       cp0_entrylo1_d1,
                       cp0_entrylo1_v1,
                       cp0_entrylo1_g1
                      };        

/****************************************index****************************************/
/*
|P  |0      |INDEX  |
|31 |30:4   |3:0    |
*/
reg         cp0_index_p;
reg [ 3: 0] cp0_index_index;

always @(posedge clk) 
begin
    if (reset) 
    begin
        cp0_index_p <= 1'b0;// reset
    end
    else if (ws_inst_tlbp && ws_valid) 
    begin
        cp0_index_p <= ws_final_result_from_mem[31];
    end
    /*else if (mtc0_we && (ws_cp0_addr == `INDEX_ADDR)) 
    begin
        cp0_index_p <= ws_cp0_wdata[31];
    end*/
end

always @(posedge clk) 
begin
    if (reset) 
    begin
        // reset
        cp0_index_index <= 4'b0;    
    end
    else if (ws_inst_tlbp && ws_valid) 
    begin
        cp0_index_index <= ws_final_result_from_mem[3:0];
    end
    else if (mtc0_we && (ws_cp0_addr == `INDEX_ADDR)) 
    begin
        cp0_index_index <= ws_cp0_wdata[3:0];
    end
end


assign cp0_index = {cp0_index_p,
                    27'b0,
                    cp0_index_index
                   };



//tlbwi
assign we       = (flush)? 1'b0 : (ws_inst_tlbwi & ws_valid);
assign w_index  = cp0_index;
assign w_vpn2   = cp0_entryhi_vpn2;
assign w_asid   = cp0_entryhi_asid;
assign w_g      = cp0_entrylo0_g0 & cp0_entrylo1_g1;
assign w_pfn0   = cp0_entrylo0_pfn0;
assign w_c0     = cp0_entrylo0_c0;
assign w_d0     = cp0_entrylo0_d0;
assign w_v0     = cp0_entrylo0_v0;
assign w_pfn1   = cp0_entrylo1_pfn1;
assign w_c1     = cp0_entrylo1_c1;
assign w_d1     = cp0_entrylo1_d1;
assign w_v1     = cp0_entrylo1_v1;

//tlbr
assign r_index = cp0_index;


endmodule