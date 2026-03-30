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

    logic [3:0] pending_irqs;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            pending_irqs <= 4'b0;
        end else begin
            // Catch the pulses
            if (byte_done_event)  pending_irqs[0] <= 1'b1;
            if (block_done_event) pending_irqs[1] <= 1'b1;
            if (error_event)      pending_irqs[2] <= 1'b1;
            
            // Clear logic triggered on a CPU Write to Status
            if (irq_clear) begin
                pending_irqs <= 4'b0;
            end
        end
    end

    // Only assert the output IRQ if the specific interrupt is enabled
    assign irq_status = pending_irqs;
    assign irq_o      = pending_irqs & irq_enable;

endmodule
