`timescale 1ns/1ps

// Shared RISC-V Debug Module Interface encodings used inside wasp1 debug RTL.
package debug_dmi_pkg;
  // The 7-bit address width covers every Debug Module register used by v0.13.x.
  localparam int DMI_ADDR_WIDTH = 7;

  // DMI request operations transported between the JTAG DTM and Debug Module.
  localparam logic [1:0] DMI_OP_NOP   = 2'b00;
  localparam logic [1:0] DMI_OP_READ  = 2'b01;
  localparam logic [1:0] DMI_OP_WRITE = 2'b10;

  // DMI response status encodings returned to the JTAG DTM.
  localparam logic [1:0] DMI_RESP_SUCCESS = 2'b00;
  localparam logic [1:0] DMI_RESP_FAILED  = 2'b10;
  localparam logic [1:0] DMI_RESP_BUSY    = 2'b11;

  // Stage-1 Debug Module register addresses from Debug Spec v0.13.x.
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_DATA0      = 7'h04;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_DMCONTROL  = 7'h10;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_DMSTATUS   = 7'h11;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_HARTINFO   = 7'h12;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_ABSTRACTCS = 7'h16;
  localparam logic [DMI_ADDR_WIDTH-1:0] DMI_ADDR_COMMAND    = 7'h17;

  // Abstract command error encodings held in abstractcs.cmderr.
  localparam logic [2:0] CMDERR_NONE         = 3'd0;
  localparam logic [2:0] CMDERR_BUSY         = 3'd1;
  localparam logic [2:0] CMDERR_NOTSUP       = 3'd2;
  localparam logic [2:0] CMDERR_EXCEPTION    = 3'd3;
  localparam logic [2:0] CMDERR_HALT_RESUME  = 3'd4;
  localparam logic [2:0] CMDERR_BUS          = 3'd5;
  localparam logic [2:0] CMDERR_OTHER        = 3'd7;
endpackage
