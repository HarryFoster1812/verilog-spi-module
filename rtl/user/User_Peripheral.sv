
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/
/* This is a dummy I/O cell which acts as a template for user hardware.       */
/* It can accommodate 16 KiW (64 KiB) of I/O registers: currently two 32-bit  */
/* registers {yyy, zzz} are implemented, aliased throughout the address space.*/
/* The template is provided with 32 I/O lines which can be routed through to  */
/* the PCB I/O connectors on a bitwise basis in software.                     */
/* Four expansion interrupt signals are also provided.                        */
/* Currently uncommitted outputs are wired to constant values.                */
/*                                                          AMM/JDG Feb. 2025 */
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -*/

module User_Peripheral (input  wire        clk,           /* System clock     */
                        input  wire        reset,         /* System reset     */
                        input  wire        cs_i,          /* Device select    */
                        input  wire        read_i,        /* Bus read select  */
                        input  wire  [1:0] size_i,        /* Transfer size    */
                        input  wire        write_i,       /* Bus write select */
                        input  wire  [1:0] mode_i,        /* Privilege mode   */
                        input  wire [31:0] address_i,     /* Processor address*/
                        output wire        stall_o,       /* Bus wait output  */
                        output wire  [2:0] abort_o,       /* Bus error        */
                        input  wire [31:0] data_in,       /* Store data bus   */
                        output reg  [31:0] data_out,      /* Load data bus    */

                        input  wire [31:0] port_in,       /* Connections      */
                                                          /*   towards pin_fn */
                        output wire [31:0] port_out, 
                        output wire [31:0] port_direction,/* 1nput or 0utput  */
                        output wire  [7:0] LED_o,         /* Connections      */
                                                          /* towards PCB LEDs */
                                                           
                        output wire  [7:0] LCD_data_o,    /* Outputs to LCD   */
                        input  wire  [7:0] LCD_data_i,    /* Inputs from LCD  */
                        output wire        LCD_RW_o,      /* Read Not write   */
                        output wire        LCD_RS_o,      /* LCD Reg select   */
                        output wire        LCD_E_o,       /* LCD Enable       */
                        output wire        LCD_BL_o,      /* LCD Backlight,   */
                                                          /* Active high      */
                                                          
                        input  wire  [3:0] switch_i,      /* PCB switch states*/
                        output wire  [3:0] irq_o);        /*Interrupt requests*/
  
reg  [15:0] addr;  /* Note : if read needed the appropriate address bits must */
                   /* be kept for the output multiplexer in the -next- cycle. */

reg  [31:0] yyy, zzz;                                    /* Example registers */

assign stall_o =    cs_i   && 1'b0;       /* Unlikely to want to change these */
assign abort_o = {3{cs_i}} && 3'h0;     /* Aborts done at 'MMU' level already */

//assign LED_o   = 8'h00;                        /* Wire off the LED outputs    */
assign LED_o   = yyy[7:0];

always @ (posedge clk)                         /* Address bits hold           */
if (cs_i && read_i) addr <= address_i[7:0];    /* Delay for next cycle        */

always @ (posedge clk)                         /* Write register: not decoded */
if (reset)
  begin
  yyy <= 32'h0000_0000;                        /* Initialisation value(s)     */
  zzz <= 32'h0000_0000;
  end
else
  if (cs_i && write_i)                         /* Write to selected register  */
    case (address_i[3:2])                      /* Select (word) address here  */
      2'h0: yyy <= data_in;
      2'h1: zzz <= data_in;
    endcase

always @ (*)                                   /* Read from selected register */
  case (addr[3:2])                /* Select (word) address here (later cycle) */
//  2'h0: data_out = yyy;
    2'h0: data_out = {28'h1234000, switch_i};
    2'h1: data_out = zzz;
    default: data_out = 32'hxxxx_xxxx; /* Guard against accidentally latching */
  endcase

// port_in                             /* Up to 32 potential inputs (unwired) */
assign port_out       = 32'h0000_0000;        /* Potential outputs (tied off) */
assign port_direction = 32'hFFFF_FFFF;        /* Potential enables (tied off) */
assign irq_o          =  4'b0000;  /* Potential interrupt requests (tied off) */

// LCD Defaults
assign LCD_data_o = 1'b0; 
assign LCD_RW_o = 1'b1;        
assign LCD_RS_o = 1'b0;
assign LCD_E_o = 1'b0;
assign LCD_BL_o = 1'b1;

endmodule  // user_periph

/*============================================================================*/
