`timescale 1ns/1ps

// icache_ctrl sequences frontend instruction fetch requests through the
// direct-mapped tag/data lookup path and the line-refill path.
//
// The controller accepts one frontend request at a time. A lookup hit returns
// the cached word, a lookup miss starts a refill and updates tag/data storage
// when the completed line arrives, and invalid fetch requests complete with a
// fault response without touching the refill path.
module icache_ctrl #(
  parameter int LINE_BYTES = 16,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                    clk_i,                 // I-cache control clock.
  input  logic                    rst_ni,                // Active-low asynchronous reset.
  input  logic                    flush_i,               // Abort active miss/response and return idle.

  mem_req_rsp_if.target           front_if,              // Frontend instruction request/response port.

  output logic                    lookup_valid_o,        // Qualifies tag/data lookup for current request.
  output logic [ADDR_WIDTH-1:0]   lookup_addr_o,         // Address presented to tag/data lookup arrays.
  input  logic                    tag_hit_i,             // Tag lookup hit for lookup_addr_o.
  input  logic [DATA_WIDTH-1:0]   data_word_i,           // Cached instruction word for lookup_addr_o.

  output logic                    refill_start_valid_o,  // Start a downstream cache-line refill.
  input  logic                    refill_start_ready_i,  // Refill sequencer can accept start.
  output logic [ADDR_WIDTH-1:0]   refill_start_addr_o,   // Miss address used to derive refill line base.
  output logic                    refill_flush_o,        // Flush forwarded to refill sequencer.

  input  logic                    refill_line_valid_i,   // Completed refill line is available.
  output logic                    refill_line_ready_o,   // Controller accepts completed refill line.
  input  logic [ADDR_WIDTH-1:0]   refill_line_addr_i,    // Line-aligned refill address.
  input  logic [LINE_BYTES*8-1:0] refill_line_data_i,    // Completed refill cache line.
  input  logic                    refill_line_error_i,   // Refill completion has downstream error.

  output logic                    tag_refill_valid_o,    // Write tag/valid state for accepted refill.
  output logic [ADDR_WIDTH-1:0]   tag_refill_addr_o,     // Refilled line address for tag update.
  output logic                    tag_refill_error_o,    // Tag update should leave line invalid on error.

  output logic                    data_refill_valid_o,   // Write data line for accepted refill.
  output logic [ADDR_WIDTH-1:0]   data_refill_addr_o,    // Refilled line address for data update.
  output logic [LINE_BYTES*8-1:0] data_refill_line_o     // Refilled line payload for data update.
);
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int WORD_INDEX_BITS = (WORDS_PER_LINE <= 1) ? 1 : $clog2(WORDS_PER_LINE);
  localparam int BYTE_OFFSET_BITS = $clog2(DATA_BYTES);

  typedef enum logic [1:0] {
    CTRL_IDLE      = 2'b00,
    CTRL_MISS_REQ  = 2'b01,
    CTRL_MISS_WAIT = 2'b10,
    CTRL_RESP      = 2'b11
  } ctrl_state_e;

  ctrl_state_e state_q;                    // Frontend/refill control FSM state.
  logic [ADDR_WIDTH-1:0] miss_addr_q;      // Captured fetch address for an outstanding miss.
  logic [DATA_WIDTH-1:0] rsp_data_q;       // Held frontend response data.
  logic                  rsp_err_q;        // Held frontend response fault status.
  logic                  req_fire;         // Frontend request accepted this cycle.
  logic                  rsp_fire;         // Frontend response accepted this cycle.
  logic                  refill_start_fire;// Refill start accepted this cycle.
  logic                  refill_line_fire; // Refill line accepted this cycle.
  logic                  invalid_req;      // Current frontend request is not a legal fetch word.
  logic [DATA_WIDTH-1:0] refill_word;      // Requested word selected from the completed refill line.
  logic [WORD_INDEX_BITS-1:0] miss_word_index; // Word offset of captured miss address.

  assign req_fire = front_if.req_valid && front_if.req_ready;
  assign rsp_fire = front_if.rsp_valid && front_if.rsp_ready;
  assign refill_start_fire = refill_start_valid_o && refill_start_ready_i;
  assign refill_line_fire = refill_line_valid_i && refill_line_ready_o;

  assign invalid_req = front_if.req_write || (front_if.req_size != 2'd2) ||
                       !front_if.req_instr || (front_if.req_addr[1:0] != 2'b00);
  assign miss_word_index = miss_addr_q[BYTE_OFFSET_BITS +: WORD_INDEX_BITS];

  assign front_if.req_ready = (state_q == CTRL_IDLE) && !flush_i;
  assign front_if.rsp_valid = (state_q == CTRL_RESP) && !flush_i;
  assign front_if.rsp_rdata = rsp_data_q;
  assign front_if.rsp_err = rsp_err_q;

  assign lookup_valid_o = front_if.req_valid && (state_q == CTRL_IDLE) && !flush_i;
  assign lookup_addr_o = (state_q == CTRL_IDLE) ? front_if.req_addr : miss_addr_q;

  assign refill_start_valid_o = (state_q == CTRL_MISS_REQ) && !flush_i;
  assign refill_start_addr_o = miss_addr_q;
  assign refill_flush_o = flush_i;

  assign refill_line_ready_o = (state_q == CTRL_MISS_WAIT) && !flush_i;
  assign tag_refill_valid_o = refill_line_fire;
  assign tag_refill_addr_o = refill_line_addr_i;
  assign tag_refill_error_o = refill_line_error_i;
  assign data_refill_valid_o = refill_line_fire;
  assign data_refill_addr_o = refill_line_addr_i;
  assign data_refill_line_o = refill_line_data_i;

  // Refill data is arranged little-endian by word number. The captured miss
  // word offset selects the instruction that satisfies the original request.
  always_comb begin
    refill_word = '0;
    for (int word = 0; word < WORDS_PER_LINE; word++) begin
      if (miss_word_index == WORD_INDEX_BITS'(word)) begin
        refill_word = refill_line_data_i[word * DATA_WIDTH +: DATA_WIDTH];
      end
    end
  end

  // Main controller priority is reset, flush abort, then normal frontend/refill
  // handshakes. Responses are held stable until the frontend accepts them.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= CTRL_IDLE;
      miss_addr_q <= '0;
      rsp_data_q <= '0;
      rsp_err_q <= 1'b0;
    end else if (flush_i) begin
      state_q <= CTRL_IDLE;
      rsp_data_q <= '0;
      rsp_err_q <= 1'b0;
    end else begin
      unique case (state_q)
        CTRL_IDLE: begin
          if (req_fire) begin
            miss_addr_q <= front_if.req_addr;
            if (invalid_req) begin
              rsp_data_q <= '0;
              rsp_err_q <= 1'b1;
              state_q <= CTRL_RESP;
            end else if (tag_hit_i) begin
              rsp_data_q <= data_word_i;
              rsp_err_q <= 1'b0;
              state_q <= CTRL_RESP;
            end else begin
              state_q <= CTRL_MISS_REQ;
            end
          end
        end
        CTRL_MISS_REQ: begin
          if (refill_start_fire) begin
            state_q <= CTRL_MISS_WAIT;
          end
        end
        CTRL_MISS_WAIT: begin
          if (refill_line_fire) begin
            rsp_data_q <= refill_word;
            rsp_err_q <= refill_line_error_i;
            state_q <= CTRL_RESP;
          end
        end
        CTRL_RESP: begin
          if (rsp_fire) begin
            state_q <= CTRL_IDLE;
            rsp_err_q <= 1'b0;
          end
        end
        default: begin
          state_q <= CTRL_IDLE;
          rsp_data_q <= '0;
          rsp_err_q <= 1'b0;
        end
      endcase
    end
  end
endmodule
