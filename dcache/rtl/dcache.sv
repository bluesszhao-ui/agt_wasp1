`timescale 1ns/1ps

// dcache integrates the direct-mapped data-cache leaves.
//
// Core load/store requests enter through core_if. Load hits are served from the
// local tag/data arrays, load misses are refilled through mem_if, and stores are
// written through to mem_if. The wrapper owns no extra sequential state beyond
// the instantiated leaves.
module dcache #(
  parameter int LINE_COUNT = 16,
  parameter int LINE_BYTES = 16,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter logic [ADDR_WIDTH-1:0] CACHEABLE0_BASE = 32'h0000_0000,
  parameter logic [ADDR_WIDTH-1:0] CACHEABLE0_SIZE = 32'h0000_FF00,
  parameter logic [ADDR_WIDTH-1:0] CACHEABLE1_BASE = 32'h1000_0000,
  parameter logic [ADDR_WIDTH-1:0] CACHEABLE1_SIZE = 32'h0001_0000,
  parameter logic [ADDR_WIDTH-1:0] CACHEABLE2_BASE = 32'h2000_0000,
  parameter logic [ADDR_WIDTH-1:0] CACHEABLE2_SIZE = 32'h0001_0000
) (
  input  logic clk_i,        // D-cache clock shared by control, tag, data, refill, and store leaves.
  input  logic rst_ni,       // Active-low asynchronous reset for sequential leaves.
  input  logic flush_i,      // Abort active cache control/refill/store work.
  input  logic invalidate_i, // Clear all tag valid bits on the next clk_i edge.

  mem_req_rsp_if.target    core_if, // Core data load/store request/response port.
  mem_req_rsp_if.initiator mem_if   // Downstream data memory request/response port.
);
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int INDEX_BITS = $clog2(LINE_COUNT);
  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  logic                    lookup_valid;        // Control-qualified tag/data lookup.
  logic [ADDR_WIDTH-1:0]   lookup_addr;         // Address presented to tag/data leaves.
  logic                    tag_hit;             // Tag leaf hit result.
  logic                    req_cacheable;       // Current core request targets cacheable memory.
  logic [INDEX_BITS-1:0]   tag_lookup_index;    // Tag lookup index, exposed only for lint visibility.
  logic [INDEX_BITS-1:0]   data_lookup_index;   // Data lookup index, exposed only for lint visibility.
  logic [DATA_WIDTH-1:0]   data_word;           // Word selected from data leaf.
  logic [LINE_BITS-1:0]    data_lookup_line;    // Full selected line, reserved for later diagnostics.

  logic                    refill_start_valid;  // Control requests a load-miss line refill.
  logic                    refill_start_ready;  // Refill sequencer can accept a start.
  logic [ADDR_WIDTH-1:0]   refill_start_addr;   // Miss address for refill line derivation.
  logic                    refill_flush;        // Flush forwarded from control to refill.
  logic                    refill_line_valid;   // Refill sequencer completed a line.
  logic                    refill_line_ready;   // Control accepts completed line.
  logic [ADDR_WIDTH-1:0]   refill_line_addr;    // Completed refill line base address.
  logic [LINE_BITS-1:0]    refill_line_data;    // Completed refill line payload.
  logic                    refill_line_error;   // Sticky downstream error from refill.

  logic                    store_start_valid;   // Control requests a write-through store.
  logic                    store_start_ready;   // Store sequencer can accept a start.
  logic [ADDR_WIDTH-1:0]   store_start_addr;    // Store byte address.
  logic [1:0]              store_start_size;    // Store size encoding.
  logic [DATA_WIDTH-1:0]   store_start_wdata;   // Store write data.
  logic [STRB_WIDTH-1:0]   store_start_wstrb;   // Store byte strobes.
  logic                    store_flush;         // Flush forwarded from control to store.
  logic                    store_done_valid;    // Store sequencer completed a transaction.
  logic                    store_done_ready;    // Control accepts store completion.
  logic [ADDR_WIDTH-1:0]   store_done_addr;     // Completed store address.
  logic [1:0]              store_done_size;     // Completed store size.
  logic [DATA_WIDTH-1:0]   store_done_wdata;    // Completed store write data.
  logic [STRB_WIDTH-1:0]   store_done_wstrb;    // Completed store byte strobes.
  logic                    store_done_error;    // Store downstream response error.

  logic                    uncached_start_valid;// Control requests uncached single transaction.
  logic                    uncached_start_ready;// Uncached sequencer can accept a start.
  logic [ADDR_WIDTH-1:0]   uncached_start_addr; // Uncached transaction byte address.
  logic                    uncached_start_write;// Uncached write indicator.
  logic [1:0]              uncached_start_size; // Uncached access size.
  logic [DATA_WIDTH-1:0]   uncached_start_wdata;// Uncached write data.
  logic [STRB_WIDTH-1:0]   uncached_start_wstrb;// Uncached write byte strobes.
  logic                    uncached_flush;      // Flush forwarded from control to uncached sequencer.
  logic                    uncached_done_valid; // Uncached transaction completed.
  logic                    uncached_done_ready; // Control accepts uncached completion.
  logic [DATA_WIDTH-1:0]   uncached_done_rdata; // Uncached read response data.
  logic                    uncached_done_error; // Uncached downstream response error.

  logic                    tag_refill_valid;    // Tag update pulse for accepted refill line.
  logic [ADDR_WIDTH-1:0]   tag_refill_addr;     // Refill line address for tag update.
  logic                    tag_refill_error;    // Refill error keeps tag invalid.
  logic                    data_refill_valid;   // Data update pulse for accepted refill line.
  logic [ADDR_WIDTH-1:0]   data_refill_addr;    // Refill line address for data update.
  logic [LINE_BITS-1:0]    data_refill_line;    // Refill line payload for data update.
  logic                    data_store_valid;    // Store-hit update pulse for data leaf.
  logic [ADDR_WIDTH-1:0]   data_store_addr;     // Store-hit update address.
  logic [DATA_WIDTH-1:0]   data_store_wdata;    // Store-hit update data.
  logic [STRB_WIDTH-1:0]   data_store_wstrb;    // Store-hit update byte strobes.

  mem_req_rsp_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) refill_mem_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  mem_req_rsp_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) store_mem_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  mem_req_rsp_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) uncached_mem_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  function automatic logic addr_in_window(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [ADDR_WIDTH-1:0] base,
    input logic [ADDR_WIDTH-1:0] size
  );
    logic [ADDR_WIDTH-1:0] offset;
    begin
      offset = addr - base;
      addr_in_window = (addr >= base) && (offset < size);
    end
  endfunction

  function automatic logic is_cacheable_addr(input logic [ADDR_WIDTH-1:0] addr);
    begin
      is_cacheable_addr = addr_in_window(addr, CACHEABLE0_BASE, CACHEABLE0_SIZE) ||
                          addr_in_window(addr, CACHEABLE1_BASE, CACHEABLE1_SIZE) ||
                          addr_in_window(addr, CACHEABLE2_BASE, CACHEABLE2_SIZE);
    end
  endfunction

  assign req_cacheable = is_cacheable_addr(core_if.req_addr);

  // Refill and store sequencers are mutually exclusive by construction in
  // dcache_ctrl. This combinational mux keeps the top-level wrapper stateless
  // while presenting one downstream memory initiator port to the SoC fabric.
  always_comb begin
    mem_if.req_valid = refill_mem_if.req_valid || store_mem_if.req_valid ||
                       uncached_mem_if.req_valid;
    mem_if.req_addr = store_mem_if.req_valid ? store_mem_if.req_addr :
                      (uncached_mem_if.req_valid ? uncached_mem_if.req_addr :
                       refill_mem_if.req_addr);
    mem_if.req_write = store_mem_if.req_valid ? store_mem_if.req_write :
                       (uncached_mem_if.req_valid ? uncached_mem_if.req_write :
                        refill_mem_if.req_write);
    mem_if.req_size = store_mem_if.req_valid ? store_mem_if.req_size :
                      (uncached_mem_if.req_valid ? uncached_mem_if.req_size :
                       refill_mem_if.req_size);
    mem_if.req_wdata = store_mem_if.req_valid ? store_mem_if.req_wdata :
                       (uncached_mem_if.req_valid ? uncached_mem_if.req_wdata :
                        refill_mem_if.req_wdata);
    mem_if.req_wstrb = store_mem_if.req_valid ? store_mem_if.req_wstrb :
                       (uncached_mem_if.req_valid ? uncached_mem_if.req_wstrb :
                        refill_mem_if.req_wstrb);
    mem_if.req_instr = 1'b0;
    mem_if.rsp_ready = refill_mem_if.rsp_ready || store_mem_if.rsp_ready ||
                       uncached_mem_if.rsp_ready;

    refill_mem_if.req_ready = mem_if.req_ready && refill_mem_if.req_valid &&
                              !store_mem_if.req_valid && !uncached_mem_if.req_valid;
    refill_mem_if.rsp_valid = mem_if.rsp_valid && refill_mem_if.rsp_ready;
    refill_mem_if.rsp_rdata = mem_if.rsp_rdata;
    refill_mem_if.rsp_err = mem_if.rsp_err;

    store_mem_if.req_ready = mem_if.req_ready && store_mem_if.req_valid;
    store_mem_if.rsp_valid = mem_if.rsp_valid && store_mem_if.rsp_ready;
    store_mem_if.rsp_rdata = mem_if.rsp_rdata;
    store_mem_if.rsp_err = mem_if.rsp_err;

    uncached_mem_if.req_ready = mem_if.req_ready && uncached_mem_if.req_valid &&
                                !store_mem_if.req_valid;
    uncached_mem_if.rsp_valid = mem_if.rsp_valid && uncached_mem_if.rsp_ready;
    uncached_mem_if.rsp_rdata = mem_if.rsp_rdata;
    uncached_mem_if.rsp_err = mem_if.rsp_err;
  end

  dcache_ctrl #(
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_ctrl (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(flush_i),
    .core_if(core_if),
    .req_cacheable_i(req_cacheable),
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
    .store_start_valid_o(store_start_valid),
    .store_start_ready_i(store_start_ready),
    .store_start_addr_o(store_start_addr),
    .store_start_size_o(store_start_size),
    .store_start_wdata_o(store_start_wdata),
    .store_start_wstrb_o(store_start_wstrb),
    .store_flush_o(store_flush),
    .store_done_valid_i(store_done_valid),
    .store_done_ready_o(store_done_ready),
    .store_done_addr_i(store_done_addr),
    .store_done_size_i(store_done_size),
    .store_done_wdata_i(store_done_wdata),
    .store_done_wstrb_i(store_done_wstrb),
    .store_done_error_i(store_done_error),
    .uncached_start_valid_o(uncached_start_valid),
    .uncached_start_ready_i(uncached_start_ready),
    .uncached_start_addr_o(uncached_start_addr),
    .uncached_start_write_o(uncached_start_write),
    .uncached_start_size_o(uncached_start_size),
    .uncached_start_wdata_o(uncached_start_wdata),
    .uncached_start_wstrb_o(uncached_start_wstrb),
    .uncached_flush_o(uncached_flush),
    .uncached_done_valid_i(uncached_done_valid),
    .uncached_done_ready_o(uncached_done_ready),
    .uncached_done_rdata_i(uncached_done_rdata),
    .uncached_done_error_i(uncached_done_error),
    .tag_refill_valid_o(tag_refill_valid),
    .tag_refill_addr_o(tag_refill_addr),
    .tag_refill_error_o(tag_refill_error),
    .data_refill_valid_o(data_refill_valid),
    .data_refill_addr_o(data_refill_addr),
    .data_refill_line_o(data_refill_line),
    .data_store_valid_o(data_store_valid),
    .data_store_addr_o(data_store_addr),
    .data_store_wdata_o(data_store_wdata),
    .data_store_wstrb_o(data_store_wstrb)
  );

  dcache_tag #(
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

  dcache_data #(
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
    .refill_line_i(data_refill_line),
    .store_valid_i(data_store_valid),
    .store_addr_i(data_store_addr),
    .store_wdata_i(data_store_wdata),
    .store_wstrb_i(data_store_wstrb)
  );

  dcache_refill #(
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
    .mem_if(refill_mem_if)
  );

  dcache_store #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_store (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(store_flush),
    .start_valid_i(store_start_valid),
    .start_ready_o(store_start_ready),
    .start_addr_i(store_start_addr),
    .start_size_i(store_start_size),
    .start_wdata_i(store_start_wdata),
    .start_wstrb_i(store_start_wstrb),
    .done_valid_o(store_done_valid),
    .done_ready_i(store_done_ready),
    .done_addr_o(store_done_addr),
    .done_size_o(store_done_size),
    .done_wdata_o(store_done_wdata),
    .done_wstrb_o(store_done_wstrb),
    .done_error_o(store_done_error),
    .mem_if(store_mem_if)
  );

  dcache_uncached #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_uncached (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(uncached_flush),
    .start_valid_i(uncached_start_valid),
    .start_ready_o(uncached_start_ready),
    .start_addr_i(uncached_start_addr),
    .start_write_i(uncached_start_write),
    .start_size_i(uncached_start_size),
    .start_wdata_i(uncached_start_wdata),
    .start_wstrb_i(uncached_start_wstrb),
    .done_valid_o(uncached_done_valid),
    .done_ready_i(uncached_done_ready),
    .done_rdata_o(uncached_done_rdata),
    .done_error_o(uncached_done_error),
    .mem_if(uncached_mem_if)
  );
endmodule
