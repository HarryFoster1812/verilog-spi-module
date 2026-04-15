module SPI_Slave_Dummy (
  input  logic sclk,
  input  logic mosi,
  output logic miso,
  input  logic cs_n
  );


  reg [7:0] data_out; // Data received
  reg [2:0] bit_count;    // Bit counter

  initial begin
    data_out = 8'd42;
  end

  always @(posedge sclk , negedge cs_n) begin
    if (!cs_n) begin // Active when cs is low
      data_out <= {data_out[6:0], mosi}; // Shift in data
      bit_count <= bit_count + 1; // Increment bit counter
      miso <= data_out[7]; // Send MSB back
    end else begin
      bit_count <= 0; // Reset bit counter when SS is high
      miso <= 1; // High impedance when not selected
    end
  end
  endmodule
