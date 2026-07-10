`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// wasp1_otp_macro
//
// This module is the executable OTP storage macro boundary. The behavioral RTL
// initializes to the erased OTP value, optionally preloads a simulation image,
// and models one-time 1->0 programming. IC synthesis should replace this module
// with an OTP/NVM macro wrapper that preserves the same logical read/program
// contract for the surrounding AHB register block.
module wasp1_otp_macro #(
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter int DEPTH = 1024,
  parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input  logic                  clk_i,            // OTP programming clock, same as the AHB wrapper clock.
  input  logic [ADDR_WIDTH-1:0] read_addr_i,      // Word address for executable/readback data reads.
  output logic [DATA_WIDTH-1:0] read_data_o,      // Current data at read_addr_i.
  input  logic [ADDR_WIDTH-1:0] prog_addr_i,      // Word address selected by OTP_ADDR.
  input  logic                  prog_i,           // One-clock accepted programming pulse.
  input  logic [DATA_WIDTH-1:0] prog_data_i,      // Program data; only 1->0 transitions are legal.
  output logic [DATA_WIDTH-1:0] prog_read_data_o  // Current word used by control logic for legality checks.
);
  localparam logic [DATA_WIDTH-1:0] ERASED_WORD = '1;

`ifdef WASP1_TARGET_FPGA_XILINX_VIRTEX7
  (* ram_style = "block" *) logic [DATA_WIDTH-1:0] otp_mem_q [DEPTH]; // FPGA OTP model storage.
`else
  logic [DATA_WIDTH-1:0] otp_mem_q [DEPTH]; // Generic simulation model or IC macro-replacement boundary.
`endif

`ifndef SYNTHESIS
  string otp_hex_path; // Simulation-only preload path passed by +WASP1_OTP_HEX.
`endif

  // Both reads are intentionally combinational at this boundary so the AHB OTP
  // wrapper keeps its existing one-cycle response and same-cycle program
  // legality check. A physical OTP wrapper must adapt its macro timing here.
  assign read_data_o = otp_mem_q[read_addr_i];
  assign prog_read_data_o = otp_mem_q[prog_addr_i];

  // Simulation starts from an erased OTP image and then overlays an optional
  // firmware hex file. Synthesis ignores this initialization hook.
  initial begin
    for (int idx = 0; idx < DEPTH; idx++) begin
      otp_mem_q[idx] = ERASED_WORD;
    end
`ifndef SYNTHESIS
    if ($value$plusargs("WASP1_OTP_HEX=%s", otp_hex_path)) begin
      $readmemh(otp_hex_path, otp_mem_q);
    end
`endif
  end

  // Accepted programming monotonically clears bits. The AHB wrapper checks key,
  // lock, address, and illegal 0->1 requests before asserting prog_i.
  always_ff @(posedge clk_i) begin
    if (prog_i) begin
      otp_mem_q[prog_addr_i] <= otp_mem_q[prog_addr_i] & prog_data_i;
    end
  end
endmodule
