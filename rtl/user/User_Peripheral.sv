module User_Peripheral (
    // Processor Bus Interface
    input  wire        clk,
    input  wire        reset,
    input  wire        cs_i,
    input  wire        read_i,
    input  wire        write_i,
    input  wire [1:0]  size_i,
    input  wire [1:0]  mode_i,
    input  wire [31:0] address_i,
    output reg         stall_o,
    output reg  [2:0]  abort_o,
    input  wire [31:0] data_in,
    output reg  [31:0] data_out,

    // I/O Interface
    input  wire [31:0] port_in,
    output wire [31:0] port_out,
    output wire [31:0] port_direction,
    output wire [7:0]  LED_o,
    input  wire [3:0]  switch_i,
    
    // LCD Interface (Unused in this peripheral)
    output wire [7:0]  LCD_data_o,
    input  wire [7:0]  LCD_data_i,
    output wire        LCD_RW_o,
    output wire        LCD_RS_o,
    output wire        LCD_E_o,
    output wire        LCD_BL_o,
    
    // Interrupts
    output wire [3:0]  irq_o
);

    // Address Decoding
    // address_i[9:0]
    // 0x000 - 0x1FF: Memory Mapped Registers (address_i[9] == 0)
    // 0x200 - 0x3FF: 512-Byte Buffer RAM     (address_i[9] == 1)
    
    wire is_ram_access = cs_i && address_i[9];
    wire is_reg_access = cs_i && !address_i[9];
    
    // Register Address Offsets
    localparam ADDR_CONTROL    = 10'h000;
    localparam ADDR_STATUS     = 10'h004;
    localparam ADDR_CONFIG     = 10'h008;
    localparam ADDR_CS         = 10'h00C;
    localparam ADDR_TXDATA     = 10'h010;
    localparam ADDR_RXDATA     = 10'h014;
    localparam ADDR_BLOCK_LEN  = 10'h018;
    localparam ADDR_IRQ_ENABLE = 10'h01C;

    reg  [31:0] reg_config;
    reg  [31:0] reg_cs;
    reg  [31:0] reg_block_len;
    reg  [31:0] reg_irq_enable;
    
    // Handshake & Status Signals
    wire        tc_busy;
    wire        tc_transfer_done;
    wire        tc_block_done;
    wire        tc_error;
    wire [7:0]  tc_rx_byte;
    wire [3:0]  irq_status_flags;
    
    // Software Flags
    reg         rx_valid_flag;
    wire        tx_ready_flag = !tc_busy;

    // CPU Write Logic
    // START and STOP are pulses, not stored registers.
    wire start_pulse = (is_reg_access && write_i && (address_i[9:0] == ADDR_CONTROL)) ? data_in[0] : 1'b0;
    wire stop_pulse  = (is_reg_access && write_i && (address_i[9:0] == ADDR_CONTROL)) ? data_in[1] : 1'b0;
    wire block_mode  = (is_reg_access && write_i && (address_i[9:0] == ADDR_CONTROL)) ? data_in[2] : 1'b0;

    reg [7:0] tx_byte_reg;
    
    always @(posedge clk) begin
        if (reset) begin
            reg_config     <= 32'h0000_0200; // Default clk_div
            reg_cs         <= 32'h0000_0001; // CS released (high)
            reg_block_len  <= 32'h0000_0000;
            reg_irq_enable <= 32'h0000_0000;
            tx_byte_reg    <= 8'h00;
            rx_valid_flag  <= 1'b0;
        end else begin
            // Clear rx_valid_flag on CPU read of RXDATA
            if (is_reg_access && read_i && (address_i[9:0] == ADDR_RXDATA)) begin
                rx_valid_flag <= 1'b0;
            end
            
            // Set rx_valid_flag when Transfer Controller finishes a byte
            if (tc_transfer_done) begin
                rx_valid_flag <= 1'b1;
            end

            // CPU Writes to Registers
            if (is_reg_access && write_i) begin
                case (address_i[9:0])
                    ADDR_CONFIG:     reg_config     <= data_in;
                    ADDR_CS:         reg_cs         <= data_in;
                    ADDR_TXDATA:     tx_byte_reg    <= data_in[7:0];
                    ADDR_BLOCK_LEN:  reg_block_len  <= data_in;
                    ADDR_IRQ_ENABLE: reg_irq_enable <= data_in;
                    // Note: CONTROL is handled by pulses above
                endcase
            end
        end
    end

    // =========================================================================
    // CPU Read Logic
    // =========================================================================
    wire [7:0] ram_read_data; // From Buffer_RAM CPU port

    always @(*) begin
        data_out = 32'h0000_0000;
        if (is_ram_access && read_i) begin
            data_out = {24'h000000, ram_read_data};
        end 
        else if (is_reg_access && read_i) begin
            case (address_i[9:0])
                ADDR_STATUS:     data_out = {27'b0, tc_error, tc_block_done, rx_valid_flag, tx_ready_flag, tc_busy};
                ADDR_CONFIG:     data_out = reg_config;
                ADDR_CS:         data_out = reg_cs;
                ADDR_TXDATA:     data_out = {24'b0, tx_byte_reg};
                ADDR_RXDATA:     data_out = {24'b0, tc_rx_byte};
                ADDR_BLOCK_LEN:  data_out = reg_block_len;
                ADDR_IRQ_ENABLE: data_out = reg_irq_enable;
                default:         data_out = 32'h0000_0000;
            endcase
        end
    end

    // =========================================================================
    // I/O Pin Mapping
    // =========================================================================
    // port_out[0]=sclk, port_out[1]=MOSI, port_in[2]=MISO, port_out[3]=CS
    wire mosi_wire, sclk_wire, cs_wire, miso_wire;
    
    assign port_out[0] = sclk_wire;
    assign port_out[1] = mosi_wire;
    assign port_out[3] = cs_wire;
    assign port_out[31:3] = 29'b0;

		assign miso_wire = port_in[2];

    // 0 = Output, 1 = Input. 
		// MISO(0) is Input, 
		// MOSI(0), SCLK(1), CS(2) are Outputs.
    assign port_direction = 32'h0000_0004; // 0b0100

    assign stall_o = 1'b0;
    assign abort_o = 3'b000;
    assign LED_o   = 8'h00;
    assign LCD_E_o = 1'b0;
    assign LCD_RW_o= 1'b0;
    assign LCD_RS_o= 1'b0;
    assign LCD_BL_o= 1'b0;
    assign LCD_data_o = 8'h00;

    // Module Instantiations

    // Buffer RAM (512 Bytes)
    wire [8:0] tc_buffer_addr;
    wire [7:0] tc_buffer_wdata;
    wire       tc_buffer_we;
    wire [7:0] tc_buffer_rdata;

    Buffer_RAM buffer_inst (
        .clk             (clk),
        
        // CPU Interface
        .cpu_addr        (address_i[8:0]),
        .cpu_write_data  (data_in[7:0]),
        .cpu_write_en    (is_ram_access & write_i),
        .cpu_read_data   (ram_read_data),
        
        // Transfer Controller Interface
        .tx_addr         (tc_buffer_addr),
        .tx_write_data   (tc_buffer_wdata),
        .tx_write_en     (tc_buffer_we),
        .tx_read_data    (tc_buffer_rdata)
    );

    // --- Transfer Controller ---
    wire       engine_start_byte;
    wire [7:0] engine_tx_byte;
    wire       engine_byte_done;
    wire [7:0] engine_rx_byte;

    Transfer_Controller tc_inst (
        .clk             (clk),
        .reset           (reset),
        
        // Control Signals
        .start           (start_pulse),
        .stop            (stop_pulse),
        .block_mode      (block_mode),
        .block_len       (reg_block_len[15:0]),
        
        // SPI Engine Interface
        .tx_byte         (engine_tx_byte),    // Output to Engine
        .rx_byte         (engine_rx_byte),    // Input from Engine
        .start_byte      (engine_start_byte), // Output to Engine
        .byte_done       (engine_byte_done),  // Input from Engine
        
        // Buffer Interface
        .buffer_read_data(tc_buffer_rdata),
        .buffer_addr     (tc_buffer_addr),
        .buffer_write_data(tc_buffer_wdata),
        .buffer_write_en (tc_buffer_we),
        
        // Status Flags
        .busy            (tc_busy),
        .transfer_done   (tc_transfer_done),
        .block_done      (tc_block_done),
        .error           (tc_error)
    );

    SPI_Engine engine_inst (
        .clk             (clk),
        .reset           (reset),
        
        // Byte Interface
        .tx_byte         (block_mode ? engine_tx_byte : tx_byte_reg),
        .start_byte      (engine_start_byte),
        .rx_byte         (engine_rx_byte),
        .byte_done       (engine_byte_done),
        
        // Configuration
        .cpol            (reg_config[0]),
        .cpha            (reg_config[1]),
        .clk_divider     (reg_config[15:8]),
        .cs              (reg_cs[0]),
        
        // Physical SPI Pins
        .mosi            (mosi_wire),
        .miso            (miso_wire),
        .sclk            (sclk_wire),
        .cs_out          (cs_wire)
    );

    Interrupt_Controller int_ctrl_inst (
        .clk             (clk),
        .reset           (reset),
        
        // Events
        .byte_done_event (tc_transfer_done),
        .block_done_event(tc_block_done),
        .error_event     (tc_error),
        
        // Config & Control
        .irq_enable      (reg_irq_enable[3:0]),
        .irq_clear       (is_reg_access && write_i && (address_i[9:0] == ADDR_STATUS)), // Write anything to STATUS to clear IRQs
        
        // Outputs
        .irq_o           (irq_o),           // Maps to irq_o[3:0]
        .irq_status      (irq_status_flags) // Could be mapped to a register if CPU needs to read IRQ status
    );

endmodule
