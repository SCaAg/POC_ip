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
    
    // Status register (8-bit)
    reg [7:0] status_reg = 8'b10000000;
    reg status_reg_next;
    
    // Register R/W logic
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            status_reg <= 8'b10000000;  // Reset status, POC ready
            reg_out <= 1'b0;
        end
        else begin
            // if the CPU requires to write
            if(rw) begin
                // Write to status register based on address
                case(addr)
                    3'b000: status_reg[0] <= reg_in;  // SR0: mode control
                    3'b111: status_reg[7] <= reg_in;  // SR7: ready flag
                    default: ; // Other addresses not used for status
                endcase
                reg_out <= reg_out;  // No change during write
            end
            // if the CPU requires to read
            else begin
                status_reg[7] <= status_reg_next;  // Update ready status
                reg_out <= status_reg[addr];       // Output requested register bit
            end
        end
    end

    // Registers Alias - corrected as per spec
    localparam polling = 1'b0;   // Polling mode when SR0=0
    localparam interrupt = 1'b1; // Interrupt mode when SR0=1
    wire mode;
    assign mode = status_reg[0];
    
    localparam poc_ready = 1'b1;
    localparam poc_busy = 1'b0;
    wire ready;
    assign ready = status_reg[7];
    
    // Read in and print request controls
    reg [7:0] byte_buffer = 8'b0;
    reg print_request = 1'b0;
    
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            print_request <= 1'b0;
            byte_buffer <= 8'b0;
            irq <= 1'b1;  // Active low, initialized inactive
        end
        else begin
            // Polling mode (SR0 = 0)
            if(mode == polling) begin
                // POC is ready
                if(ready == poc_ready) begin
                    print_request <= 1'b0; 
                    byte_buffer <= data_in;  // Store new data
                    irq <= 1'b1;  // Keep IRQ inactive in polling mode
                end
                // POC is busy
                else begin
                    if(print_ready) begin
                        print_request <= 1'b1;  // Request to print
                        byte_buffer <= byte_buffer;
                        irq <= 1'b1;  // Keep IRQ inactive
                    end
                    else begin
                        print_request <= 1'b0;
                        byte_buffer <= byte_buffer;
                        irq <= 1'b1;
                    end
                end
            end
            // Interrupt mode (SR0 = 1)
            else begin
                // POC is ready
                if(ready == poc_ready) begin
                    print_request <= 1'b0;
                    byte_buffer <= data_in;  // Store new data
                    // If printer is ready, generate interrupt (active low)
                    irq <= (print_ready == 1'b1) ? 1'b0 : 1'b1;
                end
                // POC is busy
                else begin
                    print_request <= 1'b1;  // Request to print when printer ready
                    irq <= 1'b1;  // Clear interrupt
                    byte_buffer <= byte_buffer;
                end
            end
        end
    end
    
    // Printer state machine
    localparam print_idle_state = 1'b0;
    localparam print_busy_state = 1'b1;
    reg print_state = print_idle_state;
    
    // Printer Service FSM
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            print_state <= print_idle_state;
            print_data <= 8'b0;
            pulse_request <= 1'b0;
            status_reg_next <= 1'b1;  // POC ready after reset
        end
        else begin
            // Print requested and printer ready
            if(print_request && print_ready) begin
                if(print_state == print_idle_state) begin
                    print_state <= print_busy_state;
                    print_data <= byte_buffer;     // Send data to printer
                    pulse_request <= 1'b1;         // Generate pulse request
                    status_reg_next <= poc_busy;   // POC is busy during printing
                end
                else begin  // print_state == print_busy_state
                    print_state <= print_idle_state;
                    print_data <= print_data;      // Keep data stable
                    pulse_request <= 1'b0;         // End pulse
                    status_reg_next <= poc_ready;  // POC becomes ready again
                end
            end
            // Print requested but printer not ready
            else if(print_request && !print_ready) begin
                print_state <= print_state;
                print_data <= print_data;
                pulse_request <= 1'b0;
                status_reg_next <= poc_busy;  // POC stays busy
            end
            // No print request
            else begin
                print_state <= print_idle_state;
                print_data <= print_data;
                pulse_request <= 1'b0;
                status_reg_next <= poc_ready;  // POC is ready when no request
            end
        end
    end

endmodule