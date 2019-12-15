module cpu_axi_interface(
    input clk           ,
    input resetn        ,

    //inst sram-like
    input         inst_req      ,
    input         inst_wr       ,
    input  [ 1:0] inst_size     ,
    input  [31:0] inst_addr     ,
    input  [ 3:0] inst_wstrb    ,// 此信号Lab10好像用不到 
    input  [31:0] inst_wdata    ,
    output [31:0] inst_rdata    ,
    output        inst_addr_ok  ,
    output        inst_data_ok  ,
    
    //data sram-like
    input         data_req      ,
    input         data_wr       ,
    input  [ 1:0] data_size     ,
    input  [31:0] data_addr     ,
    input  [ 3:0] data_wstrb    ,// 此信号Lab10好像用不到 
    input  [31:0] data_wdata    ,
    output [31:0] data_rdata    ,
    output        data_addr_ok  ,
    output        data_data_ok  ,

    //axi
    //ar
    output reg [ 3:0] arid      ,
    output reg [31:0] araddr    ,
    output     [ 7:0] arlen     ,
    output reg [ 2:0] arsize    ,
    output     [ 1:0] arburst   ,
    output     [ 1:0] arlock    ,
    output     [ 3:0] arcache   ,
    output     [ 2:0] arprot    ,
    output            arvalid   , 
    input             arready   ,
    //r        
    input  [ 3:0] rid       , // 这个信号不知道在prj10里面能干啥
    input  [31:0] rdata     ,
    input  [ 1:0] rresp     ,
    input         rlast     ,
    input         rvalid    ,
    output        rready    ,
    

    //aw       
    output     [ 3:0] awid      ,
    output reg [31:0] awaddr    ,
    output     [ 7:0] awlen     ,
    output reg [ 2:0] awsize    ,
    output     [ 1:0] awburst   ,
    output     [ 1:0] awlock    ,
    output     [ 3:0] awcache   ,
    output     [ 2:0] awprot    ,
    output            awvalid   ,
    input             awready   ,
    //w        
    output     [ 3:0] wid       ,
    output reg [31:0] wdata     ,
    output reg [ 3:0] wstrb     ,
    output            wlast     ,
    output            wvalid    ,
    input             wready    ,
    //b        
    input     [ 3:0] bid       , // 这个信号好像在prj10里面没用到
    input     [ 1:0] bresp     ,
    input            bvalid    ,  
    output           bready
    );

// 此处状态未考虑burst传输......
localparam AR_idle = 2'b00;
localparam AR_finish   = 2'b01;
localparam AR_init  = 2'b10;
localparam AR_blocked = 2'b11;

localparam R_idle  = 2'b00;
localparam R_finish    = 2'b01;

localparam AW_idle = 2'b00;
localparam AW_finish   = 2'b01;

localparam AW_W_WORKING = 2'b10;
//localparam W_idle  = 2'b10;
localparam W_finish    = 2'b11;


localparam B_not_start  = 2'b00;
localparam B_working    = 2'b01;

reg read_transaction;   //读事务
reg write_transaction;  //写事务
wire read_signal;
wire write_signal;

wire sram_data_read_handshake;
wire sram_inst_read_handshake;
wire sram_data_write_handshake;
wire sram_inst_write_handshake;


// axi握手信号标志
wire ar_handshake;
wire r_handshake;
wire aw_handshake;
wire w_handshake;
wire b_handshake;


//下面几个状态机的状态
reg [1:0] state_ar;
reg [1:0] state_r;
reg [1:0] state_aw_w;
reg [1:0] state_b;

// 由于目前没出现例外，这俩寄存器暂时没用到，仅为例外处理机制预留......
reg [31:0] rdata_buffer;
reg [31:0] araddr_buffer;


wire [ 3:0] wstrb_wire_all;
wire [ 3:0] wstrb_wire_zero;
wire [ 3:0] wstrb_wire_one;
wire [ 3:0] wstrb_wire_two;

