lab7文件说明

mycpu.c:
设计头文件，本次无更改。

mycpu_top.v:
设计顶层文件，本次增加了WB连向MEM的前递线路。

IF_stage.v:
取指级流水，本次无更改。

ID_stage.v:
译码级流水，本次增加了新设信号的译码、lwl和lwr指令在阻塞的特殊处理，以及加设了分支跳转的判断条件和新增指令的跳转逻辑。
tools.v:
译码相关逻辑，本次无更改。
regfile.v:
寄存器堆设计，本次无更改。

EXE_stage.v:
执行级流水，本次在传向MEM的总线中增加了rt值和部分load指令信号。store型指令复用load型指令信号，在本阶段生成相关数据和字节写使能。
alu.v:
运算器设计，本次无更改。
divide_controller.v:
除法器控制模块，本次无更改。
mulltiplier.v:
乘法器控制模块，本次无更改。

MEM_stage.v:
访存级流水，本次增加了load型指令的信号筛选。其中，lwl、lwr指令会用到由WB前递得到的rt值。

WB_stage.v:
写回级流水，本次增加了前递向访存级的线路，以及一个存储上条有效写回指令的缓存。