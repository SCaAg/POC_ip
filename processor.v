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
    localparam STATE_INIT              = 4'b0000; // Initialize
    localparam STATE_POLL_CHECK_READY  = 4'b0001; // Polling: Check if POC is ready
    localparam STATE_POLL_SEND_DATA    = 4'b0010; // Polling: Send data
    localparam STATE_POLL_SET_BUSY     = 4'b0011; // Polling: Set POC to busy
    localparam STATE_POLL_WAIT         = 4'b0100; // Polling: Wait for completion
    localparam STATE_SET_INTERRUPT     = 4'b0101; // Switch to interrupt mode
    localparam STATE_INT_WAIT_IRQ      = 4'b0110; // Interrupt: Wait for IRQ
    localparam STATE_INT_SEND_DATA     = 4'b0111; // Interrupt: Send data
    localparam STATE_INT_SET_BUSY      = 4'b1000; // Interrupt: Set POC to busy
    localparam STATE_DONE              = 4'b1001; // All done
    
    // Messages to print
    reg [7:0] poll_message [0:21];  // "Hello, World! (polling)"
    reg [7:0] int_message [0:24];   // "Hello, World! (interrupt)"
    
    // State and counter registers
    reg [3:0] state, next_state;
    reg [5:0] char_index, next_char_index;
    reg [1:0] delay_counter, next_delay_counter;
    
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
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            state <= STATE_INIT;
            char_index <= 6'b0;
            delay_counter <= 2'b0;
            rw <= 1'b0;             // Default to read
            reg_in <= 1'b0;
            addr <= 3'b0;
            data_out <= 8'b0;
        end
        else begin
            state <= next_state;
            char_index <= next_char_index;
            delay_counter <= next_delay_counter;
        end
    end
    
    // Combinational logic for next state and outputs
    always @(*) begin
        // Default: keep current values
        next_state = state;
        next_char_index = char_index;
        next_delay_counter = delay_counter;
        rw = 1'b0;         // Default to read
        reg_in = 1'b0;
        addr = 3'b0;
        data_out = 8'b0;
        
        case (state)
            STATE_INIT: begin
                // Initialize to polling mode (SR0 = 0)
                rw = 1'b1;          // Write
                addr = SR0_ADDR;    // SR0 register
                reg_in = 1'b0;      // Set to polling mode
                next_state = STATE_POLL_CHECK_READY;
                next_char_index = 6'b0;
            end
            
            STATE_POLL_CHECK_READY: begin
                // Check if POC is ready (SR7 = 1)
                rw = 1'b0;          // Read
                addr = SR7_ADDR;    // SR7 register
                
                // Add a small delay to allow read to complete
                if (delay_counter < 2'b11) begin
                    next_delay_counter = delay_counter + 1'b1;
                end
                else begin
                    next_delay_counter = 2'b0;
                    
                    // If POC is ready, move to send data
                    if (reg_out == 1'b1) begin
                        next_state = STATE_POLL_SEND_DATA;
                    end
                end
            end
            
            STATE_POLL_SEND_DATA: begin
                // Send data to POC
                rw = 1'b1;                     // Write
                addr = DATA_ADDR;              // Data register
                data_out = poll_message[char_index];
                
                next_state = STATE_POLL_SET_BUSY;
            end
            
            STATE_POLL_SET_BUSY: begin
                // Set POC to busy (SR7 = 0)
                rw = 1'b1;          // Write
                addr = SR7_ADDR;    // SR7 register
                reg_in = 1'b0;      // Set to busy
                
                next_state = STATE_POLL_WAIT;
            end
            
            STATE_POLL_WAIT: begin
                // Check if POC is ready again (SR7 = 1)
                rw = 1'b0;          // Read
                addr = SR7_ADDR;    // SR7 register
                
                // Add a small delay to allow read to complete
                if (delay_counter < 2'b11) begin
                    next_delay_counter = delay_counter + 1'b1;
                end
                else begin
                    next_delay_counter = 2'b0;
                    
                    // If POC is ready, move to next character or mode
                    if (reg_out == 1'b1) begin
                        if (char_index < 22) begin
                            next_char_index = char_index + 1'b1;
                            next_state = STATE_POLL_CHECK_READY;
                        end
                        else begin
                            // Polling message complete, switch to interrupt mode
                            next_state = STATE_SET_INTERRUPT;
                            next_char_index = 6'b0;
                        end
                    end
                end
            end
            
            STATE_SET_INTERRUPT: begin
                // Switch to interrupt mode (SR0 = 1)
                rw = 1'b1;          // Write
                addr = SR0_ADDR;    // SR0 register
                reg_in = 1'b1;      // Set to interrupt mode
                
                next_state = STATE_INT_WAIT_IRQ;
            end
            
            STATE_INT_WAIT_IRQ: begin
                // Wait for interrupt request (IRQ = 0)
                if (irq == 1'b0) begin
                    next_state = STATE_INT_SEND_DATA;
                end
            end
            
            STATE_INT_SEND_DATA: begin
                // Send data to POC
                rw = 1'b1;                     // Write
                addr = DATA_ADDR;              // Data register
                data_out = int_message[char_index];
                
                next_state = STATE_INT_SET_BUSY;
            end
            
            STATE_INT_SET_BUSY: begin
                // Set POC to busy (SR7 = 0)
                rw = 1'b1;          // Write
                addr = SR7_ADDR;    // SR7 register
                reg_in = 1'b0;      // Set to busy
                
                if (char_index < 24) begin
                    next_char_index = char_index + 1'b1;
                    next_state = STATE_INT_WAIT_IRQ;
                end
                else begin
                    // All done
                    next_state = STATE_DONE;
                end
            end
            
            STATE_DONE: begin
                // Stay in done state
                next_state = STATE_DONE;
            end
            
            default: next_state = STATE_INIT;
        endcase
    end
    
endmodule