/*
 * Copyright (c) 2024 s1pu11i
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_s1pu11i_simple_nco (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
 
  // All output pins must be assigned. If not used, assign to 0.
  assign uio_oe  = 0; // use bidirectional path as inputs only
  assign uio_out = 0; 



  simple_nco simple_nco(.clk(clk),
                        .rst_n(rst_n),
                        .enable(ena),
                        .dataIn(ui_in),
                        .ctrlIn(uio_in),
                        .dataOut(uo_out));


endmodule : tt_um_s1pu11i_simple_nco
