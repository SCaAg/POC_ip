module print_module (
    input wire clk,           // System clock (50MHz)
    input wire rst_n,         // Active low reset
    
    // Interface with POC
    input wire [7:0] print_data,  // Data from POC
    input wire pulse_request,    // Pulse request from POC
    output reg print_ready,      // Ready signal to POC
    
    // UART TX output
    output reg uart_tx           // UART TX signal
);

// Constants for baud rate generation
localparam BAUD_RATE = 9600;   // Changed to 9600 as requested
localparam CLOCK_FREQ = 50000000; // 50MHz
localparam CLOCKS_PER_BIT = CLOCK_FREQ / BAUD_RATE;

// State definitions for print module
localparam STATE_IDLE = 2'b00;
localparam STATE_RECEIVE = 2'b01;
localparam STATE_TRANSMIT = 2'b10;
localparam STATE_WAIT_COMPLETION = 2'b11;

// State definitions for UART transmitter
localparam UART_IDLE = 3'b000;
localparam UART_START_BIT = 3'b001;
localparam UART_DATA_BITS = 3'b010;
localparam UART_STOP_BIT = 3'b011;
localparam UART_CLEANUP = 3'b100;

// Registers for print module
reg [1:0] state, next_state;
reg [7:0] tx_data, next_tx_data;
reg start_tx, next_start_tx;
reg next_print_ready;

// Registers for UART transmitter
reg [2:0] uart_state, next_uart_state;
reg [2:0] bit_index, next_bit_index;      // 8 bits (0-7)
reg [15:0] clk_counter, next_clk_counter; // Counter for baud rate generation
reg next_uart_tx;
reg tx_done, next_tx_done;

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        // Reset all registers
        state <= STATE_IDLE;
        tx_data <= 8'h00;
        start_tx <= 1'b0;
        print_ready <= 1'b1;  // Ready to receive data initially
        
        uart_state <= UART_IDLE;
        bit_index <= 3'b000;
        clk_counter <= 16'h0000;
        uart_tx <= 1'b1;      // UART idle state is high
        tx_done <= 1'b0;
    end
    else begin
        // Update all registers
        state <= next_state;
        tx_data <= next_tx_data;
        start_tx <= next_start_tx;
        print_ready <= next_print_ready;
        
        uart_state <= next_uart_state;
        bit_index <= next_bit_index;
        clk_counter <= next_clk_counter;
        uart_tx <= next_uart_tx;
        tx_done <= next_tx_done;
    end
end

// Print module state machine - handles interaction with POC
always @(*) begin
    // Default values - maintain current state
    next_state = state;
    next_tx_data = tx_data;
    next_start_tx = 1'b0;      // Default is not to start transmission
    next_print_ready = print_ready;
    
    case (state)
        STATE_IDLE: begin
            // Ready to receive a new character
            next_print_ready = 1'b1;
            
            if (pulse_request) begin
                // Received pulse request from POC
                next_state = STATE_RECEIVE;
                next_print_ready = 1'b0;  // No longer ready
            end
        end
        
        STATE_RECEIVE: begin
            // Capture the data to transmit
            next_tx_data = print_data;
            next_state = STATE_TRANSMIT;
        end
        
        STATE_TRANSMIT: begin
            // Start UART transmission
            next_start_tx = 1'b1;
            next_state = STATE_WAIT_COMPLETION;
        end
        
        STATE_WAIT_COMPLETION: begin
            // Wait for UART transmission to complete
            if (tx_done) begin
                next_state = STATE_IDLE;
            end
        end
        
        default: next_state = STATE_IDLE;
    endcase
end

// UART transmitter state machine
always @(*) begin
    // Default values - maintain current state
    next_uart_state = uart_state;
    next_bit_index = bit_index;
    next_clk_counter = clk_counter;
    next_uart_tx = uart_tx;
    next_tx_done = 1'b0;  // Default is not done
    
    case (uart_state)
        UART_IDLE: begin
            // Idle state - waiting for transmission request
            next_uart_tx = 1'b1;  // Idle state is high
            next_clk_counter = 16'h0000;
            next_bit_index = 3'b000;
            
            if (start_tx) begin
                // Start bit
                next_uart_state = UART_START_BIT;
            end
        end
        
        UART_START_BIT: begin
            // Send start bit (logic low)
            next_uart_tx = 1'b0;
            
            // Count clock cycles for one bit period
            if (clk_counter < CLOCKS_PER_BIT - 1) begin
                next_clk_counter = clk_counter + 16'h0001;
            end
            else begin
                next_clk_counter = 16'h0000;
                next_uart_state = UART_DATA_BITS;
            end
        end
        
        UART_DATA_BITS: begin
            // Send data bits (LSB first)
            next_uart_tx = tx_data[bit_index];
            
            // Count clock cycles for one bit period
            if (clk_counter < CLOCKS_PER_BIT - 1) begin
                next_clk_counter = clk_counter + 16'h0001;
            end
            else begin
                next_clk_counter = 16'h0000;
                
                // Move to next bit or to stop bit
                if (bit_index < 3'b111) begin
                    next_bit_index = bit_index + 3'b001;
                end
                else begin
                    next_uart_state = UART_STOP_BIT;
                end
            end
        end
        
        UART_STOP_BIT: begin
            // Send stop bit (logic high)
            next_uart_tx = 1'b1;
            
            // Count clock cycles for one bit period
            if (clk_counter < CLOCKS_PER_BIT - 1) begin
                next_clk_counter = clk_counter + 16'h0001;
            end
            else begin
                next_clk_counter = 16'h0000;
                next_uart_state = UART_CLEANUP;
            end
        end
        
        UART_CLEANUP: begin
            // Cleanup and signal completion
            next_uart_tx = 1'b1;  // Maintain high
            next_tx_done = 1'b1;  // Signal transmission complete
            next_uart_state = UART_IDLE;
        end
        
        default: next_uart_state = UART_IDLE;
    endcase
end

endmodule