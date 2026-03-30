module Clock_Divider (
    input  logic       clk_in,
    input  logic       reset,
    input  logic [7:0] clk_divisor, // number of clk cycles per HALF SCLK period
    output logic       tick         // 1-cycle pulse every divisor cycles
);

    logic [7:0] counter;
    logic [7:0] divisor_reg;

    always_ff @(posedge clk_in) begin
        if (reset) begin
            counter     <= 0;
            divisor_reg <= 1;
            tick        <= 0;
        end else begin
            // Latch divisor safely at boundary
            if (counter == 0)
                divisor_reg <= (clk_divisor == 0) ? 1 : clk_divisor;

            if (counter == divisor_reg - 1) begin
                counter <= 0;
                tick    <= 1;
            end else begin
                counter <= counter + 1;
                tick    <= 0;
            end
        end
    end

endmodule
