module Transfer_Controller #(
    parameter ADDR_BIT = 12
	)(
    input  logic        clk,
    input  logic        reset,
    
    // Control signals
    input  logic        start,
    input  logic        stop,
    input  logic        block_mode,
    input  logic [ADDR_BIT-2:0] block_len,

		input  logic [7:0]  cpu_tx_byte,
		output logic [7:0]  cpu_rx_byte,
    // SPI engine interface
    output logic [7:0]  tx_byte,
    input  logic [7:0]  rx_byte,
    output logic        start_byte,
    input  logic        byte_done,
    
    // Buffer interface
    input  logic [7:0]  buffer_read_data,
    output logic [ADDR_BIT-1:0]  buffer_addr,
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
	FETCH_BYTE,
	START_BYTE,
	WAIT_BYTE,
	BYTE_DONE,
	TRANSFER_DONE,
	ERROR
} state;

logic internal_block_mode;
logic [ADDR_BIT-2:0] block_counter = 0;
logic [ADDR_BIT-2:0] block_terminator = 0;
logic [7:0]  cpu_tx_passthrough;
assign last_cycle = (block_counter == block_terminator - 1'b1);// NOTE: This does work but is very hacky since 512 becomes 0 but that means 0 will transfer 512 

always_ff @(posedge clk or posedge reset) begin
	if (reset || stop) begin
		// reset all states 
		state               <= IDLE;
		internal_block_mode <= 0;
		transfer_done       <= 0;
		block_done          <= 0;
		block_terminator    <= 0;
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
						block_counter <= 0;
						if(block_mode) begin 
								block_terminator    <= block_len; 
								internal_block_mode <= 1; 
						end else begin 
								internal_block_mode <= 0; 
								block_terminator    <= 1; 
								cpu_tx_passthrough  <= cpu_tx_byte; 
						end
				end
			end
			LOAD_BYTE:
				begin
					buffer_addr <= block_counter;
					state <= FETCH_BYTE;
				end

      FETCH_BYTE:
        // Wait one clock cycle for byte to fetch
        begin
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
							buffer_addr       <= {1'b1, block_counter[ADDR_BIT-2:0]};
							buffer_write_data <= rx_byte;
							buffer_write_en   <= 1'b1;
						end
						else cpu_rx_byte <= rx_byte;
					end
				end

			BYTE_DONE:
				begin
					buffer_write_en <= 1'b0;
					if (last_cycle) 
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
