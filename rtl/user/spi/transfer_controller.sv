module Transfer_Controller (
    input  wire        clk,
    input  wire        reset,
    
    // Control signals
    input  wire        start,
    input  wire        stop,
    input  wire        block_mode,
    input  wire [15:0] block_len,
    
    // SPI engine interface
    output reg  [7:0]  tx_byte,
    input  wire [7:0]  rx_byte,
    output reg         start_byte,
    input  wire        byte_done,
    
    // Buffer interface
    input  wire [7:0]  buffer_read_data,
    output reg  [8:0]  buffer_addr,
    output reg  [7:0]  buffer_write_data,
    output reg         buffer_write_en,
    
    // Status
    output reg         busy,
    output reg         transfer_done,
    output reg         block_done,
    output reg         error
);
    // FSM states: IDLE, LOAD_BYTE, TRANSFER_BYTE, BYTE_DONE, CHECK_BLOCK, BLOCK_DONE, ERROR
endmodule
