`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface
    output        inst_sram_en   ,
    output [ 3:0] inst_sram_wen  ,
    output [31:0] inst_sram_addr ,
    output [31:0] inst_sram_wdata,
    input  [31:0] inst_sram_rdata
);

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire         br_taken;
wire [ 31:0] br_target;
//wire [`BR_BUS_WD - 2 : 0] br_target;
assign {br_taken,br_target} = br_bus;//?????这个是bug？br_bus本身就32位，还要分给1位的taken和32位的target，分不过来啊

wire [31:0] fs_inst;//instruction，指令
reg  [31:0] fs_pc;
assign fs_to_ds_bus = {fs_inst ,
                       fs_pc   };//总线上面搭载instruction和PC

// pre-IF stage
assign to_fs_valid  = ~reset;//不再reset就说明可以给IF数据了
assign seq_pc       = fs_pc + 3'h4; //PC+4，正常顺序的下一条指令
assign nextpc       = br_taken ? br_target : seq_pc; //决定下一条指令是不是PC+4的

// IF stage
assign fs_ready_go    = 1'b1; //可以向ID阶段传送数据了
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;//允许接受上级信号的条件
assign fs_to_ds_valid =  fs_valid && fs_ready_go;
always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

assign inst_sram_en    = to_fs_valid && fs_allowin;//允许接受instruction的条件
assign inst_sram_wen   = 4'h0;                      //不写IRAM里面的指令，只是读指令
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

assign fs_inst         = inst_sram_rdata; //从IRAM里面读到的就是指令

endmodule