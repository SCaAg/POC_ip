`timescale 1ns/1ps

module top_tb();

    // Test bench signals
    reg clk;
    reg rst_n;
    wire uart_tx;

    // Clock period definitions
    localparam CLK_PERIOD = 20; // 50MHz = 20ns period

    // Instantiate the Unit Under Test (UUT)
    top uut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_tx(uart_tx)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize inputs
        rst_n = 0;

        // Wait for 100ns for global reset
        #100;
        rst_n = 1;

        // Wait for 1 second
        #1_000_000_000;

        // End simulation
        $finish;
    end

    // Optional: Monitor changes
    initial begin
        $monitor("Time=%0t rst_n=%b uart_tx=%b", $time, rst_n, uart_tx);
    end

    // Optional: Generate VCD file for waveform viewing
    initial begin
        $dumpfile("top_tb.vcd");
        $dumpvars(0, top_tb);
    end

endmodule