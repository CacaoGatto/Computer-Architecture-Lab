`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram
    input  [31                 :0] data_sram_rdata,
    input  [36:0]    back_to_mem_stage_bus_from_wb,
    output [38:0]    back_to_id_stage_bus_from_mem
    //output [36:0]   mem_forwarding
);

reg         ms_valid;
wire        ms_ready_go;

wire [4:0]  ws_dest_r;
wire [31:0] ws_final_result_r;
wire [31:0] rt_final_result;

reg [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire        ms_s_ext      ;     //prj7 added
wire        ms_mem_left   ;     //prj7 added
wire        ms_mem_right  ;     //prj7 added
wire        ms_mem_w      ;     //prj7 added
wire        ms_mem_h      ;     //prj7 added
wire        ms_mem_b      ;     //prj7 added
wire [ 1:0] ms_addr_low_2 ;     //prj7 added
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire [31:0] ms_alu_result;
wire [31:0] ms_rt_value;
wire [31:0] ms_pc;
assign {ms_s_ext       ,  //108:108 //合成给mem阶段的总线信号
        ms_mem_left    ,  //107:107
        ms_mem_right   ,  //106:106
        ms_mem_w       ,  //105:105
        ms_mem_h       ,  //104:104
        ms_mem_b       ,  //103:103
        ms_res_from_mem,  //102:102
        ms_gr_we       ,  //101:101
        ms_dest        ,  //100:96
        ms_alu_result  ,  //95:64
        ms_rt_value    ,  //63:32
        ms_pc             //31:0
       } = es_to_ms_bus_r; //译码

assign rt_final_result = (ms_dest == ws_dest_r) ? ws_final_result_r :
                                                  ms_rt_value ;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

assign ms_to_ws_bus = {ms_gr_we       ,  //69:69
                       ms_dest        ,  //68:64
                       ms_final_result,  //63:32
                       ms_pc             //31:0
                      };
assign ms_addr_low_2 = ms_alu_result[1:0];

assign ms_ready_go    = 1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus; //bug？？？阻塞赋值？？
    end
end

//assign mem_result = data_sram_rdata;

assign mem_result = ms_mem_left  ? (ms_addr_low_2 == 2'b00 ? {data_sram_rdata[ 7: 0], rt_final_result[23: 0]} :
                                    ms_addr_low_2 == 2'b01 ? {data_sram_rdata[15: 0], rt_final_result[15: 0]} :
                                    ms_addr_low_2 == 2'b10 ? {data_sram_rdata[23: 0], rt_final_result[ 7: 0]} :
                                                             data_sram_rdata
                                   ) :
                    ms_mem_right ? (ms_addr_low_2 == 2'b11 ? {rt_final_result[31: 8], data_sram_rdata[31:24]} :
                                    ms_addr_low_2 == 2'b10 ? {rt_final_result[31:16], data_sram_rdata[31:16]} :
                                    ms_addr_low_2 == 2'b01 ? {rt_final_result[31:24], data_sram_rdata[31: 8]} :
                                                             data_sram_rdata
                                   ) :
                    ms_mem_b     ? (ms_addr_low_2 == 2'b00 ? {{24{ms_s_ext&data_sram_rdata[ 7]}}, data_sram_rdata[ 7: 0]} :
                                    ms_addr_low_2 == 2'b01 ? {{24{ms_s_ext&data_sram_rdata[15]}}, data_sram_rdata[15: 8]} :
                                    ms_addr_low_2 == 2'b10 ? {{24{ms_s_ext&data_sram_rdata[23]}}, data_sram_rdata[23:16]} :
                                                             {{24{ms_s_ext&data_sram_rdata[31]}}, data_sram_rdata[31:24]}
                                   ) :
                    ms_mem_h     ? (ms_addr_low_2 == 2'b00 ? {{16{ms_s_ext&data_sram_rdata[15]}}, data_sram_rdata[15: 0]} :
                                                             {{16{ms_s_ext&data_sram_rdata[31]}}, data_sram_rdata[31:16]}
                                   ) :
                                   data_sram_rdata;

assign ms_final_result = ms_res_from_mem ? mem_result //判断写回的数据到底是从mem里面来的，还是alu算出来的
                                         : ms_alu_result;//res的意思应该就是result


assign back_to_id_stage_bus_from_mem = {ms_final_result,    //38:7
                                        ms_valid,           //6
                                        ms_gr_we,           //5
                                        ms_dest             //4:0
                                        };
assign {ws_dest_r, ws_final_result_r} = back_to_mem_stage_bus_from_wb;

/*
assign mem_forwarding = {ms_final_result,   //36:5
                         ms_dest            //4:0
                        };
*/

endmodule