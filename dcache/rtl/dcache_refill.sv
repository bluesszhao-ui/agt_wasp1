`timescale 1ns/1ps

// dcache_refill sequences one direct-mapped data-cache line refill.
//
// A start request captures the load-miss address, aligns it to the cache-line
// base, reads one 32-bit data word at a time from the downstream memory path,
// assembles a full line, and presents the completed line to the cache update
// path.
module dcache_refill #(
  parameter int LINE_BYTES = 16,
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                    clk_i,          // D-cache refill controller clock.
  input  logic                    rst_ni,         // Active-low asynchronous reset.
  input  logic                    flush_i,        // Abort any active refill and suppress completion.

  input  logic                    start_valid_i,  // Load-miss refill request is valid.
  output logic                    start_ready_o,  // Refill controller can accept a new request.
  input  logic [ADDR_WIDTH-1:0]   start_addr_i,   // Miss address; low line-offset bits are cleared.

  output logic                    line_valid_o,   // Completed refill line is valid.
  input  logic                    line_ready_i,   // Cache accepted the completed refill line.
  output logic [ADDR_WIDTH-1:0]   line_addr_o,    // Line-aligned refill address.
  output logic [LINE_BYTES*8-1:0] line_data_o,    // Assembled cache line data.
  output logic                    line_error_o,   // At least one downstream word response had an error.

  mem_req_rsp_if.initiator mem_if                 // Downstream data memory/cache path.
);
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int BEAT_BITS = (WORDS_PER_LINE <= 1) ? 1 : $clog2(WORDS_PER_LINE);
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);

  typedef enum logic [1:0] {
    REFILL_IDLE = 2'b00,
    REFILL_REQ  = 2'b01,
    REFILL_WAIT = 2'b10,
    REFILL_DONE = 2'b11
  } refill_state_e;

  refill_state_e state_q;                   // Refill FSM state.
  logic [ADDR_WIDTH-1:0] line_addr_q;       // Captured line-aligned base address.
  logic [LINE_BITS-1:0]  line_data_q;       // Accumulated refill line.
  logic [BEAT_BITS-1:0]  beat_q;            // Current word beat within the line.
  logic                  error_q;           // Sticky refill error accumulator.
  logic                  start_fire;        // New refill accepted this cycle.
  logic                  req_fire;          // Downstream read request accepted this cycle.
  logic                  rsp_fire;          // Downstream read response consumed this cycle.
  logic                  done_fire;         // Completed line accepted by cache this cycle.
  logic                  last_beat;         // Current response is for the final line word.
  logic [ADDR_WIDTH-1:0] aligned_start_addr;// Start address with line offset cleared.
  logic [ADDR_WIDTH-1:0] beat_addr;         // Downstream word read address.

  assign aligned_start_addr = {start_addr_i[ADDR_WIDTH-1:OFFSET_BITS],
                               {OFFSET_BITS{1'b0}}};
  assign beat_addr = line_addr_q + ADDR_WIDTH'(beat_q) * ADDR_WIDTH'(DATA_BYTES);
  assign start_ready_o = (state_q == REFILL_IDLE) && !flush_i;
  assign start_fire = start_valid_i && start_ready_o;
  assign req_fire = mem_if.req_valid && mem_if.req_ready;
  assign rsp_fire = mem_if.rsp_valid && mem_if.rsp_ready;
  assign done_fire = line_valid_o && line_ready_i;
  assign last_beat = (beat_q == BEAT_BITS'(WORDS_PER_LINE - 1));

  assign mem_if.req_valid = (state_q == REFILL_REQ) && !flush_i;
  assign mem_if.req_addr = beat_addr;
  assign mem_if.req_write = 1'b0;
  assign mem_if.req_size = 2'd2;
  assign mem_if.req_wdata = '0;
  assign mem_if.req_wstrb = '0;
  assign mem_if.req_instr = 1'b0;
  assign mem_if.rsp_ready = (state_q == REFILL_WAIT) && !flush_i;

  assign line_valid_o = (state_q == REFILL_DONE) && !flush_i;
  assign line_addr_o = line_addr_q;
  assign line_data_o = line_data_q;
  assign line_error_o = error_q;

  // Refill FSM priority is reset, flush abort, then normal request/response
  // sequencing. Responses are stored little-endian by beat number.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= REFILL_IDLE;
      line_addr_q <= '0;
      line_data_q <= '0;
      beat_q <= '0;
      error_q <= 1'b0;
    end else if (flush_i) begin
      state_q <= REFILL_IDLE;
      beat_q <= '0;
      error_q <= 1'b0;
    end else begin
      unique case (state_q)
        REFILL_IDLE: begin
          if (start_fire) begin
            state_q <= REFILL_REQ;
            line_addr_q <= aligned_start_addr;
            line_data_q <= '0;
            beat_q <= '0;
            error_q <= 1'b0;
          end
        end
        REFILL_REQ: begin
          if (req_fire) begin
            state_q <= REFILL_WAIT;
          end
        end
        REFILL_WAIT: begin
          if (rsp_fire) begin
            line_data_q[DATA_WIDTH * beat_q +: DATA_WIDTH] <= mem_if.rsp_rdata;
            error_q <= error_q || mem_if.rsp_err;
            if (last_beat) begin
              state_q <= REFILL_DONE;
            end else begin
              beat_q <= beat_q + 1'b1;
              state_q <= REFILL_REQ;
            end
          end
        end
        REFILL_DONE: begin
          if (done_fire) begin
            state_q <= REFILL_IDLE;
            beat_q <= '0;
            error_q <= 1'b0;
          end
        end
        default: begin
          state_q <= REFILL_IDLE;
          beat_q <= '0;
          error_q <= 1'b0;
        end
      endcase
    end
  end
endmodule
