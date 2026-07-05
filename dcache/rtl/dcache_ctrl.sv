`timescale 1ns/1ps

// dcache_ctrl sequences core data requests through the direct-mapped D-cache.
//
// The controller accepts one core request at a time. Load hits return the
// cached word, load misses start a line refill and update tag/data storage,
// stores always issue a write-through transaction, and only successful store
// hits merge data back into the cache line.
module dcache_ctrl #(
  parameter int LINE_BYTES = 16,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                    clk_i,                 // D-cache control clock.
  input  logic                    rst_ni,                // Active-low asynchronous reset.
  input  logic                    flush_i,               // Abort active refill/store/response work.

  mem_req_rsp_if.target           core_if,               // Core data request/response port.

  input  logic                    req_cacheable_i,       // Current core request may allocate/use cache arrays.

  output logic                    lookup_valid_o,        // Qualifies tag/data lookup for current request.
  output logic [ADDR_WIDTH-1:0]   lookup_addr_o,         // Address presented to tag/data lookup leaves.
  input  logic                    tag_hit_i,             // Tag lookup hit for lookup_addr_o.
  input  logic [DATA_WIDTH-1:0]   data_word_i,           // Cached data word for lookup_addr_o.

  output logic                    refill_start_valid_o,  // Start a load-miss cache-line refill.
  input  logic                    refill_start_ready_i,  // Refill sequencer can accept a start.
  output logic [ADDR_WIDTH-1:0]   refill_start_addr_o,   // Miss address used to derive refill line base.
  output logic                    refill_flush_o,        // Flush forwarded to refill sequencer.

  input  logic                    refill_line_valid_i,   // Completed refill line is available.
  output logic                    refill_line_ready_o,   // Controller accepts completed refill line.
  input  logic [ADDR_WIDTH-1:0]   refill_line_addr_i,    // Line-aligned refill address.
  input  logic [LINE_BYTES*8-1:0] refill_line_data_i,    // Completed refill cache line.
  input  logic                    refill_line_error_i,   // Refill completion has downstream error.

  output logic                    store_start_valid_o,   // Start a write-through store transaction.
  input  logic                    store_start_ready_i,   // Store sequencer can accept a start.
  output logic [ADDR_WIDTH-1:0]   store_start_addr_o,    // Store byte address.
  output logic [1:0]              store_start_size_o,    // Store size encoding.
  output logic [DATA_WIDTH-1:0]   store_start_wdata_o,   // Store write data.
  output logic [DATA_WIDTH/8-1:0] store_start_wstrb_o,   // Store byte strobes.
  output logic                    store_flush_o,         // Flush forwarded to store sequencer.

  input  logic                    store_done_valid_i,    // Store sequencer completion is valid.
  output logic                    store_done_ready_o,    // Controller accepts store completion.
  input  logic [ADDR_WIDTH-1:0]   store_done_addr_i,     // Completed store address.
  input  logic [1:0]              store_done_size_i,     // Completed store size.
  input  logic [DATA_WIDTH-1:0]   store_done_wdata_i,    // Completed store write data.
  input  logic [DATA_WIDTH/8-1:0] store_done_wstrb_i,    // Completed store byte strobes.
  input  logic                    store_done_error_i,    // Completed store downstream error.

  output logic                    uncached_start_valid_o,// Start a single uncached read/write transaction.
  input  logic                    uncached_start_ready_i,// Uncached sequencer can accept a start.
  output logic [ADDR_WIDTH-1:0]   uncached_start_addr_o, // Uncached byte address.
  output logic                    uncached_start_write_o,// Uncached write indicator.
  output logic [1:0]              uncached_start_size_o, // Uncached access size.
  output logic [DATA_WIDTH-1:0]   uncached_start_wdata_o,// Uncached write data.
  output logic [DATA_WIDTH/8-1:0] uncached_start_wstrb_o,// Uncached write strobes.
  output logic                    uncached_flush_o,      // Flush forwarded to uncached sequencer.

  input  logic                    uncached_done_valid_i, // Uncached transaction completed.
  output logic                    uncached_done_ready_o, // Controller accepts uncached completion.
  input  logic [DATA_WIDTH-1:0]   uncached_done_rdata_i, // Uncached read data.
  input  logic                    uncached_done_error_i, // Uncached downstream error.

  output logic                    tag_refill_valid_o,    // Write tag/valid state for accepted refill.
  output logic [ADDR_WIDTH-1:0]   tag_refill_addr_o,     // Refilled line address for tag update.
  output logic                    tag_refill_error_o,    // Tag update should leave line invalid on error.

  output logic                    data_refill_valid_o,   // Write data line for accepted refill.
  output logic [ADDR_WIDTH-1:0]   data_refill_addr_o,    // Refilled line address for data update.
  output logic [LINE_BYTES*8-1:0] data_refill_line_o,    // Refilled line payload for data update.

  output logic                    data_store_valid_o,    // Successful store-hit cache update pulse.
  output logic [ADDR_WIDTH-1:0]   data_store_addr_o,     // Store-hit update address.
  output logic [DATA_WIDTH-1:0]   data_store_wdata_o,    // Store-hit update data.
  output logic [DATA_WIDTH/8-1:0] data_store_wstrb_o     // Store-hit update byte strobes.
);
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int WORD_INDEX_BITS = (WORDS_PER_LINE <= 1) ? 1 : $clog2(WORDS_PER_LINE);
  localparam int BYTE_OFFSET_BITS = $clog2(DATA_BYTES);
  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  typedef enum logic [2:0] {
    CTRL_IDLE             = 3'b000,
    CTRL_LOAD_REFILL_REQ  = 3'b001,
    CTRL_LOAD_REFILL_WAIT = 3'b010,
    CTRL_STORE_REQ        = 3'b011,
    CTRL_STORE_WAIT       = 3'b100,
    CTRL_RESP             = 3'b101,
    CTRL_UNCACHED_REQ     = 3'b110,
    CTRL_UNCACHED_WAIT    = 3'b111
  } ctrl_state_e;

  ctrl_state_e          state_q;              // Core/refill/store control FSM state.
  logic [ADDR_WIDTH-1:0] req_addr_q;          // Captured core request address.
  logic [1:0]            req_size_q;          // Captured core request size.
  logic                  req_write_q;         // Captured core request write indicator.
  logic [DATA_WIDTH-1:0] req_wdata_q;         // Captured store write data.
  logic [STRB_WIDTH-1:0] req_wstrb_q;         // Captured store byte strobes.
  logic                  store_hit_q;         // Captured tag-hit result for a store request.
  logic [DATA_WIDTH-1:0] rsp_data_q;          // Held core response data.
  logic                  rsp_err_q;           // Held core response error.
  logic                  req_fire;            // Core request accepted this cycle.
  logic                  rsp_fire;            // Core response accepted this cycle.
  logic                  refill_start_fire;   // Refill start accepted this cycle.
  logic                  refill_line_fire;    // Refill line accepted this cycle.
  logic                  store_start_fire;    // Store start accepted this cycle.
  logic                  store_done_fire;     // Store completion accepted this cycle.
  logic                  uncached_start_fire; // Uncached start accepted this cycle.
  logic                  uncached_done_fire;  // Uncached completion accepted this cycle.
  logic                  invalid_req;         // Current core request fails D-cache legality checks.
  logic                  misaligned_req;      // Current request violates natural alignment for its size.
  logic [DATA_WIDTH-1:0] refill_word;         // Requested word selected from refill line data.
  logic [WORD_INDEX_BITS-1:0] req_word_index; // Word offset of captured request address.

  assign req_fire = core_if.req_valid && core_if.req_ready;
  assign rsp_fire = core_if.rsp_valid && core_if.rsp_ready;
  assign refill_start_fire = refill_start_valid_o && refill_start_ready_i;
  assign refill_line_fire = refill_line_valid_i && refill_line_ready_o;
  assign store_start_fire = store_start_valid_o && store_start_ready_i;
  assign store_done_fire = store_done_valid_i && store_done_ready_o;
  assign uncached_start_fire = uncached_start_valid_o && uncached_start_ready_i;
  assign uncached_done_fire = uncached_done_valid_i && uncached_done_ready_o;

  // The LSU normally suppresses misaligned requests, but the cache controller
  // still checks alignment so an invalid direct request cannot start bus work.
  always_comb begin
    unique case (core_if.req_size)
      2'd0:    misaligned_req = 1'b0;
      2'd1:    misaligned_req = core_if.req_addr[0];
      2'd2:    misaligned_req = |core_if.req_addr[1:0];
      default: misaligned_req = 1'b1;
    endcase
  end

  assign invalid_req = core_if.req_instr || (core_if.req_size == 2'd3) || misaligned_req;
  assign req_word_index = req_addr_q[BYTE_OFFSET_BITS +: WORD_INDEX_BITS];

  assign core_if.req_ready = (state_q == CTRL_IDLE) && !flush_i;
  assign core_if.rsp_valid = (state_q == CTRL_RESP) && !flush_i;
  assign core_if.rsp_rdata = rsp_data_q;
  assign core_if.rsp_err = rsp_err_q;

  assign lookup_valid_o = core_if.req_valid && req_cacheable_i &&
                          (state_q == CTRL_IDLE) && !flush_i;
  assign lookup_addr_o = (state_q == CTRL_IDLE) ? core_if.req_addr : req_addr_q;

  assign refill_start_valid_o = (state_q == CTRL_LOAD_REFILL_REQ) && !flush_i;
  assign refill_start_addr_o = req_addr_q;
  assign refill_flush_o = flush_i;
  assign refill_line_ready_o = (state_q == CTRL_LOAD_REFILL_WAIT) && !flush_i;

  assign store_start_valid_o = (state_q == CTRL_STORE_REQ) && !flush_i;
  assign store_start_addr_o = req_addr_q;
  assign store_start_size_o = req_size_q;
  assign store_start_wdata_o = req_wdata_q;
  assign store_start_wstrb_o = req_wstrb_q;
  assign store_flush_o = flush_i;
  assign store_done_ready_o = (state_q == CTRL_STORE_WAIT) && !flush_i;

  assign uncached_start_valid_o = (state_q == CTRL_UNCACHED_REQ) && !flush_i;
  assign uncached_start_addr_o = req_addr_q;
  assign uncached_start_write_o = req_write_q;
  assign uncached_start_size_o = req_size_q;
  assign uncached_start_wdata_o = req_wdata_q;
  assign uncached_start_wstrb_o = req_wstrb_q;
  assign uncached_flush_o = flush_i;
  assign uncached_done_ready_o = (state_q == CTRL_UNCACHED_WAIT) && !flush_i;

  assign tag_refill_valid_o = refill_line_fire;
  assign tag_refill_addr_o = refill_line_addr_i;
  assign tag_refill_error_o = refill_line_error_i;
  assign data_refill_valid_o = refill_line_fire;
  assign data_refill_addr_o = refill_line_addr_i;
  assign data_refill_line_o = refill_line_data_i;

  assign data_store_valid_o = store_done_fire && store_hit_q && !store_done_error_i;
  assign data_store_addr_o = store_done_addr_i;
  assign data_store_wdata_o = store_done_wdata_i;
  assign data_store_wstrb_o = store_done_wstrb_i;

  // Refill line words are stored little-endian by word number. The captured
  // request address selects the word returned to the LSU.
  always_comb begin
    refill_word = '0;
    for (int word = 0; word < WORDS_PER_LINE; word++) begin
      if (req_word_index == WORD_INDEX_BITS'(word)) begin
        refill_word = refill_line_data_i[word * DATA_WIDTH +: DATA_WIDTH];
      end
    end
  end

  // Main controller priority is reset, flush abort, then normal handshakes.
  // Request fields are captured before entering refill/store paths so outputs
  // remain stable while subordinate sequencers apply backpressure.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= CTRL_IDLE;
      req_addr_q <= '0;
      req_size_q <= '0;
      req_write_q <= 1'b0;
      req_wdata_q <= '0;
      req_wstrb_q <= '0;
      store_hit_q <= 1'b0;
      rsp_data_q <= '0;
      rsp_err_q <= 1'b0;
    end else if (flush_i) begin
      state_q <= CTRL_IDLE;
      rsp_data_q <= '0;
      rsp_err_q <= 1'b0;
      store_hit_q <= 1'b0;
    end else begin
      unique case (state_q)
        CTRL_IDLE: begin
          if (req_fire) begin
            req_addr_q <= core_if.req_addr;
            req_size_q <= core_if.req_size;
            req_write_q <= core_if.req_write;
            req_wdata_q <= core_if.req_wdata;
            req_wstrb_q <= core_if.req_wstrb;
            store_hit_q <= core_if.req_write && req_cacheable_i && tag_hit_i;
            if (invalid_req) begin
              rsp_data_q <= '0;
              rsp_err_q <= 1'b1;
              state_q <= CTRL_RESP;
            end else if (!req_cacheable_i) begin
              state_q <= CTRL_UNCACHED_REQ;
            end else if (core_if.req_write) begin
              state_q <= CTRL_STORE_REQ;
            end else if (tag_hit_i) begin
              rsp_data_q <= data_word_i;
              rsp_err_q <= 1'b0;
              state_q <= CTRL_RESP;
            end else begin
              state_q <= CTRL_LOAD_REFILL_REQ;
            end
          end
        end
        CTRL_LOAD_REFILL_REQ: begin
          if (refill_start_fire) begin
            state_q <= CTRL_LOAD_REFILL_WAIT;
          end
        end
        CTRL_LOAD_REFILL_WAIT: begin
          if (refill_line_fire) begin
            rsp_data_q <= refill_word;
            rsp_err_q <= refill_line_error_i;
            state_q <= CTRL_RESP;
          end
        end
        CTRL_STORE_REQ: begin
          if (store_start_fire) begin
            state_q <= CTRL_STORE_WAIT;
          end
        end
        CTRL_STORE_WAIT: begin
          if (store_done_fire) begin
            rsp_data_q <= '0;
            rsp_err_q <= store_done_error_i;
            state_q <= CTRL_RESP;
          end
        end
        CTRL_UNCACHED_REQ: begin
          if (uncached_start_fire) begin
            state_q <= CTRL_UNCACHED_WAIT;
          end
        end
        CTRL_UNCACHED_WAIT: begin
          if (uncached_done_fire) begin
            rsp_data_q <= uncached_done_rdata_i;
            rsp_err_q <= uncached_done_error_i;
            state_q <= CTRL_RESP;
          end
        end
        CTRL_RESP: begin
          if (rsp_fire) begin
            state_q <= CTRL_IDLE;
            rsp_err_q <= 1'b0;
            store_hit_q <= 1'b0;
          end
        end
        default: begin
          state_q <= CTRL_IDLE;
          rsp_data_q <= '0;
          rsp_err_q <= 1'b0;
          store_hit_q <= 1'b0;
        end
      endcase
    end
  end
endmodule
