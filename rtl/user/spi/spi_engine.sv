module SPI_Engine (
	input  wire       clk,
	input  wire       reset,

	// Byte interface
	input  wire [7:0] tx_byte,
		input  wire       start_byte,
		output wire [7:0] rx_byte,
		output wire       byte_done,

		// Configuration
		input  wire       cpol,
			input  wire       cpha,
			input  wire [7:0] clk_divider,
			input  wire       cs,

			// SPI pins
			output wire       mosi,
				input  wire       miso,
				output wire       sclk,
				output wire       cs_out
				);
				// Internal shift registers, clock divider, bit counter

				reg [3:0] bit_count;   // 0-7 bits, plus one extra for state management
				reg [7:0] tx_shifter;  // Shift register for MOSI
				reg [7:0] rx_shifter;  // Shift register for MISO
				reg       working;     // High when a transfer is in progress
				reg       sclk_reg;    // Internal SCLK register
				reg       half_cycle;  // Toggles every pulse_en to track half-clock cycles

				assign sclk = sclk_reg;
				assign rx_byte = rx_shifter;
				assign cs_out = cs; // Passed through from register
				assign mosi = tx_shifter[7]; // MSB first

				logic pulse_en, is_ready;

				Clock_Divider clk_div(
					.clk_in(clk),      // 40 MHz system clock
					.reset(reset),
					.clk_divisor(clk_divider), 
					.pulse_en(pulse_en),    // High for 1 cycle every (2 * divisor) cycles
					.is_ready(is_ready)     // High when the divider is stable
					);

					always @(posedge clk) begin
						if (reset) begin
							working    <= 1'b0;
							bit_count  <= 4'd0;
							sclk_reg   <= cpol; 
							half_cycle <= 1'b0;
							byte_done  <= 1'b0;
					end else if (start_byte && !working) begin
						working    <= 1'b1;
						tx_shifter <= tx_byte;
						bit_count  <= 4'd0;
						half_cycle <= 1'b0;
						byte_done  <= 1'b0;
						// Handle CPHA=0:
					end else if (working && pulse_en) begin
						half_cycle <= !half_cycle;

						// Handle SCLK Toggling
						sclk_reg <= !sclk_reg;

						// Logic for Shifting and Sampling
						// If CPHA=0: Sample on 1st pulse (leading edge), Shift on 2nd (trailing)
						// If CPHA=1: Shift on 1st pulse (leading edge), Sample on 2nd (trailing)

						if (half_cycle == cpha) begin
							// SAMPLE PHASE
							rx_shifter <= {rx_shifter[6:0], miso};
						end else begin
							// SHIFT PHASE 
							if (bit_count == 4'd7) begin
								working   <= 1'b0;
								byte_done <= 1'b1;
								sclk_reg  <= cpol; // Return to Idle
							end else begin
								tx_shifter <= {tx_shifter[6:0], 1'b0};
								bit_count  <= bit_count + 1'b1;
							end
						end
					end else begin
						byte_done <= 1'b0; // Pulse byte_done for only one cycle
					end
				end

endmodule
