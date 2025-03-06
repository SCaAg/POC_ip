module poc (
    // Clock and reset
    input  wire        clk,    // System clock
    input  wire        rst_n,  // Active low reset
    
    output reg irq,
    
    input wire [7:0]data_in,

    input wire rw,// 1 for write, 0 for read
    input wire reg_in,
    output reg reg_out,
    input wire [2:0]addr,

    input wire print_ready,
    output reg [7:0]print_data,
    output reg pulse_request
    
);
    

    reg status_reg[7:0]=8'b10000000;
    // Register R/W logic
    // mutable registers [status_reg],[reg_out]
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            status_reg <= 8'b10000000;
            reg_out <= 1'b0;
        end
        else begin
            // if the CPU requires to write
            if(rw) begin
                status_reg[addr] <= reg_in;
                reg_out<=reg_out;
            // if the CPU requires to read
            else begin
                status_reg[7] <= status_reg_next;
                reg_out <= status_reg[addr];
            end
            end
        end
    end

    // Regesters Alias
    localparam polling = 1'b1;
    localparam interupt = 1'b0;
    wire mode;
    assign mode = status_reg[0];
    
    localparam poc_ready=1'b1;
    localparam poc_busy=1'b0;
    wire ready;
    assign ready= status_reg[7];
    
    // Read in and print request controls
    // Mutable registers:[print_request], [byte_buffer], [irq]
    reg [7:0]byte_buffer=8'b0;
    reg print_request=1'b0;
    reg int_request=1'b0;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            print_request<=1'b0;
            byte_buffer<=8'b0;
            irq<=1'b1;
        end
        else begin
            // if in polling mode
            if(mode == polling) begin
                // if in the polling mode, poc is ready
                if(ready==poc_ready)begin
                    print_request<=1'b0; 
                    byte_buffer<=data_in;
                    irq<=1'b1;
                end
                // if in the polling mode, poc is busy
                else begin
                    // if in the polling mode, poc is ready, print is ready
                    if(print_ready) begin
                        print_request<=1'b1;
                        byte_buffer<=byte_buffer;
                        irq<=1'b1;
                    end
                    // if in the polling mode, poc is ready, print is busy
                    else begin
                        print_request<=1'b0;
                        byte_buffer<=byte_buffer;
                        irq<=1'b1;
                    end
                end
            end
            // if in interupt mode
            else begin
                // if in interupt mode, poc is ready
                if(ready==poc_ready)begin
                    print_request<=1'b0;
                    byte_buffer<=data_in;
                    irq<=print_ready==1'b1 ? 1'b0 : 1'b1;// if print is ready, send irq. if not, wait for printer.
                end
                // if in interupt mode, poc is busy
                else begin
                    // if in interupt mode, poc is busy, print is ready(only when printer is ready can enter this state)
                    print_request<=1'b1;
                    irq<=1'b1;// high level to clear the interrupt
                    byte_buffer<=byte_buffer;
                end
            end
        end
    end
    
    
    

    localparam print_idle_state=1'b0;
    localparam pirnt_busy_state=1'b1;
    reg print_state=print_idle_state;
    reg pulse_request=1'b0;
    reg status_reg_next=1'b1;
    // Printer Service FSM
    // Mutable registers:[print_state], [print_data], [pulse_request], [status_reg_next]
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            print_state<=print_idle_state;
            print_data<=8'b0;
            pulse_request<=1'b0;
            status_reg_next<=1'b1;
        end
        else begin
            // if print is requested
            if(print_request)begin
                // if print is requested, printer is ready
                if(print_ready)begin
                    // if print is requested, printer is ready, printer state is idle
                    if(print_state==print_idle_state)begin
                        print_state<=pirnt_busy_state;
                        print_data<=byte_buffer;
                        pulse_request<=1'b1;
                        status_reg_next<=status_reg_next;
                    end
                    // if print is requested, printer is ready, printer state is busy
                    else begin
                        print_state<=print_idle_state;
                        print_data<=print_data;
                        pulse_request<=1'b0;
                        status_reg_next<=1'b1;
                    end
                end
                // if print is requested, printer is busy
                else begin
                    print_state<=print_state;
                    print_data<=print_data;
                    pulse_request<=1'b0;
                    status_reg_next<=1'b0;
                end
            end
            // if print is not requested
            else begin
                print_state<=print_idle_state;
                print_data<=print_data;
                pulse_request<=1'b0;
                status_reg_next<=1'b0;
            end
        end
    end


    /*
    // CPU Data I/O FSM
    localparam read_in = 1'b0;
    localparam write_out = 1'b1;
    reg rw_state = read_in;
    reg [7:0]print_data_polling=8'b0;
    reg require_interupt=1'b0;
    reg require_print=1'b0;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rw_state <= read_in;
        end
        else begin
            if(status_reg[7])begin
                case (mode)
                    polling:print_data_polling<=data_in;
                    interupt:require_interupt<=~require_interupt;
                endcase
            end
            else begin
                require_print<=~require_print;
            end
        end
    end
    
    reg [1:0]require_interupt_buffer=2'b0;
    reg [1:0]require_print_buffer=2'b0;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            require_interupt_buffer<=2'b0;
            require_print_buffer<=2'b0;
        end
        else begin
            require_interupt_buffer<={require_interupt_buffer[0],require_interupt};
            require_print_buffer<={require_print_buffer[0],require_print};
        end
    end
    
    wire execute_interupt = require_interupt_buffer[0]!=require_interupt_buffer[1];
    wire execute_print = require_print_buffer[0]!=require_print_buffer[1];
    reg wait_for_cpu_input=1'b0;
    reg wait_for_cpu_input_next=1'b0;
    reg start_to_print=1'b0;
    reg start_to_print_next=1'b0;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            
        end
        else begin
            if(execute_interupt)begin
                wait_for_cpu_input<=1'b1;
                start_to_print<=start_to_print_next;
            end
            else if(execute_print)begin
                wait_for_cpu_input<=wait_for_cpu_input_next;
                start_to_print<=1'b1;
            end
        end
    end
    reg [7:0]print_data_interupt=8'b0;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            
        end
        else begin
            if(wait_for_cpu_input&&status_reg[7])print_data_interupt<=data_in;
            else if(start_to_print_next&&finish_print)status_reg_next[7]<=1'b1;
            else wait_for_cpu_input_next<=1'b0;
        end
    end

    // Print Process FSM
    localparam send_pulse=1'b0;
    localparam print_out=1'b1;
    reg print_state=send_pulse;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            print_state<=send_pulse;
        end
        else begin
            if(print_ready)begin
                print_state<=send_pulse;
            end
            else begin
                print_state<=print_out;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            
        end
        else begin
            if(start_to_print)begin
                
            end
        end
    end
    
    // Data I/O Behavior
    
    reg [7:0]status_reg_next=8'b0;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            byte_data<=8'b0;
        end
        else begin
            case rw_state
                read_in: begin
                    case mode
                        polling: begin
                            byte_data<=data_in;
                            status_reg_next[7]<=0;
                        end
                        interupt: begin
                            
                        end
                    endcase
                end
                print_out: begin
                    
                end
            endcase
        end
    end

    // Print Behavior
    /*
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            
        end
        else begin
            case print_state
                send_pulse:begin
                    
                end
                print_out:begin
                    print_data<=byte_data;

                end
            endcase
        end
    end
    reg buffer_selected=1'b0;
    wire[8:0]config_wire={buffer_selected,status_reg};
    localparam mode_selected=2'b00;
    localparam ready_selected=2'b01;
    localparam buffer_selected=2'b10;
    reg [2:0]cpu_selected_content=2'b00;
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n)
        cpu_selected_content<=2'b00;
        case (config_wire[8:7],config_wire[0])
            3'b001:cpu_selected_content<=mode_selected;
            3'b010:cpu_selected_content<=ready_selected;
            3'b100:cpu_selected_content<=buffer_selected;
        endcase
    end
    */


endmodule