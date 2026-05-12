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
    logic       pending;     // High when we are waiting for the next tick to start
    logic       sclk_reg;    
    logic       tick;        

    assign sclk = sclk_reg;
    assign rx_byte = rx_shifter;
    assign cs_out = cs;
    assign mosi = tx_shifter[7];

    // Clock divider is now free-running (only reset by global reset)
    Clock_Divider clk_div_inst (
        .clk_in(clk),
        .reset(reset), 
        .clk_divisor(clk_divider),
        .tick(tick)
    );

logic [4:0] tick_count; // Counts 0 to 15 half-cycles

    always_ff @(posedge clk) begin
        if (reset) begin
            working    <= 1'b0;
            pending    <= 1'b0;
            sclk_reg   <= cpol;
            tick_count <= 5'd0;
            byte_done  <= 1'b0;
        end else begin
            byte_done <= 1'b0;

            if (start_byte && !working) begin
                pending    <= 1'b1;
                tx_shifter <= tx_byte;
            end

            // synchronize start with the next available tick
            if (pending && tick) begin
                pending    <= 1'b0;
                working    <= 1'b1;
                tick_count <= 5'd0;
                
                sclk_reg   <= !sclk_reg; // First Toggle

                // IMMEDIATE SAMPLE for Mode 0
                if (cpha == 1'b0) begin
                    rx_shifter <= {rx_shifter[6:0], miso};
                end
                tick_count <= 5'd1; 
            end
            
            else if (working && tick) begin
                sclk_reg <= !sclk_reg;
                
                // tick_count[0] == 0: Leading Edge (Bit 0, 2, 4, ect)
                // tick_count[0] == 1: Trailing Edge (Bit 1, 3, 5, ect)
                if (tick_count[0] == cpha) begin
                    // SAMPLE PHASE
                    rx_shifter <= {rx_shifter[6:0], miso};
                end else begin
                    // SHIFT PHASE
                    if (tick_count < 15) begin
                        tx_shifter <= {tx_shifter[6:0], 1'b0};
                    end
                end

                // Increment and Exit
                if (tick_count == 5'd15) begin
                    working    <= 1'b0;
                    byte_done  <= 1'b1;
                    sclk_reg   <= cpol; // Force return to idle
                end else begin
                    tick_count <= tick_count + 1'b1;
                end
            end
        end
    end

endmodule