reg inst_req_reg;
reg data_req_reg;


reg aw_has_handshaked;  //表示aw信号已经握手
reg w_has_handshaked;   //表示w信号已经握手  

wire read_blocked;        //发生阻塞的标志信号

assign ar_handshake = arvalid & arready;
assign r_handshake  = rvalid  & rready;
assign aw_handshake = awvalid & awready;
assign w_handshake  = wvalid  & wready;
assign b_handshake  = bvalid  & bready;

// 以下信号是根据讲义所描述的“固定不动”的信号赋值
assign arlen    = 0;
assign arburst  = 2'b01;
assign arlock   = 0;
assign arcache  = 0;
assign arprot   = 0;

assign awid     = 4'b0001;
assign awlen    = 0;
assign awburst  = 2'b01;
assign awlock   = 0;
assign awcache  = 0;
assign awprot   = 0;

assign wid      = 4'b0001;
assign wlast    = 1'b1;



assign inst_addr_ok = (read_transaction)?  0 :
                      (write_transaction)? 0 :
                      (data_req)? 0 : inst_req;

assign data_addr_ok = (read_transaction)?  0 :
                      (write_transaction)? 0 : data_req;




assign inst_data_ok = (!inst_req_reg)? 0 : 
                      (read_transaction)?r_handshake :
                      (write_transaction)?b_handshake : 0;

assign data_data_ok = (!data_req_reg)? 0 :
                      (read_transaction)?r_handshake :
                      (write_transaction)?b_handshake : 0;

//assign inst_rdata = (inst_req)? rdata_buffer : 0;
//assign data_rdata = (data_req)? rdata_buffer : 0;
assign inst_rdata = (inst_req_reg)? rdata : 0;
assign data_rdata = (data_req_reg)? rdata : 0;


    
assign read_signal  = (data_req & (~data_wr)) | (inst_req & (~inst_wr)); //读信号的逻辑：有req，且wr为0
assign write_signal = (data_req &   data_wr)  |  (inst_req &   inst_wr); //写信号的逻辑：有req，且wr为1

assign sram_data_read_handshake  = data_req & data_addr_ok & (~data_wr);
assign sram_inst_read_handshake  = inst_req & inst_addr_ok & (~inst_wr);
assign sram_data_write_handshake = data_req & data_addr_ok & data_wr;
assign sram_inst_write_handshake = inst_req & inst_addr_ok & inst_wr;



always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        read_transaction <= 1'b0;
    end
    else if ((~read_transaction) && (~write_transaction) && (read_signal) && (!write_signal)) // 读事务的赋值逻辑：观测到读信号，而且读事务寄存器还没被置为1 
    begin
        read_transaction <= 1'b1;
    end


    else if(r_handshake) //握手之后，下一拍读事务结束，因此非阻塞赋值为0
    begin
        read_transaction <= 1'b0;
    end
end

always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        write_transaction <= 1'b0;
    end
    else if ((~write_transaction) && (~read_transaction) && (write_signal)) // 写事务的赋值逻辑：观测到写信号，而且写事务寄存器还没被置为1 
    begin
        write_transaction <= 1'b1;
    end
    else if(b_handshake) //握手之后，下一拍写事务结束，非阻塞赋值为0
    begin
        write_transaction <= 1'b0;
    end
end


always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        inst_req_reg <= 1'b0;    
    end
    /*else if (sram_inst_read_handshake) 
    begin
        inst_req_reg <= inst_req;
    end

    else if (sram_inst_write_handshake)
    begin
        inst_req_reg <= inst_req;
    end

    else if (r_handshake | b_handshake)
    begin
        inst_req_reg <= 1'b0;
    end*/

    else if (sram_data_read_handshake | sram_data_write_handshake | sram_inst_read_handshake | sram_inst_write_handshake) 
    begin
        inst_req_reg <= (inst_req) & (~data_req);
    end

end

