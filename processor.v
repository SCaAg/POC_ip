module processor (
    input  wire        clk,        // System clock (50MHz)
    input  wire        rst_n,      // Active low reset
    
    input  wire        irq,        // Interrupt request from POC (active low)
    
    output reg  [7:0]  data_out,   // Data to POC
    
    output reg         rw,         // 1 for write, 0 for read
    output reg         reg_in,     // Input bit for register write
    input  wire        reg_out,    // Output bit for register read
    output reg  [2:0]  addr        // Register address
);

    // Register addresses
    localparam SR0_ADDR = 3'b000;  // Mode control register (0=polling, 1=interrupt)
    localparam DATA_ADDR = 3'b001; // Data register
    localparam SR7_ADDR = 3'b111;  // Ready flag register (1=ready, 0=busy)
    
    // Processor states
    localparam STATE_INIT              = 5'b00000; // Initialize
    localparam STATE_POLL_START        = 5'b00001; // Start polling mode
    localparam STATE_POLL_CHECK_READY  = 5'b00010; // Polling: Check if POC is ready
    localparam STATE_POLL_PREPARE_DATA = 5'b00011; // Polling: Prepare to send data
    localparam STATE_POLL_SEND_DATA    = 5'b00100; // Polling: Send data
    localparam STATE_POLL_WAIT_1       = 5'b00101; // Polling: Wait cycle
    localparam STATE_POLL_SET_BUSY     = 5'b00110; // Polling: Set POC to busy
    localparam STATE_POLL_WAIT_2       = 5'b00111; // Polling: Wait cycle
    localparam STATE_POLL_WAIT_DONE    = 5'b01000; // Polling: Wait for completion
    localparam STATE_INT_START         = 5'b01001; // Start interrupt mode
    localparam STATE_INT_WAIT_IRQ      = 5'b01010; // Interrupt: Wait for IRQ
    localparam STATE_INT_PREPARE_DATA  = 5'b01011; // Interrupt: Prepare to send data
    localparam STATE_INT_SEND_DATA     = 5'b01100; // Interrupt: Send data
    localparam STATE_INT_WAIT_1        = 5'b01101; // Interrupt: Wait cycle
    localparam STATE_INT_SET_BUSY      = 5'b01110; // Interrupt: Set POC to busy
    localparam STATE_INT_WAIT_2        = 5'b01111; // Interrupt: Wait cycle
    localparam STATE_DONE              = 5'b10000; // All done
    
    // Messages to print
    reg [7:0] poll_message [0:22];  // "Hello, World! (polling)"
    reg [7:0] int_message [0:24];   // "Hello, World! (interrupt)"
    
    // State and counter registers
    reg [4:0] state, next_state;
    reg [5:0] char_index, next_char_index;
    reg [19:0] delay_counter, next_delay_counter;
    
    // Delay constants (50MHz clock = 20ns period)
    localparam WAIT_CYCLES_SHORT = 20'd50;     // 1us
    localparam WAIT_CYCLES_MEDIUM = 20'd2500;  // 50us
    localparam WAIT_CYCLES_LONG = 20'd25000;   // 500us
    
    // Initialize messages
    initial begin
        // "Hello, World! (polling)"
        poll_message[0] = "H";
        poll_message[1] = "e";
        poll_message[2] = "l";
        poll_message[3] = "l";
        poll_message[4] = "o";
        poll_message[5] = ",";
        poll_message[6] = " ";
        poll_message[7] = "W";
        poll_message[8] = "o";
        poll_message[9] = "r";
        poll_message[10] = "l";
        poll_message[11] = "d";
        poll_message[12] = "!";
        poll_message[13] = " ";
        poll_message[14] = "(";
        poll_message[15] = "p";
        poll_message[16] = "o";
        poll_message[17] = "l";
        poll_message[18] = "l";
        poll_message[19] = "i";
        poll_message[20] = "n";
        poll_message[21] = "g";
        poll_message[22] = ")";
        
        // "Hello, World! (interrupt)"
        int_message[0] = "H";
        int_message[1] = "e";
        int_message[2] = "l";
        int_message[3] = "l";
        int_message[4] = "o";
        int_message[5] = ",";
        int_message[6] = " ";
        int_message[7] = "W";
        int_message[8] = "o";
        int_message[9] = "r";
        int_message[10] = "l";
        int_message[11] = "d";
        int_message[12] = "!";
        int_message[13] = " ";
        int_message[14] = "(";
        int_message[15] = "i";
        int_message[16] = "n";
        int_message[17] = "t";
        int_message[18] = "e";
        int_message[19] = "r";
        int_message[20] = "r";
        int_message[21] = "u";
        int_message[22] = "p";
        int_message[23] = "t";
        int_message[24] = ")";
    end
    
    // Output control registers
    reg [7:0] next_data_out;
    reg next_rw;
    reg next_reg_in;
    reg [2:0] next_addr;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= STATE_INIT;
            char_index <= 6'b0;
            delay_counter <= 20'b0;
            
            // Default output values
            data_out <= 8'b0;
            rw <= 1'b0;             // Default to read
            reg_in <= 1'b0;
            addr <= 3'b0;
        end
        else begin
            state <= next_state;
            char_index <= next_char_index;
            delay_counter <= next_delay_counter;
            
            // Update outputs
            data_out <= next_data_out;
            rw <= next_rw;
            reg_in <= next_reg_in;
            addr <= next_addr;
        end
    end
    
    // Combinational logic for next state and outputs
    always @(*) begin
        // Default: keep current values
        next_state = state;
        next_char_index = char_index;
        next_delay_counter = delay_counter;
        
        // Default output values
        next_data_out = data_out;
        next_rw = 1'b0;     // Default to read
        next_reg_in = 1'b0;
        next_addr = addr;
        
        case (state)
            STATE_INIT: begin
                // Reset all outputs to safe defaults
                next_data_out = 8'b0;
                next_rw = 1'b0;
                next_reg_in = 1'b0;
                next_addr = 3'b0;
                next_char_index = 6'b0;
                next_delay_counter = 20'b0;
                
                // Move to polling mode initialization
                next_state = STATE_POLL_START;
            end
            
            STATE_POLL_START: begin
                // Initialize to polling mode (SR0 = 0)
                next_rw = 1'b1;          // Write
                next_addr = SR0_ADDR;    // SR0 register
                next_reg_in = 1'b0;      // Set to polling mode
                next_char_index = 6'b0;  // Reset character index
                
                // Add delay before checking POC status
                next_delay_counter = WAIT_CYCLES_MEDIUM;
                next_state = STATE_POLL_CHECK_READY;
            end
            
            STATE_POLL_CHECK_READY: begin
                // Wait for delay to expire
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Check if POC is ready (SR7 = 1)
                    next_rw = 1'b0;          // Read
                    next_addr = SR7_ADDR;    // SR7 register
                    
                    // Add delay for read to complete
                    next_delay_counter = WAIT_CYCLES_SHORT;
                    next_state = STATE_POLL_PREPARE_DATA;
                end
            end
            
            STATE_POLL_PREPARE_DATA: begin
                // Wait for delay to expire
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Check result of SR7 read
                    if (reg_out == 1'b1) begin
                        // POC is ready, prepare to send data
                        next_data_out = poll_message[char_index];
                        next_state = STATE_POLL_SEND_DATA;
                    end
                    else begin
                        // POC not ready, check again after delay
                        next_delay_counter = WAIT_CYCLES_MEDIUM;
                        next_state = STATE_POLL_CHECK_READY;
                    end
                end
            end
            
            STATE_POLL_SEND_DATA: begin
                // Send data to POC
                next_rw = 1'b1;                     // Write
                next_addr = DATA_ADDR;              // Data register
                next_data_out = poll_message[char_index];
                
                // Add short delay for write to complete
                next_delay_counter = WAIT_CYCLES_SHORT;
                next_state = STATE_POLL_WAIT_1;
            end
            
            STATE_POLL_WAIT_1: begin
                // Wait for delay to expire
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Move to set busy state
                    next_state = STATE_POLL_SET_BUSY;
                end
            end
            
            STATE_POLL_SET_BUSY: begin
                // Set POC to busy (SR7 = 0)
                next_rw = 1'b1;          // Write
                next_addr = SR7_ADDR;    // SR7 register
                next_reg_in = 1'b0;      // Set to busy
                
                // Add short delay for write to complete
                next_delay_counter = WAIT_CYCLES_SHORT;
                next_state = STATE_POLL_WAIT_2;
            end
            
            STATE_POLL_WAIT_2: begin
                // Wait for delay to expire
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Move to wait for POC ready
                    next_delay_counter = WAIT_CYCLES_MEDIUM;
                    next_state = STATE_POLL_WAIT_DONE;
                end
            end
            
            STATE_POLL_WAIT_DONE: begin
                // Check if POC is ready again (SR7 = 1)
                next_rw = 1'b0;          // Read
                next_addr = SR7_ADDR;    // SR7 register
                
                // Wait for delay to expire
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Check if POC is ready
                    if (reg_out == 1'b1) begin
                        // POC is ready, move to next character or mode
                        if (char_index < 22) begin
                            next_char_index = char_index + 1'b1;
                            next_delay_counter = WAIT_CYCLES_MEDIUM;
                            next_state = STATE_POLL_CHECK_READY;
                        end
                        else begin
                            // Polling message complete, switch to interrupt mode
                            next_state = STATE_INT_START;
                            next_char_index = 6'b0;
                        end
                    end
                    else begin
                        // POC not ready, check again after delay
                        next_delay_counter = WAIT_CYCLES_MEDIUM;
                    end
                end
            end
            
            STATE_INT_START: begin
                // Switch to interrupt mode (SR0 = 1)
                next_rw = 1'b1;          // Write
                next_addr = SR0_ADDR;    // SR0 register
                next_reg_in = 1'b1;      // Set to interrupt mode
                
                // Add delay to allow mode change to take effect
                next_delay_counter = WAIT_CYCLES_MEDIUM;
                next_state = STATE_INT_WAIT_IRQ;
            end
            
            STATE_INT_WAIT_IRQ: begin
                // Wait for delay to expire first
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Then wait for interrupt request (IRQ = 0)
                    if (irq == 1'b0) begin
                        next_state = STATE_INT_PREPARE_DATA;
                    end
                    else begin
                        // No interrupt yet, continue waiting
                        next_delay_counter = WAIT_CYCLES_SHORT;
                    end
                end
            end
            
            STATE_INT_PREPARE_DATA: begin
                // Prepare data for interrupt mode
                next_data_out = int_message[char_index];
                next_state = STATE_INT_SEND_DATA;
            end
            
            STATE_INT_SEND_DATA: begin
                // Send data to POC
                next_rw = 1'b1;                     // Write
                next_addr = DATA_ADDR;              // Data register
                next_data_out = int_message[char_index];
                
                // Add short delay for write to complete
                next_delay_counter = WAIT_CYCLES_SHORT;
                next_state = STATE_INT_WAIT_1;
            end
            
            STATE_INT_WAIT_1: begin
                // Wait for delay to expire
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Move to set busy state
                    next_state = STATE_INT_SET_BUSY;
                end
            end
            
            STATE_INT_SET_BUSY: begin
                // Set POC to busy (SR7 = 0)
                next_rw = 1'b1;          // Write
                next_addr = SR7_ADDR;    // SR7 register
                next_reg_in = 1'b0;      // Set to busy
                
                // Add short delay for write to complete
                next_delay_counter = WAIT_CYCLES_SHORT;
                next_state = STATE_INT_WAIT_2;
            end
            
            STATE_INT_WAIT_2: begin
                // Wait for delay to expire
                if (delay_counter > 0) begin
                    next_delay_counter = delay_counter - 1'b1;
                end
                else begin
                    // Check if we've processed all characters
                    if (char_index < 24) begin
                        next_char_index = char_index + 1'b1;
                        next_delay_counter = WAIT_CYCLES_MEDIUM;
                        next_state = STATE_INT_WAIT_IRQ;
                    end
                    else begin
                        // All done
                        next_state = STATE_DONE;
                    end
                end
            end
            
            STATE_DONE: begin
                // Stay in done state
                next_state = STATE_DONE;
                
                // Reset all outputs to safe defaults
                next_data_out = 8'b0;
                next_rw = 1'b0;
                next_reg_in = 1'b0;
                next_addr = 3'b0;
            end
            
            default: begin
                // In case of undefined state, return to safe state
                next_state = STATE_INIT;
                next_data_out = 8'b0;
                next_rw = 1'b0;
                next_reg_in = 1'b0;
                next_addr = 3'b0;
            end
        endcase
    end
    
endmodule