`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Four-word RISC-V Debug Module Program Buffer storage.
//
// This leaf owns only debugger-visible instruction words. Abstract-command
// execution is intentionally outside this storage milestone, so the array has
// one DMI-side write port, one combinational read port, and a future executor
// view of all words.
module debug_progbuf #(
  parameter int unsigned WORD_COUNT = debug_dmi_pkg::PROGBUF_WORD_COUNT
) (
  input  logic                          clk_i,       // Debug Module clock for stored words.
  input  logic                          rst_ni,      // Asynchronous active-low storage reset.
  input  logic                          clear_i,     // Synchronous clear; dominates a same-cycle write.
  input  logic                          write_valid_i,// One-cycle accepted DMI Program Buffer write.
  input  logic [$clog2(WORD_COUNT)-1:0] write_index_i,// Word index selected by DMI address.
  input  logic [31:0]                   write_data_i,// RV32 instruction word written by debugger.
  input  logic [$clog2(WORD_COUNT)-1:0] read_index_i,// Combinational DMI read word index.
  output logic [31:0]                   read_data_o, // Current selected Program Buffer word.
  output logic [WORD_COUNT-1:0][31:0]   words_o     // Full future abstract-executor instruction view.
);
  // Program Buffer words are ordinary flops in this minimal four-word design.
  logic [WORD_COUNT-1:0][31:0] words_q;

  assign read_data_o = words_q[read_index_i];
  assign words_o = words_q;

  // Reset and an integration-requested clear remove all debugger payloads. A
  // clear on the same edge as a write wins so stale instructions cannot survive.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      words_q <= '0;
    end else if (clear_i) begin
      words_q <= '0;
    end else if (write_valid_i) begin
      words_q[write_index_i] <= write_data_i;
    end
  end
endmodule
