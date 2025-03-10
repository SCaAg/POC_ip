module poc (
    // Clock and reset
    input  wire        clk,    // System clock
    input  wire        rst_n,  // Active low reset
    
    output reg irq,            // Interrupt request (active low)
    
    input wire [7:0]data_in,   // Data from CPU
    
    input wire rw,             // 1 for write, 0 for read
    input wire reg_in,         // Input bit for register write
    output reg reg_out,        // Output bit for register read
    input wire [2:0]addr,      // Register address
    
    input wire print_ready,    // Printer ready signal
    output reg [7:0]print_data, // Data to printer
    output reg pulse_request   // Pulse request to printer
);
    
    // 常量定义，增强代码可读性
    localparam POLLING_MODE = 1'b0;   // 查询模式 (SR0=0)
    localparam INTERRUPT_MODE = 1'b1; // 中断模式 (SR0=1)
    localparam POC_READY = 1'b1;      // POC就绪状态 (SR7=1)
    localparam POC_BUSY = 1'b0;       // POC忙状态 (SR7=0)
    
    // Register addresses
    localparam SR0_ADDR = 3'b000;     // Mode control register
    localparam DATA_ADDR = 3'b001;    // Data register
    localparam SR7_ADDR = 3'b111;     // Ready flag register
    
   // POC主状态机状态定义
    localparam STATE_IDLE = 3'b000;           // POC空闲，等待数据
    localparam STATE_DATA_RECEIVED = 3'b001;  // 收到数据，准备打印
    localparam STATE_WAIT_PRINTER = 3'b010;   // 等待打印机就绪
    localparam STATE_PRINT_START = 3'b011;    // 开始打印 (发送脉冲)
    localparam STATE_PRINT_END = 3'b100;      // 结束打印 (结束脉冲)
    
    // 状态寄存器
    reg [2:0] state, next_state;
    
    // 内部寄存器
    reg [7:0] status_reg, next_status_reg;
    reg [7:0] byte_buffer, next_byte_buffer;
    reg next_irq;
    reg [7:0] next_print_data;
    reg next_pulse_request;
    reg next_reg_out;
    
    // 方便访问的状态寄存器位
    wire mode = status_reg[0];
    wire ready = status_reg[7];
    
    //==========================================
    // 时序逻辑 - 寄存器更新
    //==========================================
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            // 复位所有寄存器
            state <= STATE_IDLE;
            status_reg <= 8'b10000000;  // POC初始就绪 (SR7=1)
            byte_buffer <= 8'b0;
            irq <= 1'b1;                // 中断初始为非激活
            print_data <= 8'b0;
            pulse_request <= 1'b0;
            reg_out <= 1'b0;
        end
        else begin
            // 更新所有寄存器
            state <= next_state;
            status_reg <= next_status_reg;
            byte_buffer <= next_byte_buffer;
            irq <= next_irq;
            print_data <= next_print_data;
            pulse_request <= next_pulse_request;
            reg_out <= next_reg_out;
        end
    end
    
    //==========================================
    // 组合逻辑 - 计算下一状态和输出
    //==========================================
    always @(*) begin
        // 默认：保持当前值
        next_state = state;
        next_status_reg = status_reg;
        next_byte_buffer = byte_buffer;
        next_irq = irq;
        next_print_data = print_data;
        next_pulse_request = pulse_request;
        next_reg_out = reg_out;
        
        // 处理CPU寄存器读写操作
        if (rw) begin
            // CPU写操作
            case (addr)
                SR0_ADDR: next_status_reg[0] = reg_in;  // SR0: Mode control
                DATA_ADDR: next_byte_buffer = data_in;  // Data register: Store data directly
                SR7_ADDR: next_status_reg[7] = reg_in;  // SR7: Ready flag
                default: ; // Other addresses not used
            endcase
        end
        else begin
            // CPU读操作
            next_reg_out = status_reg[addr];
        end
        
        // 主状态机逻辑
        case (state)
            STATE_IDLE: begin
                // POC空闲状态
                
                // 在中断模式下，如果POC就绪且打印机就绪，生成中断请求
                if (mode == INTERRUPT_MODE && ready == POC_READY) begin
                    next_irq = (print_ready) ? 1'b0 : 1'b1;  // 低电平有效
                end
                
                // 如果CPU将SR7设为0(POC忙)，存储数据并准备打印
                if (ready == POC_READY && next_status_reg[7] == POC_BUSY) begin
                    next_state = STATE_DATA_RECEIVED;
                    
                    // 在中断模式下，清除中断请求
                    if (mode == INTERRUPT_MODE) begin
                        next_irq = 1'b1;  // 非激活
                    end
                end
            end
            
            STATE_DATA_RECEIVED: begin
                // 数据已接收，检查打印机是否就绪
                if (print_ready) begin
                    next_state = STATE_PRINT_START;
                    next_print_data = byte_buffer;
                    next_pulse_request = 1'b1;  // 发送脉冲请求
                end
                else begin
                    next_state = STATE_WAIT_PRINTER;
                end
            end
            
            STATE_WAIT_PRINTER: begin
                // 等待打印机就绪
                if (print_ready) begin
                    next_state = STATE_PRINT_START;
                    next_print_data = byte_buffer;
                    next_pulse_request = 1'b1;  // 发送脉冲请求
                end
            end
            
            STATE_PRINT_START: begin
                // 开始打印状态 (脉冲高)
                next_state = STATE_PRINT_END;
            end
            
            STATE_PRINT_END: begin
                // 结束打印状态 (脉冲低)
                next_pulse_request = 1'b0;  // 结束脉冲
                next_status_reg[7] = POC_READY;  // 设置POC为就绪状态
                next_state = STATE_IDLE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end
    
endmodule