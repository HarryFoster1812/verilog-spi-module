module SPI_Controller (
    input  wire        clk,						// system clock
    input  wire        reset,
    
    // Control signals from CPU/User_Peripheral
    input  wire        start,          // start transfer
    input  wire        stop,           // abort transfer
    input  wire        block_mode,     // 1 = block transfer, 0 = byte transfer
    input  wire [7:0]  tx_byte,        // CPU writes single byte
    output wire [7:0]  rx_byte,        // CPU reads received byte
    input  wire [15:0] block_len,      // number of bytes for block transfer
    output wire        busy,           // SPI engine busy
    
    // Buffer interface (for block transfers)
    input  wire [8:0]  buffer_addr,
    input  wire [7:0]  buffer_write_data,
    input  wire        buffer_write_en,
    output wire [7:0]  buffer_read_data,
    
    // Configuration
    input  wire [7:0]  config,         // CPOL/CPHA/clock divider
    input  wire        cs,             // chip select
    
    // SPI pins
    output wire        mosi,
    input  wire        miso,
    output wire        sclk,
    output wire        cs_out,
    
    // Interrupt outputs
    output wire        transfer_done,
    output wire        block_done,
    output wire        error
);
    // Internal instantiations:
    // SPI_Engine, Transfer_Controller, Buffer_RAM, Interrupt_Controller
endmodule