always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        data_req_reg <= 1'b0;    
    end
    /*else if (sram_data_read_handshake) 
    begin
        data_req_reg <= data_req;
    end

    else if (sram_data_write_handshake)
    begin
        data_req_reg <= data_req;
    end

    else if (r_handshake | b_handshake)
    begin
        data_req_reg <= 1'b0;
    end*/

    else if (sram_data_read_handshake | sram_data_write_handshake | sram_inst_read_handshake | sram_inst_write_handshake) 
    begin
        data_req_reg <= data_req;
    end
end


/****************************************axi-ar****************************************/
//状态机

always @(posedge clk) 
begin
    if (~resetn) begin
        // reset
        state_ar <= AR_idle;
    end
/*
    else if ((state_ar == AR_idle) && (test_for_block) && (state_aw_w == AW_W_WORKING)) 
    begin
        state_ar <= AR_blocked;
    end

    else if ((state_ar == AR_blocked) && b_handshake)
    begin
        state_ar <= AR_idle;
    end
*/
    else if (ar_handshake && (state_ar == AR_idle))
    begin
        state_ar <= AR_finish;
    end

    else if (r_handshake && (state_ar == AR_finish))
    begin
        state_ar <= AR_idle; 
    end
end


// arvalid
assign arvalid = //read_blocked ? 0 : // 简易阻塞机制：同时出现读写事务且读写地址相同时，阻塞
                (state_ar == AR_idle) && read_transaction;


assign read_blocked = (araddr[31:2] == awaddr[31:2]) && read_transaction && write_transaction;
//assign read_blocked = (write_transaction) && (sram_data_read_handshake) && (awaddr[31:2] == data_addr[31:2]);
// 阻塞的条件是：此时正在进行写事务，但是读事务还没开始
//              准备申请新一次的读事务的时候，首先要在类SRAM端握手，以获得新的读地址
//              如果这个刚发下来的读地址和现在正在写的写地址一样，那么认为会发生写后读冲突
//              此时还没有出现读事务，也就是在读事务开始之前阻塞
//              但是问题是，这个新的地址会不会丢失？需不需要寄存器暂存一下，等到阻塞完毕之后再赋给araddr？
//              由于此时已经发生sram握手，下一拍master端的valid（req）就会拉低，那么握手+block两个信号一起作为这个寄存器赋值的条件？
//              然后这个寄存器将数值释放出来的条件是，block信号拉低，还可能有别的信号
//              但是实际上从仿真的波形上面看，似乎没有出现这种冲突？

// araddr
always @(posedge clk) 
begin
    if (~resetn) begin
        araddr <= 0;
    end
    
    else if (sram_data_read_handshake) 
    begin
        araddr <= data_addr;
    end

    else if (sram_inst_read_handshake) 
    begin
        araddr <= inst_addr;
    end
end

// arid
always @(posedge clk)   
begin
    if (~resetn) 
    begin
        // reset
        arid <= 0;        
    end    

    else if (sram_data_read_handshake) 
    begin
        arid <= 4'b0001;    
    end

    else if (sram_inst_read_handshake) 
    begin
        arid <= 0;
    end

end

// arsize
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        arsize <= 0;
    end
    else if (sram_data_read_handshake) 
    begin
        arsize <= data_size; 
    end

    else if (sram_inst_read_handshake) 
    begin
        arsize <= inst_size;    
    end
end

/****************************************axi-r****************************************/
//axi-r的状态机

always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        state_r <= R_idle;
    end
    
    else if (r_handshake)
    begin
        state_r <= R_finish;
    end

    else if (ar_handshake) 
    begin
        state_r <= R_idle;
    end

    // 为cache的burst传输预留
    // 目前未使用到last信号......
    

end


// rready

assign rready = (state_ar == AR_finish) && read_transaction;


// rdata_buffer
// 为例外机制暂留的，目前仿真测试也查不了这个地方的bug......
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        rdata_buffer <= 0;
    end
    else if (state_ar == AR_idle && read_transaction && state_r == R_idle)  // 检测到rready即将上升
    begin
        rdata_buffer <= rdata;
    end

    else if (rvalid && (state_r == R_idle)) // 检测到rvalid
    begin
        rdata_buffer <= rdata;
    end

