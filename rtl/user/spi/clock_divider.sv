module Clock_Divider (
    input  wire       clk_in,      // 40 MHz system clock
    input  wire       reset,
    input  wire [7:0] clk_divisor, // From CONFIG register (e.g., 2 to 255)
    output reg        pulse_en,    // High for 1 cycle every (2 * divisor) cycles
    output wire       is_ready     // High when the divider is stable
);

    // Internal counter
    reg [7:0] counter;

    // We are ready as soon as reset is released in this simple implementation
    assign is_ready = !reset;

    always @(posedge clk_in) begin
        if (reset) begin
            counter  <= 8'h00;
            pulse_en <= 1'b0;
        end else begin
            if (counter >= clk_divisor) begin
                counter  <= 8'h00;
                pulse_en <= 1'b1; // Trigger the pulse
            end else begin
                counter  <= counter + 1'b1;
                pulse_en <= 1'b0;
            end
        end
    end

endmodule
