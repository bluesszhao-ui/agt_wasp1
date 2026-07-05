`timescale 1ns/1ps

// dcache_uncached issues one downstream transaction for an uncached D-cache
// access.
//
// This sequencer is used for MMIO/device regions. It never allocates tag/data
// state and it never combines adjacent words into a cache-line refill, so
// software-visible device reads always observe the current peripheral value.
module dcache_uncached #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                    clk_i,          // D-cache clock.
  input  logic                    rst_ni,         // Active-low asynchronous reset.
  input  logic                    flush_i,        // Abort an active uncached transaction.

  input  logic                    start_valid_i,  // Uncached access request is valid.
  output logic                    start_ready_o,  // Sequencer can accept a request.
  input  logic [ADDR_WIDTH-1:0]   start_addr_i,   // Byte address for the single transaction.
  input  logic                    start_write_i,  // High for write, low for read.
  input  logic [1:0]              start_size_i,   // Access size encoding.
  input  logic [DATA_WIDTH-1:0]   start_wdata_i,  // Write payload.
  input  logic [DATA_WIDTH/8-1:0] start_wstrb_i,  // Write byte enables.

  output logic                    done_valid_o,   // Response is available to dcache_ctrl.
  input  logic                    done_ready_i,   // dcache_ctrl accepted the response.
  output logic [DATA_WIDTH-1:0]   done_rdata_o,   // Read data for uncached loads.
  output logic                    done_error_o,   // Downstream response error.

  mem_req_rsp_if.initiator        mem_if          // Downstream memory/MMIO request path.
);
  typedef enum logic [1:0] {
    UNCACHED_IDLE = 2'b00,
    UNCACHED_REQ  = 2'b01,
    UNCACHED_WAIT = 2'b10,
    UNCACHED_DONE = 2'b11
  } uncached_state_e;

  uncached_state_e      state_q;      // Uncached transaction FSM state.
  logic [ADDR_WIDTH-1:0] addr_q;      // Captured byte address.
  logic                  write_q;     // Captured write indicator.
  logic [1:0]            size_q;      // Captured size encoding.
  logic [DATA_WIDTH-1:0] wdata_q;     // Captured write payload.
  logic [DATA_WIDTH/8-1:0] wstrb_q;   // Captured write byte enables.
  logic [DATA_WIDTH-1:0] rdata_q;     // Held read data response.
  logic                  error_q;     // Held downstream response error.
  logic                  start_fire;  // Request accepted from dcache_ctrl.
  logic                  req_fire;    // Downstream address/data phase accepted.
  logic                  rsp_fire;    // Downstream response accepted.
  logic                  done_fire;   // Response accepted by dcache_ctrl.

  assign start_ready_o = (state_q == UNCACHED_IDLE) && !flush_i;
  assign start_fire = start_valid_i && start_ready_o;
  assign req_fire = mem_if.req_valid && mem_if.req_ready;
  assign rsp_fire = mem_if.rsp_valid && mem_if.rsp_ready;
  assign done_fire = done_valid_o && done_ready_i;

  assign mem_if.req_valid = (state_q == UNCACHED_REQ) && !flush_i;
  assign mem_if.req_addr = addr_q;
  assign mem_if.req_write = write_q;
  assign mem_if.req_size = size_q;
  assign mem_if.req_wdata = wdata_q;
  assign mem_if.req_wstrb = wstrb_q;
  assign mem_if.req_instr = 1'b0;
  assign mem_if.rsp_ready = (state_q == UNCACHED_WAIT) && !flush_i;

  assign done_valid_o = (state_q == UNCACHED_DONE) && !flush_i;
  assign done_rdata_o = rdata_q;
  assign done_error_o = error_q;

  // The transaction FSM keeps request fields stable until the downstream
  // handshake completes, then holds the response for dcache_ctrl backpressure.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= UNCACHED_IDLE;
      addr_q <= '0;
      write_q <= 1'b0;
      size_q <= '0;
      wdata_q <= '0;
      wstrb_q <= '0;
      rdata_q <= '0;
      error_q <= 1'b0;
    end else if (flush_i) begin
      state_q <= UNCACHED_IDLE;
      rdata_q <= '0;
      error_q <= 1'b0;
    end else begin
      unique case (state_q)
        UNCACHED_IDLE: begin
          if (start_fire) begin
            state_q <= UNCACHED_REQ;
            addr_q <= start_addr_i;
            write_q <= start_write_i;
            size_q <= start_size_i;
            wdata_q <= start_wdata_i;
            wstrb_q <= start_wstrb_i;
            rdata_q <= '0;
            error_q <= 1'b0;
          end
        end
        UNCACHED_REQ: begin
          if (req_fire) begin
            state_q <= UNCACHED_WAIT;
          end
        end
        UNCACHED_WAIT: begin
          if (rsp_fire) begin
            state_q <= UNCACHED_DONE;
            rdata_q <= mem_if.rsp_rdata;
            error_q <= mem_if.rsp_err;
          end
        end
        UNCACHED_DONE: begin
          if (done_fire) begin
            state_q <= UNCACHED_IDLE;
            rdata_q <= '0;
            error_q <= 1'b0;
          end
        end
        default: begin
          state_q <= UNCACHED_IDLE;
          rdata_q <= '0;
          error_q <= 1'b0;
        end
      endcase
    end
  end
endmodule
