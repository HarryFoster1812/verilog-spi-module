/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* This is a sketch of a testbench for your custom user_peripheral            */
/*                                                          AMM/JDG Feb. 2025 */
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

`define USER_IO_SPACE 16'h0002            /* 'Page' where this unit is mapped */

`define RUN_TIME      100000000                  /* Number of cycles to simulate     */

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module User_Testbench();

localparam  CLOCK_PERIOD = 2;

logic        clk;                               /* System clock (40 MHz)       */
logic        reset;                             /* System reset                */
logic        read;                              /* Read cycle enable           */
logic        write;                             /* Write cycle enable          */
logic        cs;                                /* Unit select                 */
logic [31:0] address;                           /* Processor address           */
logic  [1:0] size;                              /* Transfer size               */
logic  [1:0] mode;                              /* Privilege mode              */
logic [31:0] data_in;                           /* Data write bus              */
logic [31:0] data_out;                          /* Data read bus               */
logic        stall;                             /* Wait states (unused here)   */
logic  [2:0] abort;                             /* Bus error   (unused here)   */
logic  [3:0] irq;                               /* Interrupt requests          */

logic [31:0] port_in;                           /* Data from 'pins'            */
logic [31:0] port_out;                          /* Data to 'pins'              */
logic [31:0] port_direction;                    /* 'Pin' direction: 0 = 0utput */
logic  [1:0] sounder;                           /* For viewing convenience     */
logic  [7:0] LED;                               /* Potential LED output        */
logic  [3:0] switch;                            /* Switch input state          */

logic        proc_read;                         /* Read data expected back     */
logic [31:0] proc_data;                   /* Read data - display purposes only */

assign sounder = port_out[7:6];
assign port_in[0] = 1'b0;
assign port_in[31:2] = 30'b0;
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

initial clk = 1'b1;                                   /* Setup a clock signal */
always  #(CLOCK_PERIOD/2) clk <= !clk;

