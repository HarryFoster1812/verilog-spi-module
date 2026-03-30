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
				// Internal shift registers, clock divider, bit counter

  logic [3:0] bit_count;   // 0-7 bits, plus one extra for state management
  logic [7:0] tx_shifter;  // Shift register for MOSI
  logic [7:0] rx_shifter;  // Shift register for MISO
  logic       working;     // High when a transfer is in progress
  logic       sclk_reg;    // Internal SCLK register
  logic       half_cycle;  // Toggles every pulse_en to track half-clock cycles

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

  always_ff @(posedge clk) begin
    if (reset) begin
      working    <= 1'b0;
      bit_count  <= 4'd0;
      sclk_reg   <= cpol;
      half_cycle <= 1'b0;
      byte_done  <= 0;
    end else if (start_byte && !working) begin
			// Start engine 
      working    <= 1'b1;
      tx_shifter <= tx_byte;
      bit_count  <= 4'd0;
      half_cycle <= 1'b0;
      byte_done  <= 0;
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
          byte_done <= 1;
          sclk_reg  <= cpol; // Return to Idle
        end else begin
          tx_shifter <= {tx_shifter[6:0], 1'b0};
          bit_count  <= bit_count + 1'b1;
        end
      end
    end else begin
      byte_done <= 0; // Pulse byte_done for only one cycle
    end
  end

endmodule
