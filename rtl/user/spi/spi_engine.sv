module SPI_Engine (
    input  logic       clk,
    input  logic       reset,

    // Byte interface
    input  logic [7:0] tx_byte,
    input  logic       start_byte,
    output logic [7:0] rx_byte,
    output logic       byte_done,

    // Configuration
    input  logic       cpol,
    input  logic       cpha,
    input  logic [7:0] clk_divider,
    input  logic       cs,

    // SPI pins
    output logic       mosi,
    input  logic       miso,
    output logic       sclk,
    output logic       cs_out
);

    logic [3:0] bit_count;   
    logic [7:0] tx_shifter;  
    logic [7:0] rx_shifter;  
    logic       working;     
    logic       sclk_reg;    
    logic       half_cycle;  // Tracks which half of the SCLK period we are in
    logic       tick;        // From Clock_Divider

    assign sclk = sclk_reg;
    assign rx_byte = rx_shifter;
    assign cs_out = cs;
    assign mosi = tx_shifter[7];

    // Instantiate your new Clock_Divider
    Clock_Divider clk_div_inst (
        .clk_in(clk),
        .reset(reset || !working), // Keep divider in reset when not working to sync phase
        .clk_divisor(clk_divider),
        .tick(tick)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            working    <= 1'b0;
            bit_count  <= 4'd0;
            sclk_reg   <= cpol;
            half_cycle <= 1'b0;
            byte_done  <= 1'b0;
            tx_shifter <= 8'h00;
        end else if (start_byte && !working) begin
            working    <= 1'b1;
            tx_shifter <= tx_byte;
            bit_count  <= 4'd0;
            half_cycle <= 1'b0;
            byte_done  <= 1'b0;
            sclk_reg   <= cpol; 
        end else if (working && tick) begin
            // Toggle SCLK every tick
            sclk_reg   <= !sclk_reg;
            half_cycle <= !half_cycle;

            // SPI Logic: Sample vs Shift
            // SPI standard: 
            // CPHA=0: First edge is Sample, Second edge is Shift
            // CPHA=1: First edge is Shift, Second edge is Sample
            
            if (half_cycle == cpha) begin
                // --- SAMPLE PHASE ---
                rx_shifter <= {rx_shifter[6:0], miso};
            end else begin
                // --- SHIFT PHASE ---
                if (bit_count == 4'd7) begin
                    working    <= 1'b0;
                    byte_done  <= 1'b1;
                    sclk_reg   <= cpol; // Ensure we return to idle state
                end else begin
                    tx_shifter <= {tx_shifter[6:0], 1'b0};
                    bit_count  <= bit_count + 1'b1;
                end
            end
        end else begin
            byte_done <= 1'b0; // Ensure pulse behavior
        end
    end

endmodule
