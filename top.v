module top (
    input wire clk,     // System clock (50MHz)
    input wire rst_n,   // Active low reset
    
    // UART output
    output wire uart_tx // UART TX signal
);

    // Internal connections between modules
    wire irq;                // Interrupt request from POC to processor
    wire [7:0] data_to_poc; // Data from processor to POC
    wire rw;                // Read/write signal
    wire reg_out_poc;       // Register output from POC to processor
    wire reg_in_proc;       // Register input from processor to POC
    wire [2:0] addr;        // Register address
    
    wire [7:0] print_data;  // Data from POC to print module
    wire pulse_request;     // Pulse request from POC to print module
    wire print_ready;       // Ready signal from print module to POC

    // Instantiate processor module
    processor processor_inst (
        .clk(clk),
        .rst_n(rst_n),
        .irq(irq),
        .data_out(data_to_poc),
        .rw(rw),
        .reg_in(reg_in_proc),
        .reg_out(reg_out_poc),
        .addr(addr)
    );
    
    // Instantiate POC module
    poc poc_inst (
        .clk(clk),
        .rst_n(rst_n),
        .irq(irq),
        .data_in(data_to_poc),
        .rw(rw),
        .reg_in(reg_in_proc),
        .reg_out(reg_out_poc),
        .addr(addr),
        .print_ready(print_ready),
        .print_data(print_data),
        .pulse_request(pulse_request)
    );
    
    // Instantiate print module
    print_module print_inst (
        .clk(clk),
        .rst_n(rst_n),
        .print_data(print_data),
        .pulse_request(pulse_request),
        .print_ready(print_ready),
        .uart_tx(uart_tx)
    );

endmodule