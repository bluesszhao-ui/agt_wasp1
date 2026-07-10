`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// wasp1_sram_macro
//
// This module is the single-port SRAM macro boundary used by AHB SRAM wrappers.
// The checked-in RTL body is a cycle-accurate behavioral model for simulation,
// lint, and FPGA BRAM inference. For IC synthesis, this module is the intended
// replacement point for a foundry SRAM compiler macro with the same logical
// contract: one read/write port, word address, byte write enables, and
// read-during-write behavior that does not change the AHB-visible protocol.
module wasp1_sram_macro #(
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter int DEPTH = 1024,
  parameter int ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH)
) (
  input  logic                        clk_i,    // Memory clock; same domain as the AHB wrapper.
  input  logic                        write_i,  // High for one clock to update selected byte lanes.
  input  logic [ADDR_WIDTH-1:0]       addr_i,   // Word address used for both read and write.
  input  logic [(DATA_WIDTH/8)-1:0]   wstrb_i,  // One byte write enable per data byte.
  input  logic [DATA_WIDTH-1:0]       wdata_i,  // Write data aligned to the selected word.
  output logic [DATA_WIDTH-1:0]       rdata_o   // Current selected word for the wrapper data phase.
);
  localparam int BYTE_WIDTH = 8;
  localparam int STRB_WIDTH = DATA_WIDTH / BYTE_WIDTH;

`ifdef WASP1_TARGET_FPGA_XILINX_VIRTEX7
  (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem_q [DEPTH]; // Virtex-7 BRAM inference target.
`else
  logic [DATA_WIDTH-1:0] mem_q [DEPTH]; // Generic simulation model or IC macro-replacement boundary.
`endif

  // The wrapper presents an asynchronous read model so the existing one-cycle
  // AHB slave response is preserved. An IC SRAM with registered read data must
  // be wrapped to keep this logical contract at the `wasp1_sram_macro` boundary.
  assign rdata_o = mem_q[addr_i];

  // Byte-lane writes model the write mask expected from the AHB wrapper. The
  // AHB wrapper qualifies `write_i`, so invalid or error transfers never update
  // the macro model.
  always_ff @(posedge clk_i) begin
    if (write_i) begin
      for (int byte_idx = 0; byte_idx < STRB_WIDTH; byte_idx++) begin
        if (wstrb_i[byte_idx]) begin
          mem_q[addr_i][(byte_idx * BYTE_WIDTH) +: BYTE_WIDTH] <=
            wdata_i[(byte_idx * BYTE_WIDTH) +: BYTE_WIDTH];
        end
      end
    end
  end
endmodule
