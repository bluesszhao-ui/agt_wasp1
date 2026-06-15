`timescale 1ns/1ps

// frontend_fetch translates frontend PC requests into instruction-memory reads.
//
// The block accepts one PC at a time, issues a read-only instruction request,
// and returns the fetched instruction with its PC. Redirect/trap flushes can
// kill an outstanding response so stale instructions are not delivered.
module frontend_fetch (
  input  logic        clk_i,              // Frontend clock for outstanding request state.
  input  logic        rst_ni,             // Active-low asynchronous reset.

  input  logic        pc_valid_i,         // PC request valid from frontend_pc.
  output logic        pc_ready_o,         // This block can accept the current PC.
  input  logic [31:0] pc_i,               // PC request address.
  input  logic        pc_misaligned_i,    // PC has non-zero low address bits.
  input  logic        flush_i,            // Drop current/new fetch due to redirect.

  output logic        instr_valid_o,      // Instruction response valid to ibuf/core side.
  input  logic        instr_ready_i,      // Consumer accepted instruction response.
  output logic [31:0] instr_pc_o,         // PC associated with instruction response.
  output logic [31:0] instr_o,            // Fetched instruction word.
  output logic        instr_fault_o,      // Fetch fault or misalignment indicator.
  output logic        instr_misaligned_o, // Response is due to a misaligned PC.

  mem_req_rsp_if.initiator imem_if        // Instruction memory/cache request interface.
);
  typedef enum logic [0:0] {
    FETCH_IDLE = 1'b0,
    FETCH_WAIT = 1'b1
  } fetch_state_e;

  fetch_state_e state_q;        // Outstanding fetch state.
  logic [31:0]  pc_q;           // PC captured with an accepted memory request.
  logic         kill_q;         // Outstanding memory response should be dropped.
  logic         aligned_req;    // Current PC can be sent to instruction memory.
  logic         req_fire;       // Memory request handshake completed.
  logic         misalign_rsp;   // Current PC produces an immediate misalignment fault.
  logic         mem_rsp_live;   // Memory response is live and can be delivered.
  logic         rsp_fire;       // Memory response was consumed or dropped.

  assign aligned_req = (state_q == FETCH_IDLE) && pc_valid_i &&
                       !pc_misaligned_i && !flush_i;
  assign req_fire = aligned_req && imem_if.req_ready;
  assign misalign_rsp = (state_q == FETCH_IDLE) && pc_valid_i &&
                        pc_misaligned_i && !flush_i;
  assign mem_rsp_live = (state_q == FETCH_WAIT) && !kill_q &&
                        !flush_i && imem_if.rsp_valid;

  assign imem_if.req_valid = aligned_req;
  assign imem_if.req_addr = pc_i;
  assign imem_if.req_write = 1'b0;
  assign imem_if.req_size = 2'd2;
  assign imem_if.req_wdata = 32'h0000_0000;
  assign imem_if.req_wstrb = 4'b0000;
  assign imem_if.req_instr = 1'b1;
  assign imem_if.rsp_ready = (state_q == FETCH_WAIT) &&
                             ((kill_q || flush_i) || instr_ready_i);

  assign rsp_fire = (state_q == FETCH_WAIT) && imem_if.rsp_valid &&
                    imem_if.rsp_ready;

  assign pc_ready_o = (state_q == FETCH_IDLE) && !flush_i &&
                      (!pc_valid_i ||
                       (pc_misaligned_i ? instr_ready_i : imem_if.req_ready));

  assign instr_valid_o = misalign_rsp || mem_rsp_live;
  assign instr_pc_o = misalign_rsp ? pc_i : pc_q;
  assign instr_o = misalign_rsp ? 32'h0000_0000 : imem_if.rsp_rdata;
  assign instr_fault_o = misalign_rsp ? 1'b1 : imem_if.rsp_err;
  assign instr_misaligned_o = misalign_rsp;

  // State priority is reset, request capture, response consume/drop, then flush
  // kill marking. A flush with a simultaneous response consumes and drops it.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= FETCH_IDLE;
      pc_q <= 32'h0000_0000;
      kill_q <= 1'b0;
    end else begin
      unique case (state_q)
        FETCH_IDLE: begin
          kill_q <= 1'b0;
          if (req_fire) begin
            state_q <= FETCH_WAIT;
            pc_q <= pc_i;
          end
        end
        FETCH_WAIT: begin
          if (rsp_fire) begin
            state_q <= FETCH_IDLE;
            kill_q <= 1'b0;
          end else if (flush_i) begin
            kill_q <= 1'b1;
          end
        end
        default: begin
          state_q <= FETCH_IDLE;
          kill_q <= 1'b0;
        end
      endcase
    end
  end
endmodule
