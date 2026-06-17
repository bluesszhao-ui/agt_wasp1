`timescale 1ns/1ps

// icache integrates the direct-mapped instruction-cache leaves.
//
// Frontend fetch requests enter through front_if. Hits are served from the
// local tag/data arrays; misses are refilled through mem_if. The top-level
// wrapper owns no extra sequential state beyond the instantiated leaves.
module icache #(
  parameter int LINE_COUNT = 16,
  parameter int LINE_BYTES = 16,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic clk_i,        // I-cache clock shared by control, tag, data, and refill leaves.
  input  logic rst_ni,       // Active-low asynchronous reset for sequential leaves.
  input  logic flush_i,      // Abort active cache control/refill work.
  input  logic invalidate_i, // Clear all tag valid bits on the next clk_i edge.

  mem_req_rsp_if.target    front_if, // Frontend instruction fetch request/response port.
  mem_req_rsp_if.initiator mem_if    // Downstream instruction memory request/response port.
);
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int INDEX_BITS = $clog2(LINE_COUNT);

  logic                    lookup_valid;        // Control-qualified tag/data lookup.
  logic [ADDR_WIDTH-1:0]   lookup_addr;         // Address presented to tag/data leaves.
  logic                    tag_hit;             // Tag leaf hit result.
  logic [INDEX_BITS-1:0]   tag_lookup_index;    // Tag lookup index, exposed only for lint visibility.
  logic [INDEX_BITS-1:0]   data_lookup_index;   // Data lookup index, exposed only for lint visibility.
  logic [DATA_WIDTH-1:0]   data_word;           // Word selected from data leaf.
  logic [LINE_BITS-1:0]    data_lookup_line;    // Full selected line, reserved for later diagnostics.

  logic                    refill_start_valid;  // Control requests a line refill.
  logic                    refill_start_ready;  // Refill sequencer accepted/ready for start.
  logic [ADDR_WIDTH-1:0]   refill_start_addr;   // Miss address for refill line derivation.
  logic                    refill_flush;        // Flush forwarded from control to refill.
  logic                    refill_line_valid;   // Refill sequencer completed a line.
  logic                    refill_line_ready;   // Control accepts completed line.
  logic [ADDR_WIDTH-1:0]   refill_line_addr;    // Completed refill line base address.
  logic [LINE_BITS-1:0]    refill_line_data;    // Completed refill line payload.
  logic                    refill_line_error;   // Sticky downstream error from refill.

  logic                    tag_refill_valid;    // Tag update pulse for accepted refill line.
  logic [ADDR_WIDTH-1:0]   tag_refill_addr;     // Refill line address for tag update.
  logic                    tag_refill_error;    // Refill error keeps tag invalid.
  logic                    data_refill_valid;   // Data update pulse for accepted refill line.
  logic [ADDR_WIDTH-1:0]   data_refill_addr;    // Refill line address for data update.
  logic [LINE_BITS-1:0]    data_refill_line;    // Refill line payload for data update.

  icache_ctrl #(
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_ctrl (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(flush_i),
    .front_if(front_if),
    .lookup_valid_o(lookup_valid),
    .lookup_addr_o(lookup_addr),
    .tag_hit_i(tag_hit),
    .data_word_i(data_word),
    .refill_start_valid_o(refill_start_valid),
    .refill_start_ready_i(refill_start_ready),
    .refill_start_addr_o(refill_start_addr),
    .refill_flush_o(refill_flush),
    .refill_line_valid_i(refill_line_valid),
    .refill_line_ready_o(refill_line_ready),
    .refill_line_addr_i(refill_line_addr),
    .refill_line_data_i(refill_line_data),
    .refill_line_error_i(refill_line_error),
    .tag_refill_valid_o(tag_refill_valid),
    .tag_refill_addr_o(tag_refill_addr),
    .tag_refill_error_o(tag_refill_error),
    .data_refill_valid_o(data_refill_valid),
    .data_refill_addr_o(data_refill_addr),
    .data_refill_line_o(data_refill_line)
  );

  icache_tag #(
    .LINE_COUNT(LINE_COUNT),
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) u_tag (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .invalidate_i(invalidate_i),
    .lookup_valid_i(lookup_valid),
    .lookup_addr_i(lookup_addr),
    .lookup_hit_o(tag_hit),
    .lookup_index_o(tag_lookup_index),
    .refill_valid_i(tag_refill_valid),
    .refill_addr_i(tag_refill_addr),
    .refill_error_i(tag_refill_error)
  );

  icache_data #(
    .LINE_COUNT(LINE_COUNT),
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_data (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .lookup_addr_i(lookup_addr),
    .lookup_index_o(data_lookup_index),
    .lookup_word_o(data_word),
    .lookup_line_o(data_lookup_line),
    .refill_valid_i(data_refill_valid),
    .refill_addr_i(data_refill_addr),
    .refill_line_i(data_refill_line)
  );

  icache_refill #(
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_refill (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(refill_flush),
    .start_valid_i(refill_start_valid),
    .start_ready_o(refill_start_ready),
    .start_addr_i(refill_start_addr),
    .line_valid_o(refill_line_valid),
    .line_ready_i(refill_line_ready),
    .line_addr_o(refill_line_addr),
    .line_data_o(refill_line_data),
    .line_error_o(refill_line_error),
    .mem_if(mem_if)
  );
endmodule
