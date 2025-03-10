module processor (
    input wire clk,         // System clock (50MHz)
    input wire rst_n,       // Active low reset
    
    // Interface with POC
    input wire irq,         // Interrupt from POC (active low)
    output reg [7:0] data_out, // Data to POC
    output reg rw,          // 1 for write, 0 for read
    output reg reg_in,      // Output bit for register write
    input wire reg_out,     // Input bit from register read
    output reg [2:0] addr   // Register address
);

// Constants for clarity
localparam POLLING_MODE = 1'b0;
localparam INTERRUPT_MODE = 1'b1;
localparam POC_READY = 1'b1;
localparam POC_BUSY = 1'b0;

// Processor states
localparam STATE_INIT = 4'b0000;
localparam STATE_POLL_CHECK = 4'b0001;
localparam STATE_POLL_WRITE = 4'b0010;
localparam STATE_POLL_SET_BUSY = 4'b0011;
localparam STATE_POLL_WAIT = 4'b0100;
localparam STATE_SWITCH_MODE = 4'b0101;
localparam STATE_INT_WAIT = 4'b0110;
localparam STATE_INT_WRITE = 4'b0111;
localparam STATE_INT_SET_BUSY = 4'b1000;
localparam STATE_DELAY = 4'b1001;
localparam STATE_RESET_MODE = 4'b1010;

// Register addresses
localparam ADDR_SR0 = 3'b000;  // Mode control bit
localparam ADDR_SR7 = 3'b111;  // Ready/busy bit
localparam ADDR_BR = 3'b100;   // Data buffer register (assuming)

// Messages to print
reg [7:0] polling_msg [0:23];  // " Hello, World! (polling)"
reg [7:0] interrupt_msg [0:25]; // " Hello, World! (interrupt)"
integer msg_index;
integer delay_counter;
localparam DELAY_1SEC = 50000; // 1ms second at 50MHz

// State registers
reg [3:0] state, next_state;
reg current_mode;

// Initialize messages with ASCII values
initial begin
    // " Hello, World! (polling)" ASCII values - space at index 0
    polling_msg[0] = 8'h20; // Space
    polling_msg[1] = 8'h48; // H
    polling_msg[2] = 8'h65; // e
    polling_msg[3] = 8'h6C; // l
    polling_msg[4] = 8'h6C; // l
    polling_msg[5] = 8'h6F; // o
    polling_msg[6] = 8'h2C; // ,
    polling_msg[7] = 8'h20; //  
    polling_msg[8] = 8'h57; // W
    polling_msg[9] = 8'h6F; // o
    polling_msg[10] = 8'h72; // r
    polling_msg[11] = 8'h6C; // l
    polling_msg[12] = 8'h64; // d
    polling_msg[13] = 8'h21; // !
    polling_msg[14] = 8'h20; //  
    polling_msg[15] = 8'h28; // (
    polling_msg[16] = 8'h70; // p
    polling_msg[17] = 8'h6F; // o
    polling_msg[18] = 8'h6C; // l
    polling_msg[19] = 8'h6C; // l
    polling_msg[20] = 8'h69; // i
    polling_msg[21] = 8'h6E; // n
    polling_msg[22] = 8'h67; // g
    polling_msg[23] = 8'h29; // )

    // " Hello, World! (interrupt)" ASCII values - space at index 0
    interrupt_msg[0] = 8'h20; // Space
    interrupt_msg[1] = 8'h48; // H
    interrupt_msg[2] = 8'h65; // e
    interrupt_msg[3] = 8'h6C; // l
    interrupt_msg[4] = 8'h6C; // l
    interrupt_msg[5] = 8'h6F; // o
    interrupt_msg[6] = 8'h2C; // ,
    interrupt_msg[7] = 8'h20; //  
    interrupt_msg[8] = 8'h57; // W
    interrupt_msg[9] = 8'h6F; // o
    interrupt_msg[10] = 8'h72; // r
    interrupt_msg[11] = 8'h6C; // l
    interrupt_msg[12] = 8'h64; // d
    interrupt_msg[13] = 8'h21; // !
    interrupt_msg[14] = 8'h20; //  
    interrupt_msg[15] = 8'h28; // (
    interrupt_msg[16] = 8'h69; // i
    interrupt_msg[17] = 8'h6E; // n
    interrupt_msg[18] = 8'h74; // t
    interrupt_msg[19] = 8'h65; // e
    interrupt_msg[20] = 8'h72; // r
    interrupt_msg[21] = 8'h72; // r
    interrupt_msg[22] = 8'h75; // u
    interrupt_msg[23] = 8'h70; // p
    interrupt_msg[24] = 8'h74; // t
    interrupt_msg[25] = 8'h29; // )
end

