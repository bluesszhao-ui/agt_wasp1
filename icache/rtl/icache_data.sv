`timescale 1ns/1ps

`include "wasp1_target_defs.svh"

// icache_data stores direct-mapped instruction cache line data.
//
// The refill side writes one complete cache line at a time. The lookup side
// decodes the line index and word offset from the lookup address and returns a
// combinational 32-bit instruction word from the currently stored line.
module icache_data #(
  parameter int LINE_COUNT = 16,
  parameter int LINE_BYTES = 16,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                         clk_i,          // I-cache clock for line storage writes.
  input  logic                         rst_ni,         // Active-low reset; data contents are not reset.

  input  logic [ADDR_WIDTH-1:0]        lookup_addr_i,  // Address whose index and word offset are decoded.
  output logic [$clog2(LINE_COUNT)-1:0] lookup_index_o,// Index decoded from lookup address.
  output logic [DATA_WIDTH-1:0]        lookup_word_o,  // Selected instruction word from the cached line.
  output logic [LINE_BYTES*8-1:0]      lookup_line_o,  // Complete cached line at lookup index.

  input  logic                         refill_valid_i, // Refill writes a complete line on this clock edge.
  input  logic [ADDR_WIDTH-1:0]        refill_addr_i,  // Address whose index selects the refill destination.
  input  logic [LINE_BYTES*8-1:0]      refill_line_i   // Full cache line written by refill.
);
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);
  localparam int INDEX_BITS = $clog2(LINE_COUNT);
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int WORD_INDEX_BITS = (WORDS_PER_LINE <= 1) ? 1 : $clog2(WORDS_PER_LINE);
  localparam int BYTE_OFFSET_BITS = $clog2(DATA_BYTES);

  typedef logic [INDEX_BITS-1:0]      index_t;
  typedef logic [WORD_INDEX_BITS-1:0] word_index_t;
  typedef logic [LINE_BITS-1:0]       line_t;

`ifdef WASP1_TARGET_FPGA_XILINX_VIRTEX7
  (* ram_style = "distributed" *) line_t data_q [LINE_COUNT]; // Async-read LUTRAM-friendly line storage.
`else
  line_t data_q [LINE_COUNT];          // Generic/IC line storage inferred by synthesis.
`endif

  index_t      lookup_index;           // Lookup line index extracted from address.
  index_t      refill_index;           // Refill line index extracted from address.
  word_index_t lookup_word_index;      // Word offset inside the selected cache line.
  line_t       lookup_line;            // Current line data selected by lookup index.

  assign lookup_index = lookup_addr_i[OFFSET_BITS +: INDEX_BITS];
  assign refill_index = refill_addr_i[OFFSET_BITS +: INDEX_BITS];
  assign lookup_word_index = lookup_addr_i[BYTE_OFFSET_BITS +: WORD_INDEX_BITS];
  assign lookup_line = data_q[lookup_index];
  assign lookup_index_o = lookup_index;
  assign lookup_line_o = lookup_line;

  // Word select is purely combinational so an I-cache hit can return the
  // instruction word without adding a data-array state transition.
  always_comb begin
    lookup_word_o = '0;
    for (int word = 0; word < WORDS_PER_LINE; word++) begin
      if (lookup_word_index == word_index_t'(word)) begin
        lookup_word_o = lookup_line[word * DATA_WIDTH +: DATA_WIDTH];
      end
    end
  end

  // Refill owns the only write path. Reset intentionally does not clear data
  // RAM contents because tag valid bits determine whether line data is usable.
  always_ff @(posedge clk_i) begin
    if (refill_valid_i) begin
      data_q[refill_index] <= refill_line_i;
    end
  end
endmodule
