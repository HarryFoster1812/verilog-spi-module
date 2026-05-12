module Buffer_RAM #(
    parameter ADDR_BIT = 10,
    parameter DEPTH    = 1024,
    parameter BUFFER_START_ADDR = 'h200
)(
    input  logic        clk,
    input  logic        reset,
    
    // CPU interface
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_write_data,
    input  logic        cpu_write_en,   
    output logic [31:0] cpu_read_data,
    input  logic [1:0]  cpu_read_mode,  // 00: Byte, 01: Half, 10: Word
    input  logic        cpu_read_en,
    
    // SPI/Transfer_Controller interface
    input  logic [ADDR_BIT-1:0]  tx_addr,
    input  logic [7:0]  tx_write_data,
    input  logic        tx_write_en,
    output logic [7:0]  tx_read_data
);

    // Internal memory
    logic [7:0] buffer [0:DEPTH-1];

    // Local index calculation
    logic [ADDR_BIT-1:0] ram_index;
    assign ram_index = cpu_addr[ADDR_BIT-1:0] - BUFFER_START_ADDR[ADDR_BIT-1:0];

    // CPU Expects zero cycle read
    always_comb begin
      if (cpu_read_en) begin
        cpu_read_data = {buffer[{ram_index[ADDR_BIT-1:2], 2'b11}], 
                                buffer[{ram_index[ADDR_BIT-1:2], 2'b10}], 
                                buffer[{ram_index[ADDR_BIT-1:2], 2'b01}], 
                                buffer[{ram_index[ADDR_BIT-1:2], 2'b00}]};
        end else begin cpu_read_data = 32'h0; end
    end

    // Synchronous Logic
    always_ff @(posedge clk) begin
        if (reset) begin
            tx_read_data  <= 8'h0;
        end else begin
            // WRITE PORT 
            if (tx_write_en) begin
                buffer[tx_addr] <= tx_write_data;
            end else if (cpu_write_en) begin
                buffer[{ram_index[ADDR_BIT-1:2], 2'b00}] <= cpu_write_data[7:0];
                buffer[{ram_index[ADDR_BIT-1:2], 2'b01}] <= cpu_write_data[15:8];
                buffer[{ram_index[ADDR_BIT-1:2], 2'b10}] <= cpu_write_data[23:16];
                buffer[{ram_index[ADDR_BIT-1:2], 2'b11}] <= cpu_write_data[31:24];
            end

            // READ PORT
            tx_read_data <= buffer[tx_addr];

        end
    end

endmodule
