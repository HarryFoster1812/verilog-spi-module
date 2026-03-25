module Buffer_RAM (
    input  logic        clk,
		input logic reset,
    
    // CPU interface
    input  logic [31:0] cpu_addr,
    input  logic [31:0] cpu_write_data,
    input  logic        cpu_write_en,   // Already gated by (cs_i && addr[9])
    output logic [31:0] cpu_read_data,
    input  logic [1:0]  cpu_read_mode,  // 00: Byte, 01: Half, 10: Word
    
    // SPI/Transfer_Controller interface
    input  logic [8:0]  tx_addr,
    input  logic [7:0]  tx_write_data,
    input  logic        tx_write_en,
    output logic [7:0]  tx_read_data
);

    // Internal 512-byte buffer
    logic [7:0] buffer [0:511];

    // Local index derived from the lower 9 bits
    logic [8:0] ram_index;
    assign ram_index = cpu_addr[8:0];

    //  Combinatorial Read Logic
    always_comb begin
        case (cpu_read_mode)
            2'b00: begin // Byte Access
                cpu_read_data = {24'h0, buffer[ram_index]};
            end
            
            2'b01: begin // Halfword Access: Align to 2-byte boundary
                // Mask bit 0 to force 16-bit alignment
                cpu_read_data = {16'h0, buffer[{ram_index[8:1], 1'b1}], 
                                        buffer[{ram_index[8:1], 1'b0}]};
            end
            
            2'b10: begin // Word Access: Align to 4-byte boundary
                // Mask bits [1:0] to force 32-bit alignment
                cpu_read_data = {buffer[{ram_index[8:2], 2'b11}], 
                                 buffer[{ram_index[8:2], 2'b10}], 
                                 buffer[{ram_index[8:2], 2'b01}], 
                                 buffer[{ram_index[8:2], 2'b00}]};
            end
            
            default: cpu_read_data = 32'h0;
        endcase
    end

    // SPI side read is simple byte access
    assign tx_read_data = buffer[tx_addr];

    // Synchronous Writes
    always_ff @(posedge clk or posedge reset) begin
			if (reset) begin
				// Wipe entire memory to 0 on Active-High Reset
				for (int i = 0; i < 512; i++) begin
					buffer[i] <= 8'h00;
				end
			end else begin if (cpu_write_en) begin
            // Aligning to 4-byte boundary for the word write
            buffer[{ram_index[8:2], 2'b00}] <= cpu_write_data[7:0];
            buffer[{ram_index[8:2], 2'b01}] <= cpu_write_data[15:8];
            buffer[{ram_index[8:2], 2'b10}] <= cpu_write_data[23:16];
            buffer[{ram_index[8:2], 2'b11}] <= cpu_write_data[31:24];
        end
        
        // Priority to SPI write if both occur simultaneously
        if (tx_write_en) begin
            buffer[tx_addr] <= tx_write_data;
        end
    end
	end

endmodule
