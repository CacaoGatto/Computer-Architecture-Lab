`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus,
    //阻塞判断信号
    input [39:0] back_to_id_stage_bus_from_exe,
    input [38:0] back_to_id_stage_bus_from_mem

);

reg         ds_valid   ;
wire        ds_ready_go;

wire [31                 :0] fs_pc;
reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;
assign fs_pc = fs_to_ds_bus[31:0];//记录IF阶段传过来的PC值

wire [31:0] ds_inst;//这两个wire是ID阶段专用的instruction和PC 线网
wire [31:0] ds_pc  ;
assign {ds_inst,
        ds_pc  } = fs_to_ds_bus_r;

wire        rf_we   ;//寄存器堆的一堆信号
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_taken;
wire [31:0] br_target;

wire        mem_left;
wire        mem_right;
wire        mem_w;
wire        mem_h;
wire        mem_b;
wire        s_ext;
wire [11:0] alu_op;
wire        load_op;
wire		 store_op;
wire		 base_br_op;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm_symbol_extend;
wire        src2_is_imm_zero_extend;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;

//wire        hi_we;    // prj6 added
//wire        lo_we;    // prj6 added
//wire        div_en;   // prj6 added
//wire        div_sign; // prj6 added


wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_add;       // prj6 added
wire        inst_addu;
wire        inst_sub;       // prj6 added
wire        inst_subu;
wire        inst_slt;
wire        inst_slti;      // prj6 added
wire        inst_sltu;
wire        inst_sltiu;     // prj6 added
wire        inst_and;
wire        inst_andi;      // prj6 added
wire        inst_or;
wire        inst_ori;       // prj6 added
wire        inst_xor;
wire        inst_xori;      // prj6 added
wire        inst_nor;
wire        inst_sll;
wire        inst_sllv;      // prj6 added
wire        inst_srl;
wire        inst_srlv;      // prj6 added
wire        inst_sra;
wire        inst_srav;      // prj6 added

wire        inst_mult;      // prj6 added
wire        inst_multu;     // prj6 added
wire        inst_div;       // prj6 added
wire        inst_divu;      // prj6 added
wire        inst_mfhi;      // prj6 added
wire        inst_mflo;      // prj6 added
wire        inst_mthi;      // prj6 added
wire        inst_mtlo;      // prj6 added

wire        inst_addi;      // prj6 added
wire        inst_addiu;
wire        inst_lui;

wire		 inst_lb;			//prj7 added
wire		 inst_lbu;			//prj7 added
wire		 inst_lh;			//prj7 added
wire		 inst_lhu;			//prj7 added
wire		 inst_lwl;			//prj7 added
wire		 inst_lwr;			//prj7 added
wire        inst_lw;
wire		 inst_sb;			//prj7 added
wire		 inst_sh;			//prj7 added
wire		 inst_swl;			//prj7 added
wire		 inst_swr;			//prj7 added
wire        inst_sw;

wire		 inst_bgez;			//prj7 added
wire		 inst_bgtz;			//prj7 added
wire		 inst_blez;			//prj7 added
wire		 inst_bltz;			//prj7 added
wire        inst_beq;
wire        inst_bne;
wire		 inst_bltzal;			//prj7 added
wire		 inst_bgezal;			//prj7 added
wire        inst_jal;
wire		 inst_jalr;			//prj7 added
wire        inst_jr;
wire		 inst_j;				//prj7 added


wire        dst_is_r31;  
wire        dst_is_rt;   

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire		 rs_ge_z ;
wire		 rs_le_z ;

//用于阻塞与前递
//wire ds_ready_go_about_exe;
//wire ds_ready_go_about_mem;
//wire ds_ready_go_about_wb;
//wire ds_ready_go_about_id_itself;

wire es_load_op;
wire es_valid;
wire es_gr_we;
wire [4:0] es_dest;

wire ms_valid;
wire ms_gr_we;
wire [4:0] ms_dest;

wire [31:0] es_result;
wire [31:0] ms_result;

//wire read_hi;
//wire read_lo;



assign br_bus       = {br_taken,br_target};

assign ds_to_es_bus = {s_ext        ,                   //150:150
                       mem_left     ,                   //149:149
                       mem_right    ,                   //148:148
                       mem_w        ,                   //147:147
                       mem_h        ,                   //146:146
                       mem_b        ,                   //145:145
                       alu_op       ,                   //144:133
                       load_op      ,                   //132:132 //??????????????bug？？？？？？？？？？？？？整个模块这个信号就没有个源头
                       src1_is_sa   ,                   //131:131 //这4个信号或许是表示alu的2个操作数从哪儿来的
                       src1_is_pc   ,                   //130:130
                       src2_is_imm_symbol_extend    ,   //129:129
                       src2_is_imm_zero_extend      ,   //128:128
                       src2_is_8    ,                   //127:127
                       gr_we        ,                   //126:126
                       mem_we       ,                   //125:125
                       inst_mult    ,                   //124:124
                       inst_multu   ,                   //123:123
                       inst_div     ,                   //122:122
                       inst_divu    ,                   //121:121
                       inst_mfhi    ,                   //120:120
                       inst_mflo    ,                   //119:119
                       inst_mthi    ,                   //118:118
                       inst_mtlo    ,                   //117:117
                       dest         ,                   //116:112 //似乎是描述目标寄存器是哪个
                       imm          ,                   //111:96  //立即数
                       rs_value     ,                   //95 :64  //两个寄存器里面存的东西
                       rt_value     ,                   //63 :32
                       ds_pc                            //31 :0   //PC
                      };

//assign ds_ready_go    = 1'b1;

assign {es_load_op,     //39
        es_result,      //38:7
        es_valid,       //6
        es_gr_we,       //5
        es_dest         //4:0
        } = back_to_id_stage_bus_from_exe;

assign {ms_result,      //38:7
        ms_valid,       //6
        ms_gr_we,       //5
        ms_dest         //4:0
        } = back_to_id_stage_bus_from_mem;

//判断逻辑：
/*
assign ds_ready_go_about_exe =  (!es_valid)? 1 :                                    //首先看信号是否过期，过期直接为1
                                (!es_gr_we)? 1 :                                    //再看是否是写寄存器的指令，不是直接为1
                                (es_dest == rf_raddr1 && rf_raddr1 != 0)? 0 :       //再看写地址和第一个读地址相不相等，相等直接为0
                                (dst_is_rt == 1) ? 1 :                              //再考虑当前指令是否将rt当作读的信号源，rt不是读的，则直接为1
                                (es_dest == rf_raddr2 && rf_raddr2 != 0)? 0 : 1;    //再看写地址和第二个读地址相不相等，相等直接为0
                                                                                    //否则为1
assign ds_ready_go_about_mem =  (!ms_valid)? 1 :                                    //首先看信号是否过期，过期直接为1
                                (!ms_gr_we)? 1 :                                    //再看是否是写寄存器的指令，不是直接为1
                                (ms_dest == rf_raddr1 && rf_raddr1 != 0)? 0 :       //再看写地址和第一个读地址相不相等，相等直接为0
                                (dst_is_rt == 1) ? 1 :                              //再考虑当前指令是否将rt当作读的信号源，rt不是读的，则直接为1
                                (ms_dest == rf_raddr2 && rf_raddr2 != 0)? 0 : 1;    //再看写地址和第二个读地址相不相等，相等直接为0
                                                                                    //否则为1
assign ds_ready_go_about_wb = (!rf_we)? 1 :                                         //先看是不是写使能，不是直接为1
                              (rf_waddr == rf_raddr1 && rf_raddr1 != 0)? 0 :        //再看和两个读地址相不相等，有一个相等就为0
                              (dst_is_rt == 1) ? 1 :                                //再考虑当前指令是否将rt当作读的信号源，rt不是读的，则直接为1
                              (rf_waddr == rf_raddr2 && rf_raddr2 != 0)? 0 : 1;     //否则为1
assign ds_ready_go_about_id_itself = inst_jal;  //这个条件的优先级最高，因为后续指令如果啥寄存器都没读，那么就不会有什么写后读的问题，随便写
assign ds_ready_go = ds_ready_go_about_id_itself |  
                    (ds_ready_go_about_exe & ds_ready_go_about_mem & ds_ready_go_about_wb);  //ID必须与后三个模块同时不冲突才可以搞下去
*/

assign ds_ready_go = (es_load_op == 0)? 1:                                    //首先看exe是不是load指令，不是直接为1
                     (inst_lwr | inst_lwl)? 1:                                //再看本条指令是不是lwr或lwl，是就直接为1
                     (rf_raddr1 == es_dest && es_valid && es_gr_we)? 0 :      //再看此时寄存器1会不会接受前递，是就直接为0
                     (rf_raddr2 == es_dest && es_valid && es_gr_we)? 0 : 1;   //再看此时寄存器2会不会接受前递，是就直接为0
                                                                              //否则为1

assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;//允许接受上级信号的条件
assign ds_to_es_valid = ds_valid && ds_ready_go; 
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (es_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end


    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end
//下面的assign相当于独热码译码器
assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];//j指令的地址

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];   // prj6 added
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];   // prj6 added
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];   // prj6 added
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];   // prj6 added
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];   // prj6 added
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];

assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00];                 // prj6 added   
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00];                 // prj6 added   
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];                 // prj6 added   
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];                 // prj6 added   
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];   // prj6 added                 
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];   // prj6 added
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];   // prj6 added 
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];   // prj6 added 


assign inst_addi   = op_d[6'h08];                                 // prj6 added
assign inst_addiu  = op_d[6'h09];
assign inst_slti   = op_d[6'h0a];                                 // prj6 added
assign inst_sltiu  = op_d[6'h0b];                                 // prj6 added
assign inst_andi   = op_d[6'h0c];                                 // prj6 added
assign inst_ori    = op_d[6'h0d];                                 // prj6 added
assign inst_xori   = op_d[6'h0e];                                 // prj6 added
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];

assign inst_lb     = op_d[6'h20];									//prj7 added
assign inst_lbu    = op_d[6'h24];									//prj7 added
assign inst_lh     = op_d[6'h21];									//prj7 added
assign inst_lhu    = op_d[6'h25];									//prj7 added
assign inst_lwl    = op_d[6'h22];									//prj7 added
assign inst_lwr    = op_d[6'h26];									//prj7 added
assign inst_lw     = op_d[6'h23];
assign inst_sb     = op_d[6'h28];									//prj7 added
assign inst_sh     = op_d[6'h29];									//prj7 added
assign inst_swl    = op_d[6'h2a];									//prj7 added
assign inst_swr    = op_d[6'h2e];									//prj7 added
assign inst_sw     = op_d[6'h2b];

assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];						//prj7 added
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];						//prj7 added
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];						//prj7 added
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];						//prj7 added
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];						//prj7 added
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];						//prj7 added
assign inst_jal    = op_d[6'h03];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];		//prj7 added
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_j      = op_d[6'h02];

assign alu_op[ 0] = inst_add | inst_addu | inst_addi | inst_addiu | load_op | store_op | inst_jal | inst_jalr | inst_bgezal | inst_bltzal;
assign alu_op[ 1] = inst_sub | inst_subu;
assign alu_op[ 2] = inst_slti | inst_slt;
assign alu_op[ 3] = inst_sltiu | inst_sltu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;

assign load_op   = inst_lw  | inst_lb  | inst_lh   | inst_lbu  | inst_lhu  | inst_lwl  | inst_lwr;
assign store_op  = inst_sw  | inst_sb  | inst_sh   | inst_swl  | inst_swr;
assign base_br_op = inst_beq | inst_bne | inst_bgez | inst_bgtz | inst_blez | inst_bltz;

assign mem_left  = inst_swl | inst_lwl ;
assign mem_right = inst_swr | inst_lwr ;
assign mem_b     = inst_sb  | inst_lb  | inst_lbu ;
assign mem_h     = inst_sh  | inst_lh  | inst_lhu ;
assign mem_w     = inst_sw  | inst_lw  ;
assign s_ext     = inst_lb  | inst_lh  ;

assign src1_is_sa   = inst_sll   | inst_srl  | inst_sra;
assign src1_is_pc   = inst_jal   | inst_jalr | inst_bgezal | inst_bltzal;
assign src2_is_8    = inst_jal   | inst_jalr | inst_bgezal | inst_bltzal;
assign src2_is_imm_symbol_extend = inst_addi | inst_addiu | inst_lui | load_op | store_op | inst_slti | inst_sltiu;
assign src2_is_imm_zero_extend   = inst_andi | inst_ori   | inst_xori;
assign res_from_mem = load_op;
assign dst_is_r31   = inst_jal  | inst_bgezal | inst_bltzal;
assign dst_is_rt    = inst_addi | inst_addiu | inst_lui | load_op | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori;
assign gr_we        = ~store_op & ~base_br_op & ~inst_j & ~inst_jr & ~inst_mult & ~inst_multu & ~inst_div & ~inst_divu & ~inst_mthi & ~inst_mtlo;
assign mem_we       = store_op;
//assign hi_we        = inst_mult | inst_multu | inst_mthi;
//assign lo_we        = inst_mult | inst_multu | inst_mtlo;
//assign div_en       = inst_div | inst_divu;
//assign div_sign     = inst_div;
//assign read_hi      = inst_mfhi;
//assign read_lo      = inst_mflo;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

//assign rs_value = rf_rdata1;
//assign rt_value = rf_rdata2;
assign rs_value = (rf_raddr1 == es_dest && es_valid && es_gr_we)?  es_result :            //首先看源寄存器号是不是等于alu的目标寄存器号，等于的话就可以将alu前递的值用上
                  (rf_raddr1 == ms_dest && ms_valid && ms_gr_we)?  ms_result :            //否则再看源寄存器号是不是等于mem的目标寄存器号，等于的话就将mem前递的值用上
                  (rf_raddr1 == rf_waddr && rf_we)? rf_wdata : rf_rdata1;                 //否则再看源寄存器号是不是等于wb的目标寄存器号，等于的话就将wb前递的值用上
                                                                                          //都不等于，再用rf读出来的数据

assign rt_value = (rf_raddr2 == es_dest && es_valid && es_gr_we)?  es_result :            //首先看源寄存器号是不是等于alu的目标寄存器号，等于的话就可以将alu前递的值用上
                  (rf_raddr2 == ms_dest && ms_valid && ms_gr_we)?  ms_result :            //否则再看源寄存器号是不是等于mem的目标寄存器号，等于的话就将mem前递的值用上
                  (rf_raddr2 == rf_waddr && rf_we)? rf_wdata : rf_rdata2;                 //否则再看源寄存器号是不是等于wb的目标寄存器号，等于的话就将wb前递的值用上
                                                                                          //都不等于，再用rf读出来的数据
//以上每一级前递信号都要考虑是否是有效值

assign rs_eq_rt = (rs_value == rt_value);
assign rs_ge_z  = (rs_value[31] == 1'b0);		//prj7 added
assign rs_le_z  = (rs_value[31] == 1'b1 || rs_value == 32'b0);		//prj7 added
assign br_taken = (  inst_beq    &&  rs_eq_rt //看样子br似乎意味着branch
					|| inst_bne    && !rs_eq_rt 
					|| inst_bgez   &&  rs_ge_z
					|| inst_bgtz   && !rs_le_z
					|| inst_blez   &&  rs_le_z
					|| inst_bltz   && !rs_ge_z
					|| inst_bgezal &&  rs_ge_z
					|| inst_bltzal && !rs_ge_z
					|| inst_jal
					|| inst_jalr
					|| inst_jr
					|| inst_j
					) && ds_valid;
assign br_target = (base_br_op || inst_bgezal || inst_bltzal)            ? (fs_pc + {{14{imm[15]}}, imm[15:0], 2'b0}) :
                   (inst_jr || inst_jalr) ? rs_value :
                  /*inst_jal & j*/          {fs_pc[31:28], jidx[25:0], 2'b0};

endmodule