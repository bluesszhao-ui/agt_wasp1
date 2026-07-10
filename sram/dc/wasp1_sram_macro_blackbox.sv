`timescale 1ns/1ps

// IC synthesis blackbox for `wasp1_sram_macro`.
//
// Use this stub, not the behavioral RTL body, when an ASIC synthesis run must
// bind the wrapper to a foundry SRAM compiler macro. The final technology
// adapter may keep this exact logical port list or wrap the vendor-specific
// macro below this boundary.
(* blackbox *)
module wasp1_sram_macro #(
  parameter int DATA_WIDTH = 32,
  parameter int DEPTH = 1024,
  parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input  logic                        clk_i,    // Macro clock.
  input  logic                        write_i,  // Qualified write pulse.
  input  logic [ADDR_WIDTH-1:0]       addr_i,   // Word address.
  input  logic [(DATA_WIDTH/8)-1:0]   wstrb_i,  // Byte write enables.
  input  logic [DATA_WIDTH-1:0]       wdata_i,  // Write data.
  output logic [DATA_WIDTH-1:0]       rdata_o   // Read data.
);
endmodule