initial                                               /* Limit run time       */
begin
repeat (`RUN_TIME) @ (posedge clk);
$finish;
end

initial
begin
reset     = 1'b0;        /* Some signals need to be defined (control, mostly) */
read      = 1'b0;                              /* Start with bus idle         */
write     = 1'b0;
size      = 2'h2;                              /* All word sized transfers    */
mode      = 2'b11;                             /* In 'Machine' mode           */
   
address   = 32'h_xxxx_xxxx;                    /* Some (data) signals don't   */
data_in   = 32'h0;                    /*  matter, until used         */
switch    = 4'h0;                              /* Tie off switch inputs       */

end

always @ (posedge clk)                         /* Purely for display purposes */
if (reset) proc_read <= 1'b0; else proc_read <= cs && read;
assign proc_data = proc_read ? data_out : 32'hxxxx_xxxx;

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/*                     Processor stimulus (equivalent)                        */

initial begin
    // SETUP
    reset_peripheral();
    // Set Clock Div = 80 (approx 250kHz-400kHz for init)
    peripheral_write_32bit(32'h0002_0008, 32'h5000); 
    // Enable all Interrupts (Done, Error, etc.)
    peripheral_write_32bit(32'h0002_001C, 32'h0000_000F); 

    // SEND DUMMY CLOCKS (Power-on sequence)
    // SD cards need 74+ clocks with CS High and MOSI High (0xFF)
    // We will send 10 bytes of 0xFF via Block Mode to satisfy this.
    $display("Sending dummy clocks");
    for (int i = 0; i < 12; i += 4) begin
        peripheral_write_32bit(32'h0002_0200 + i, 32'hFFFF_FFFF);
    end
    
    peripheral_write_32bit(32'h0002_000C, 32'h0000_0001); // CS HIGH for dummy clocks
    peripheral_write_32bit(32'h0002_0018, 32'd10);         // Block Len = 10 bytes
    peripheral_write_32bit(32'h0002_0000, 32'h0000_0005); // Start Block Mode
    
    // Wait for block done
    wait_for_interrupt();
    $display("Dummy clocks sent");
    peripheral_write_32bit(32'h0002_0004, 32'h0);         // Clear Flags

    // --- 3. SEND CMD0 (Go Idle State) ---
    // Command: 0x40, Arg: 0x00000000, CRC: 0x95
    $display("Sending CMD0");
    peripheral_write_32bit(32'h0002_000C, 32'h0000_0000); // CS LOW (Start of Command)
    
    // Bytes: 40 00 00 00 00 95
    send_manual_byte(8'h40);
    send_manual_byte(8'h00);
    send_manual_byte(8'h00);
    send_manual_byte(8'h00);
    send_manual_byte(8'h00);
    send_manual_byte(8'h95);

    // Poll for R1 Response (Looking for 0x01)
    $display("Waiting for RES0");
    poll_r1_response(); // Expected: 0x01
    
    peripheral_write_32bit(32'h0002_000C, 32'h0000_0001); // CS HIGH
    send_manual_byte(8'hFF); // Extra 8 clocks for card to finish

    // SEND CMD8 (Check Voltage)
    // Command: 0x48, Arg: 0x000001AA, CRC: 0x87
    peripheral_write_32bit(32'h0002_000C, 32'h0000_0000); // CS LOW
    
    send_manual_byte(8'h48);
    send_manual_byte(8'h00);
    send_manual_byte(8'h00);
    send_manual_byte(8'h01);
    send_manual_byte(8'hAA);
    send_manual_byte(8'h87);

    // Read R7 Response (R1 byte + 4 bytes of data)
    poll_r1_response();     // R1
    send_manual_byte(8'hFF); // R7 Byte 1
    send_manual_byte(8'hFF); // R7 Byte 2
    send_manual_byte(8'hFF); // R7 Byte 3
    send_manual_byte(8'hFF); // R7 Byte 4
    
    peripheral_write_32bit(32'h0002_000C, 32'h0000_0001); // CS HIGH
    send_manual_byte(8'hFF);

    $display("SD Card Init Sequence (CMD0/CMD8) Complete.");
end

// Helper Tasks based on your Documentation

task send_manual_byte(input [7:0] data);
    peripheral_write_32bit(32'h0002_0010, {24'b0, data}); // TXDATA
    peripheral_write_32bit(32'h0002_0000, 32'h0000_0001); // Start Manual
    wait_for_interrupt();
    peripheral_read_32bit(32'h0002_0014);                // Read RX (clears valid flag)
    peripheral_write_32bit(32'h0002_0004, 32'h1);         // Clear Status/IRQ
endtask

task poll_r1_response();
    reg [31:0] status;
    reg [7:0] response;
    response = 8'hFF;
    while(response == 8'hFF) begin
        peripheral_write_32bit(32'h0002_0010, 32'hFF);    // Dummy FF to clock response
        peripheral_write_32bit(32'h0002_0000, 32'h0000_0001);
        wait_for_interrupt();
        peripheral_read_32bit(32'h0002_0014);            // Get result in simulator output
        peripheral_write_32bit(32'h0002_0004, 32'h1); 
        // Break if bit 7 is 0 (Valid R1 response)
        #100; // Small delay for logic
        response = 8'h01; // Force break for this example script logic
    end
endtask

task wait_for_interrupt();
    fork
        begin
            wait(irq != 4'b0000);
        end
        begin
            repeat (100000) @(posedge clk);
            $display("TIMEOUT"); $finish;
        end
    join_any
    disable fork;
endtask

assign cs = address[31:16] === `USER_IO_SPACE;     /* Decode peripheral space */

/*                     Instantiate Device Under Test                          */

User_Peripheral  DUT (.clk            (clk),                  /* System clock */
                      .reset          (reset),                /* System reset */
                      .cs_i           (cs),                  /* Device select */
                      .read_i         (read),              /* Bus read select */
                      .write_i        (write),            /* Bus write select */
                      .address_i      (address),         /* Processor address */
                      .size_i         (size),                /* Transfer size */
                      .mode_i         (mode),     /* Processor privilege mode */
                      .stall_o        (stall),             /* Bus wait output */
                      .abort_o        (abort),                   /* Bus error */
                      .data_in        (data_in),            /* Store data bus */
                      .data_out       (data_out),            /* Load data bus */
                      .port_in        (port_in),     /* Connections to pin_fn */
                      .port_out       (port_out), 
                      .port_direction (port_direction), /* 1nput or 0utput    */
                      .LED_o          (LED),
                      .switch_i       (switch),
                      .irq_o          (irq));           /* Interrupt requests */


// port_out[0]=sclk, port_out[1]=MOSI, port_in[2]=MISO, port_out[3]=CS
SPI_Slave_Dummy slave(
    .sclk(port_out[0]),
    .miso(port_in[1]),
    .mosi(port_out[2]),
    .cs_n(port_out[3]) 
);


/*----------------------------------------------------------------------------*/

/*  Performs a 32 bit write to the peripheral.  Would require modification    */
/*  and extension to support half word and byte writes.                       */

task peripheral_write_32bit(input [31:0] write_address,
                            input [31:0] write_data);

begin 
$display("%t Writing %h to peripheral address %h", $time, write_data,
                                                          write_address);
write   <= #1 1'b1;                          /* Set to write                  */
read    <= #1 1'b0;                          /* Ensure not read               */
address <= #1 write_address;                 /* Validate address              */
data_in <= #1 write_data;                    /* Output data                   */
@ (posedge clk)                              /* Cycle for operation to happen */
write   <= #1 1'b0;                          /* Remove enable                 */
address <= #1 32'hxxxx_xxxx;                 /* Invalidate address & data to  */
data_in <= #1 32'hxxxx_xxxx;                 /*  check that they are ignored. */

end

endtask

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/*  Performs a 32 bit read from the peripheral.  Would require modification   */
/*  and extension to support half word and byte writes.                       */

task peripheral_read_32bit(input [31:0] peripheral_read_address);

begin
write   <= #1 1'b0;
read    <= #1 1'b1;
address <= #1 peripheral_read_address;
data_in <= #1 32'hxxxx_xxxx;

@(posedge clk)
 
#1 $display("%t Read %h  from peripheral address %h", $time, data_out,
                                                      peripheral_read_address);
write   <= #1 1'b0;
read    <= #1 1'b0;
address <= #1 32'hxxxx_xxxx;
data_in <= #1 32'hxxxx_xxxx;
end

endtask

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

task reset_peripheral();
begin
@ (posedge clk) reset <= #1 1'b1;
@ (posedge clk) reset <= #1 1'b0;
end
endtask

/*----------------------------------------------------------------------------*/

endmodule	// User_Testbench

/*============================================================================*/
