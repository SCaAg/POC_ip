module testbench;
    // Inputs to the top module
    reg clk;
    reg rst_n;
    
    // Outputs from the top module
    wire uart_tx;
    
    // Clock generation parameters
    localparam CLK_PERIOD = 20; // 50MHz => 20ns period
    
    // Instantiate the top module
    top dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );
    
    // Clock generation
    always begin
        #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // UART reception parameters
    localparam BAUD_RATE = 9600;
    localparam BIT_PERIOD = 1000000000/BAUD_RATE; // in ns
    
    // Task to monitor UART output
    task monitor_uart;
        input integer timeout_ms;
        
        integer timeout_cycles;
        reg [7:0] rx_byte;
        integer bit_count;
        reg start_bit_detected;
        integer i;
        time last_change;
        time current_time;
        
        begin
            timeout_cycles = timeout_ms * 1000000 / CLK_PERIOD;
            start_bit_detected = 0;
            bit_count = 0;
            last_change = $time;
            
            for (i = 0; i < timeout_cycles; i = i + 1) begin
                @(negedge uart_tx); // Wait for start bit (high to low transition)
                
                if (!start_bit_detected) begin
                    start_bit_detected = 1;
                    $display("Start bit detected at time %t", $time);
                    
                    // Wait half a bit period to sample in the middle
                    #(BIT_PERIOD/2);
                    
                    // Verify start bit is still low
                    if (uart_tx != 0) begin
                        $display("Error: False start bit at time %t", $time);
                        start_bit_detected = 0;
                    end
                    else begin
                        // Wait for first data bit
                        #(BIT_PERIOD);
                        
                        // Sample 8 data bits
                        for (bit_count = 0; bit_count < 8; bit_count = bit_count + 1) begin
                            rx_byte[bit_count] = uart_tx;
                            #(BIT_PERIOD);
                        end
                        
                        // Verify stop bit
                        if (uart_tx != 1) begin
                            $display("Error: Invalid stop bit at time %t", $time);
                        end
                        else begin
                            $display("Received byte: %c (0x%h) at time %t", rx_byte, rx_byte, $time);
                        end
                        
                        start_bit_detected = 0;
                    end
                end
                else begin
                    @(posedge clk);
                end
            end
        end
    endtask
    
    // Test sequence
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        
        // Reset sequence
        #100;
        rst_n = 1;
        
        $display("Starting test at time %t", $time);
        $display("Monitoring UART output (Baud Rate: %d)...", BAUD_RATE);
        
        // Monitoring UART output for a period
        monitor_uart(5000); // Monitor for 5 seconds
        
        $display("Test completed at time %t", $time);
        $finish;
    end
    
    // Optional: Monitor key signals
    initial begin
        $monitor("Time=%t, rst_n=%b, uart_tx=%b", $time, rst_n, uart_tx);
    end
    
endmodule