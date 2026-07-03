`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Stage-1 JTAG-facing Debug Module integration boundary.
//
// This wrapper connects the RISC-V JTAG DTM/TAP to the verified wasp1 Debug
// Module register/control wrapper. It adds no architectural Debug Module
// registers of its own; all DMI-visible state remains inside `debug`, while all
// JTAG scan-chain state remains inside `debug_jtag_dtm`.
module debug_jtag (
  input  logic       clk_i,              // Debug Module/system clock for DMI and core-debug channels.
  input  logic       rst_ni,             // Active-low reset for the debug system clock domain.
  input  logic       tck_i,              // JTAG test clock for TAP/scan state.
  input  logic       trst_ni,            // Active-low asynchronous JTAG TAP reset.
  input  logic       tms_i,              // JTAG test mode select.
  input  logic       tdi_i,              // JTAG serial data input.
  output logic       tdo_o,              // JTAG serial data output.
  debug_if.dm        core_debug,         // Halt/resume and GPR debug channel to the single core.
  input  logic       hart_reset_event_i, // One-cycle hart reset observation for dmstatus.havereset.
  output logic       dmactive_o,         // Debug Module active state.
  output logic       ndmreset_o,         // Non-debug reset request from dmcontrol.ndmreset.
  output logic       dtm_hardreset_o     // One-TCK pulse from DTMCS.dmihardreset.
);
  // Internal DMI transport between the JTAG DTM master and Debug Module target.
  debug_dmi_if dmi_link (
    .clk   (clk_i),
    .rst_n (rst_ni)
  );

  debug_jtag_dtm u_debug_jtag_dtm (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .tck_i           (tck_i),
    .trst_ni         (trst_ni),
    .tms_i           (tms_i),
    .tdi_i           (tdi_i),
    .tdo_o           (tdo_o),
    .dmi             (dmi_link),
    .dtm_hardreset_o (dtm_hardreset_o)
  );

  debug u_debug (
    .clk_i              (clk_i),
    .rst_ni             (rst_ni),
    .dmi                (dmi_link),
    .core_debug         (core_debug),
    .hart_reset_event_i (hart_reset_event_i),
    .dmactive_o         (dmactive_o),
    .ndmreset_o         (ndmreset_o)
  );
endmodule