// Sequential logic - register updates
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        state <= STATE_INIT;
        msg_index <= 0;
        delay_counter <= 0;
        current_mode <= POLLING_MODE;
    end
    else begin
        state <= next_state;
        
        // Update counters based on state transitions
        if (state != next_state) begin
            if (next_state == STATE_POLL_WRITE || next_state == STATE_INT_WRITE) begin
                // Only increment message index when actually writing
                if (current_mode == POLLING_MODE) begin
                    if (msg_index < 23) begin
                        msg_index <= msg_index + 1;
                    end
                end else begin
                    if (msg_index < 25) begin
                        msg_index <= msg_index + 1;
                    end
                end
            end
            else if (next_state == STATE_DELAY) begin
                msg_index <= 0;  // Reset message index for next cycle
                delay_counter <= 0;  // Reset delay counter
            end
            else if (next_state == STATE_SWITCH_MODE) begin
                current_mode <= INTERRUPT_MODE;
                msg_index <= 0;  // Reset message index when switching modes
            end
            else if (next_state == STATE_RESET_MODE) begin
                current_mode <= POLLING_MODE;
                msg_index <= 0;  // Reset message index when switching modes
            end
        end
        
        // Increment delay counter when in DELAY state
        if (state == STATE_DELAY) begin
            delay_counter <= delay_counter + 1;
        end
    end
end

// Combinational logic - next state and outputs
always @(*) begin
    // Default values
    next_state = state;
    data_out = 8'h00;
    rw = 1'b0;       // Default to read
    reg_in = 1'b0;
    addr = 3'b000;
    
    case (state)
        STATE_INIT: begin
            // Initial state - set polling mode
            rw = 1'b1;        // Write
            addr = ADDR_SR0;  // SR0 register
            reg_in = POLLING_MODE;
            next_state = STATE_POLL_CHECK;
        end
        
        STATE_POLL_CHECK: begin
            // Check if POC is ready in polling mode
            rw = 1'b0;        // Read
            addr = ADDR_SR7;  // SR7 register (ready/busy bit)
            
            // If SR7 is 1 (ready), proceed to write data
            if (reg_out == POC_READY) begin
                if (msg_index <= 23) begin
                    next_state = STATE_POLL_WRITE;
                end else begin
                    next_state = STATE_SWITCH_MODE;
                end
            end
        end
        
        STATE_POLL_WRITE: begin
            // Write data to BR register
            rw = 1'b1;        // Write
            addr = ADDR_BR;   // Data buffer register
            data_out = polling_msg[msg_index];
            
            next_state = STATE_POLL_SET_BUSY;
        end
        
        STATE_POLL_SET_BUSY: begin
            // Set SR7 to 0 (busy)
            rw = 1'b1;        // Write
            addr = ADDR_SR7;  // SR7 register
            reg_in = POC_BUSY;
            
            next_state = STATE_POLL_WAIT;
        end
        
        STATE_POLL_WAIT: begin
            // Wait until POC is ready again
            rw = 1'b0;        // Read
            addr = ADDR_SR7;  // SR7 register
            
            if (reg_out == POC_READY) begin
                // If we've printed all characters
                if (msg_index >= 23) begin
                    next_state = STATE_SWITCH_MODE;
                end
                else begin
                    next_state = STATE_POLL_WRITE;
                end
            end
        end
        
        STATE_SWITCH_MODE: begin
            // Switch to interrupt mode
            rw = 1'b1;        // Write
            addr = ADDR_SR0;  // SR0 register
            reg_in = INTERRUPT_MODE;
            
            next_state = STATE_INT_WAIT;
        end
        
        STATE_INT_WAIT: begin
            // Wait for interrupt from POC
            if (irq == 1'b0) begin  // IRQ is active low
                next_state = STATE_INT_WRITE;
            end
        end
        
        STATE_INT_WRITE: begin
            // Write data in interrupt mode
            rw = 1'b1;        // Write
            addr = ADDR_BR;   // Data buffer register
            data_out = interrupt_msg[msg_index];
            
            next_state = STATE_INT_SET_BUSY;
        end
        
        STATE_INT_SET_BUSY: begin
            // Set SR7 to 0 (busy)
            rw = 1'b1;        // Write
            addr = ADDR_SR7;  // SR7 register
            reg_in = POC_BUSY;
            
            if (msg_index >= 25) begin
                next_state = STATE_DELAY;
            end
            else begin
                next_state = STATE_INT_WAIT;
            end
        end
        
        STATE_DELAY: begin
            // Wait for 1 second before repeating
            if (delay_counter >= DELAY_1SEC - 1) begin
                next_state = STATE_RESET_MODE;
            end
        end
        
        STATE_RESET_MODE: begin
            // Reset to polling mode and start over
            rw = 1'b1;        // Write
            addr = ADDR_SR0;  // SR0 register
            reg_in = POLLING_MODE;
            
            next_state = STATE_POLL_CHECK;
        end
        
        default: next_state = STATE_INIT;
    endcase
end

endmodule