end


/****************************************axi-aw/w****************************************/
//axi-aw/w的状态机
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        state_aw_w <= AW_idle;
        aw_has_handshaked <= 1'b0;
        w_has_handshaked <= 1'b0;    
    end
    
    /*else if (aw_handshake)
    begin
        state_aw_w <= AW_finish;
    end

    else if (w_handshake)
    begin
        state_aw_w <= W_finish;
    end*/

    else if (aw_handshake | w_handshake)
    begin
        state_aw_w <= AW_W_WORKING;
        if (aw_handshake) 
        begin
           aw_has_handshaked <= 1'b1; 
        end

        if (w_handshake)
        begin
            w_has_handshaked <= 1'b1;
        end
    end

    else if (b_handshake)
    begin
        state_aw_w <= AW_idle;
        aw_has_handshaked <= 1'b0;
        w_has_handshaked <= 1'b0;
    end    
end

//awvalid
assign awvalid = write_transaction && (aw_has_handshaked != 1'b1); //(state_aw_w != AW_finish) && (state_aw_w != W_finish);

// awaddr
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
       awaddr <= 0;
    end

    else if (sram_data_write_handshake) 
    begin
        awaddr <= data_addr;
    end

    else if (sram_inst_write_handshake) 
    begin
        awaddr <= inst_addr;
    end

end

// awsize
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        awsize <= 0;    
    end
    else if (sram_data_write_handshake)
    begin
        awsize <= data_size;
    end

    else if (sram_inst_write_handshake) 
    begin
        awsize <= inst_size;
    end
end

// wvalid

assign wvalid = write_transaction && (w_has_handshaked != 1);//(state_aw_w != W_finish);


//wdata
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        wdata <= 0;    
    end
    
    else if (sram_data_write_handshake)
    begin
        wdata <= data_wdata;
    end

    else if (sram_inst_write_handshake)
    begin
        wdata <= inst_wdata;
    end

end

//wstrb
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        wstrb <= 0;
    end
    //else if (wvalid) 
    else if (sram_data_write_handshake)
    begin
        //wstrb <= wstrb_wire_all;
        wstrb <= data_wstrb;
    end
end

// size = 0
assign wstrb_wire_zero = (awaddr[1:0] == 2'b00) ? 4'b0001 :
                         (awaddr[1:0] == 2'b01) ? 4'b0010 :
                         (awaddr[1:0] == 2'b10) ? 4'b0100 :
                         (awaddr[1:0] == 2'b11) ? 4'b1000 : 4'b0000;
// size = 1
assign wstrb_wire_one  = (awaddr[1:0] == 2'b00) ? 4'b0011 :
                         (awaddr[1:0] == 2'b10) ? 4'b1100 : 4'b0000;

// size = 2
assign wstrb_wire_two  = (awaddr[1:0] == 2'b00) ? 4'b1111 : 4'b0000; // 为lwl/lwr/swl/swr预留一下......


assign wstrb_wire_all  = (awsize == 2'b00) ? wstrb_wire_zero :
                         (awsize == 2'b01) ? wstrb_wire_one  :
                         (awsize == 2'b10) ? wstrb_wire_two  : 4'b0000;

/****************************************axi-b****************************************/
//axi-b的状态机
always @(posedge clk) 
begin
    if (~resetn) 
    begin
        // reset
        state_b <= B_not_start;    
    end
    else if (wlast && w_handshake) // 看到本次W结束了 
    begin
        state_b <= B_working;
    end

    else if (b_handshake) 
    begin
        state_b <= B_not_start;
    end
end

// bready
assign bready = write_transaction && (state_aw_w != AW_idle);


//debug
wire test_for_block;
assign test_for_block = (awaddr[31:2] == araddr[31:2]);


endmodule


