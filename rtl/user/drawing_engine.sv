/** 
    Module:        drawing_engine
    
    Description:   Top level module for the drawing engine.
                   This module instantiates the drawing control and
                   drawing units, and provides a bus interface to the
                   video display unit controller (VDUC).
                   It also handles the bus requests and responses.

    Authors:       James Garside & Anthony Mathews
    Date:          July 2025

*/

`timescale 1ns / 1ps

module drawing_engine(input  wire        clk,
               input  wire        reset_i,
               input  wire        cs_i,
               input  wire        read_i,
               input  wire        write_i,
               input  wire [31:0] address_i,
               input  wire  [1:0] size_i,
               input  wire  [1:0] mode_i,
               output wire        stall_o,
               output wire  [2:0] abort_v_o,
               input  wire [31:0] data_in,
               output reg  [31:0] data_out,
               output wire  [1:0] ireq_o,
               
               input  wire  [9:0] v_width_i,
               input  wire  [9:0] v_height_i,
               input  wire  [1:0] v_mode_i,
               input  wire [17:0] v_base_i,

               output wire        de_req_o,  /* Bus fron drawing accelerator to FS mux. */
               output wire        de_RnW_o,
               output wire  [3:0] de_nbyte_o,
               input  wire        de_ack_i,
               output wire [17:0] de_address_o,
               output wire [31:0] de_wr_data_o,
               input  wire [31:0] de_rd_data_i);
 
always_comb begin : debug_signal
    data_out = 32'habcddcba;
end


endmodule

/*============================================================================*/
