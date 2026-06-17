`timescale 1ns/1ps

`include "wasp1_target_defs.svh"

// icache_tag stores valid bits and tags for a direct-mapped instruction cache.
//
// The block has a combinational lookup path and a clocked refill/update path.
// It owns no data RAM and performs no refill sequencing; later icache_data and
// icache_ctrl modules use this leaf to decide hit/miss behavior.
module icache_tag #(
  parameter int LINE_COUNT = 16,
  parameter int LINE_BYTES = 16,
  parameter int ADDR_WIDTH = 32
) (
  input  logic                  clk_i,              // I-cache clock for tag/valid state.
  input  logic                  rst_ni,             // Active-low asynchronous reset.

  input  logic                  invalidate_i,       // Clear every valid bit on this clock edge.

  input  logic                  lookup_valid_i,     // Lookup request qualifier for hit output.
  input  logic [ADDR_WIDTH-1:0] lookup_addr_i,      // Address whose index/tag are compared.
  output logic                  lookup_hit_o,       // Lookup address hits a valid matching tag.
  output logic [$clog2(LINE_COUNT)-1:0] lookup_index_o, // Index decoded from lookup address.

  input  logic                  refill_valid_i,     // Write tag for the refill address.
  input  logic [ADDR_WIDTH-1:0] refill_addr_i,      // Address whose line tag becomes valid.
  input  logic                  refill_error_i      // Refill failed; do not mark the line valid.
);
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);
  localparam int INDEX_BITS = $clog2(LINE_COUNT);
  localparam int TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;

  typedef logic [INDEX_BITS-1:0] index_t;
  typedef logic [TAG_BITS-1:0]   tag_t;

`ifdef WASP1_TARGET_FPGA_XILINX_VIRTEX7
  (* ram_style = "distributed" *) tag_t tag_q [LINE_COUNT]; // FPGA LUTRAM-friendly tag storage.
`else
  tag_t tag_q [LINE_COUNT];         // Generic/IC tag storage inferred by synthesis.
`endif
  logic [LINE_COUNT-1:0] valid_q;   // Per-line valid bits.

  index_t lookup_index;             // Lookup index extracted from address.
  tag_t   lookup_tag;               // Lookup tag extracted from address.
  index_t refill_index;             // Refill index extracted from address.
  tag_t   refill_tag;               // Refill tag extracted from address.

  assign lookup_index = lookup_addr_i[OFFSET_BITS +: INDEX_BITS];
  assign lookup_tag = lookup_addr_i[ADDR_WIDTH-1 -: TAG_BITS];
  assign refill_index = refill_addr_i[OFFSET_BITS +: INDEX_BITS];
  assign refill_tag = refill_addr_i[ADDR_WIDTH-1 -: TAG_BITS];
  assign lookup_index_o = lookup_index;
  assign lookup_hit_o = lookup_valid_i && valid_q[lookup_index] &&
                        (tag_q[lookup_index] == lookup_tag);

  // Reset/invalidate clear all valid bits. Refill updates the indexed tag and,
  // when the refill completed without error, marks the line valid.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= '0;
    end else if (invalidate_i) begin
      valid_q <= '0;
    end else if (refill_valid_i) begin
      tag_q[refill_index] <= refill_tag;
      valid_q[refill_index] <= !refill_error_i;
    end
  end
endmodule
