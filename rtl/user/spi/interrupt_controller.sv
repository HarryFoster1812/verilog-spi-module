module Interrupt_Controller (
    input  wire        clk,
    input  wire        reset,
    
    // Events from SPI module
    input  wire        byte_done_event,
    input  wire        block_done_event,
    input  wire        error_event,
    
    // Interrupt enable register
    input  wire [3:0]  irq_enable,
    
    // CPU control
    input  wire        irq_clear,
    
    // Outputs
    output reg  [3:0]  irq_o,
    output reg  [3:0]  irq_status
);
    // Masked event -> irq_o
    // irq_status records pending interrupts
endmodule
