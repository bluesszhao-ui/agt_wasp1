`timescale 1ns/1ps

// dcache_store sequences one write-through data-cache store transaction.
//
// The block captures one store request, emits one downstream data write through
// mem_req_rsp_if, waits for the downstream response, and reports completion to
// the later D-cache control FSM. It does not decide cache hit/miss policy and
// does not update the data RAM directly.
module dcache_store #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input  logic                  clk_i,          // Store controller clock.
  input  logic                  rst_ni,         // Active-low asynchronous reset.
  input  logic                  flush_i,        // Abort active transaction and suppress completion.

  input  logic                  start_valid_i,  // Store request is valid.
  output logic                  start_ready_o,  // Store controller can accept a request.
  input  logic [ADDR_WIDTH-1:0] start_addr_i,   // Store byte address captured on start fire.
  input  logic [1:0]            start_size_i,   // Store size encoding captured unchanged.
  input  logic [DATA_WIDTH-1:0] start_wdata_i,  // Store write data captured unchanged.
  input  logic [DATA_WIDTH/8-1:0] start_wstrb_i,// Store byte strobes captured unchanged.

  output logic                  done_valid_o,   // Completed store status is valid.
  input  logic                  done_ready_i,   // D-cache control accepted the completion.
  output logic [ADDR_WIDTH-1:0] done_addr_o,    // Completed store address.
  output logic [1:0]            done_size_o,    // Completed store size.
  output logic [DATA_WIDTH-1:0] done_wdata_o,   // Completed store write data.
  output logic [DATA_WIDTH/8-1:0] done_wstrb_o, // Completed store byte strobes.
  output logic                  done_error_o,   // Downstream response error for this store.

  mem_req_rsp_if.initiator mem_if               // Downstream data memory/cache path.
);
  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  typedef enum logic [1:0] {
    STORE_IDLE = 2'b00,
    STORE_REQ  = 2'b01,
    STORE_WAIT = 2'b10,
    STORE_DONE = 2'b11
  } store_state_e;

  store_state_e          state_q;       // Store FSM state.
  logic [ADDR_WIDTH-1:0] addr_q;        // Captured store byte address.
  logic [1:0]            size_q;        // Captured request size encoding.
  logic [DATA_WIDTH-1:0] wdata_q;       // Captured downstream write data.
  logic [STRB_WIDTH-1:0] wstrb_q;       // Captured downstream byte enables.
  logic                  error_q;       // Captured downstream response error.
  logic                  start_fire;    // Start request accepted this cycle.
  logic                  req_fire;      // Downstream write request accepted this cycle.
  logic                  rsp_fire;      // Downstream write response consumed this cycle.
  logic                  done_fire;     // Completion accepted this cycle.

  assign start_ready_o = (state_q == STORE_IDLE) && !flush_i;
  assign start_fire = start_valid_i && start_ready_o;
  assign req_fire = mem_if.req_valid && mem_if.req_ready;
  assign rsp_fire = mem_if.rsp_valid && mem_if.rsp_ready;
  assign done_fire = done_valid_o && done_ready_i;

  assign mem_if.req_valid = (state_q == STORE_REQ) && !flush_i;
  assign mem_if.req_addr = addr_q;
  assign mem_if.req_write = 1'b1;
  assign mem_if.req_size = size_q;
  assign mem_if.req_wdata = wdata_q;
  assign mem_if.req_wstrb = wstrb_q;
  assign mem_if.req_instr = 1'b0;
  assign mem_if.rsp_ready = (state_q == STORE_WAIT) && !flush_i;

  assign done_valid_o = (state_q == STORE_DONE) && !flush_i;
  assign done_addr_o = addr_q;
  assign done_size_o = size_q;
  assign done_wdata_o = wdata_q;
  assign done_wstrb_o = wstrb_q;
  assign done_error_o = error_q;

  // Store FSM priority is reset, flush abort, then normal valid/ready
  // sequencing. Captured request fields are held stable through REQ, WAIT, and
  // DONE so the downstream bus and the control FSM see a single coherent store.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= STORE_IDLE;
      addr_q <= '0;
      size_q <= '0;
      wdata_q <= '0;
      wstrb_q <= '0;
      error_q <= 1'b0;
    end else if (flush_i) begin
      state_q <= STORE_IDLE;
      error_q <= 1'b0;
    end else begin
      unique case (state_q)
        STORE_IDLE: begin
          if (start_fire) begin
            state_q <= STORE_REQ;
            addr_q <= start_addr_i;
            size_q <= start_size_i;
            wdata_q <= start_wdata_i;
            wstrb_q <= start_wstrb_i;
            error_q <= 1'b0;
          end
        end
        STORE_REQ: begin
          if (req_fire) begin
            state_q <= STORE_WAIT;
          end
        end
        STORE_WAIT: begin
          if (rsp_fire) begin
            error_q <= mem_if.rsp_err;
            state_q <= STORE_DONE;
          end
        end
        STORE_DONE: begin
          if (done_fire) begin
            state_q <= STORE_IDLE;
            error_q <= 1'b0;
          end
        end
        default: begin
          state_q <= STORE_IDLE;
          error_q <= 1'b0;
        end
      endcase
    end
  end
endmodule
