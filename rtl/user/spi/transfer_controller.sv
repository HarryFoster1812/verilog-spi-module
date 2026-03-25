module Transfer_Controller (
    input  logic        clk,
    input  logic        reset,
    
    // Control signals
    input  logic        start,
    input  logic        stop,
    input  logic        block_mode,
    input  logic [8:0] block_len,

		input  logic [7:0]  cpu_tx_byte,
		output logic [7:0]  cpu_rx_byte    
    // SPI engine interface
    output logic [7:0]  tx_byte,
    input  logic [7:0]  rx_byte,
    output logic        start_byte,
    input  logic        byte_done,
    
    // Buffer interface
    input  logic [7:0]  buffer_read_data,
    output logic [8:0]  buffer_addr,
    output logic [7:0]  buffer_write_data,
    output logic        buffer_write_en,
    
    // Status
    output logic         busy,
    output logic         transfer_done,
    output logic         block_done,
    output logic         error
);

enum {
	IDLE,
	LOAD_BYTE,
	START_BYTE,
	WAIT_BYTE,
	BYTE_DONE,
	TRANSFER_DONE,
	ERROR,
} state;

logic internal_block_mode;
logic [8:0] block_counter;
logic [8:0] block_terminator;
logic [7:0]  cpu_tx_passthrough;

always_ff @(posedge clk or posedge reset) begin
	if (reset or stop) begin
		// reset all states 
		state               <= IDLE;
		internal_block_mode <= 0;
		transfer_done       <= 0;
		block_done          <= 0;
		error               <= 0;
		buffer_write_en     <= 0;
		buffer_addr         <= 0;
		busy                <= 0;
		start_byte          <= 0;
		cpu_rx_byte         <= 8'h00;
	end else

		case(state)
			IDLE:
				begin
					transfer_done <= 0;
					block_done <= 0;
					error <= 0;
					buffer_write_en <= 0;
					buffer_addr <= 0;
					busy <= 0;
					start_byte <= 0;

					if(start) begin 
						state <= LOAD_BYTE; 
						busy  <= 1;
						block_counter <= 16'h0;
						if(block_mode) begin 
								block_terminator    <= block_len; 
								internal_block_mode <= 1; 
						end else begin 
								internal_block_mode <= 0; 
								block_terminator    <= 16'h1; 
								cpu_tx_passthrough  <= cpu_tx_byte; 
						end
				end
			end
			LOAD_BYTE:
				begin
					buffer_addr <= block_counter;
					state <= START_BYTE;
				end

			START_BYTE:
				begin
					tx_byte <= internal_block_mode ? buffer_read_data : cpu_tx_passthrough;
					start_byte <= 1'b1; // send start signal to engine
					state <= WAIT_BYTE;
				end


			WAIT_BYTE:
				begin
					start_byte <= 1'b0;
					if (byte_done) begin
						state             <= BYTE_DONE;
						if (internal_block_mode) begin
							buffer_addr       <= block_counter;
							buffer_write_data <= rx_byte;
							buffer_write_en   <= 1'b1;
						end
						else cpu_rx_byte <= rx_byte;
					end
				end

			BYTE_DONE:
				begin
					buffer_write_en <= 1'b0;
					if (block_counter == (block_terminator - 1))
						state <= TRANSFER_DONE;
					else begin
						block_counter <= block_counter + 1;
						state         <= LOAD_BYTE;
					end
				end

			TRANSFER_DONE:
				begin
					busy <= 1'b0;
					if(internal_block_mode) block_done <= 1'b1;
					else transfer_done <= 1'b1;
					state <= IDLE;
				end


			ERROR:
				begin
					state <= IDLE;
					error <= 1'b1;
				end
			default: state <= ERROR;
		endcase
end

endmodule
