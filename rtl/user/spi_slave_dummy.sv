module SPI_Slave_Dummy (
    input  logic sclk,
    input  logic mosi,
    output logic miso,
    input  logic cs_n  // Active Low Chip Select
);

    logic [7:0] shift_reg;
    logic [7:0] data_to_send;
    logic [2:0] bit_count;

    // data that will be sent back
		// the answer to the Ultimate Question of Life, the Universe and Everything
		initial begin 
			data_to_send = 8'd42;
			shift_reg = 8'd42;
			bit_count = 3'h7;
		end

    // SPI is Shift-Left: MSB first
    assign miso = shift_reg[7];

    always @(posedge sclk or posedge cs_n) begin
        if (cs_n) begin
            // When deselected, reset bit counter and load next pattern
            bit_count <= 3'h7;
            shift_reg <= data_to_send; 
        end else begin
            // Capture MOSI into the LSB and shift MSB out to MISO
            shift_reg <= {shift_reg[6:0], mosi};
            
            if (bit_count == 3'h0) begin
                bit_count <= 3'h7;
                // Once a full byte is received, let's prepare the 
                // "Twist": send back the inversion of what we just got.
                // This proves the full-duplex path is working.
                data_to_send <= ~{shift_reg[6:0], mosi};
								shift_reg <= ~{shift_reg[6:0], mosi};
            end else begin
                bit_count <= bit_count - 1;
            end
        end
    end

endmodule
