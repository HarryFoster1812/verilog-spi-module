// TODO: Change interface to use words not bytes
module Buffer_RAM (
    input  wire        clk,
    
    // CPU interface
    input  wire [8:0]  cpu_addr,
    input  wire [7:0]  cpu_write_data,
    input  wire        cpu_write_en,
    output reg  [7:0]  cpu_read_data,
    
    // SPI/Transfer_Controller interface
    input  wire [8:0]  tx_addr,
    input  wire [7:0]  tx_write_data,
    input  wire        tx_write_en,
    output reg  [7:0]  tx_read_data
);
    reg [7:0] buffer [0:511]; // 512-byte RAM
    
    // TODO: Add CPU/SPI arbitration
endmodule
