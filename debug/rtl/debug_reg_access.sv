`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Sequencer for one Debug Module general-purpose-register access transaction.
module debug_reg_access (
  input  logic          clk_i,          // Debug/core transaction clock.
  input  logic          rst_ni,         // Asynchronous active-low sequencer reset.
  input  logic          flush_i,        // Abort local work and drain any accepted core request.
  input  logic          cmd_valid_i,    // Upstream GPR command is valid.
  output logic          cmd_ready_o,    // Sequencer can accept a new command.
  input  logic          cmd_write_i,    // One writes the GPR; zero reads it.
  input  logic [4:0]    cmd_addr_i,     // Integer register index x0-x31.
  input  logic [31:0]   cmd_wdata_i,    // GPR write payload.
  output logic          rsp_valid_o,    // Completed command response is valid.
  input  logic          rsp_ready_i,    // Upstream accepts the command response.
  output logic [31:0]   rsp_rdata_o,    // Captured core read response.
  output logic          rsp_error_o,    // Captured core access error.
  debug_if.dm_gpr       core_debug      // Structured GPR request/response channel to core.
);
  // DROP_RSP is essential after flushing an already accepted core request: it
  // prevents a delayed response from being paired with a later command.
  typedef enum logic [2:0] {
    REG_ACCESS_IDLE,
    REG_ACCESS_CORE_REQ,
    REG_ACCESS_CORE_WAIT,
    REG_ACCESS_LOCAL_RSP,
    REG_ACCESS_DROP_RSP
  } reg_access_state_e;

  reg_access_state_e state_q;
  reg_access_state_e state_d;

  // Captured command fields remain stable throughout core-side backpressure.
  logic        cmd_write_q;
  logic [4:0]  cmd_addr_q;
  logic [31:0] cmd_wdata_q;

  // Captured result remains stable throughout upstream response backpressure.
  logic [31:0] rsp_rdata_q;
  logic        rsp_error_q;

  // Handshake terms are named to keep transition conditions reviewable.
  logic cmd_fire;
  logic core_req_fire;
  logic core_rsp_fire;
  logic local_rsp_fire;

  assign cmd_fire = cmd_valid_i && cmd_ready_o;
  assign core_req_fire = core_debug.gpr_req_valid && core_debug.gpr_req_ready;
  assign core_rsp_fire = core_debug.gpr_rsp_valid && core_debug.gpr_rsp_ready;
  assign local_rsp_fire = rsp_valid_o && rsp_ready_i;

  // Upstream command/response channel decode.
  assign cmd_ready_o = (state_q == REG_ACCESS_IDLE) && !flush_i;
  assign rsp_valid_o = (state_q == REG_ACCESS_LOCAL_RSP);
  assign rsp_rdata_o = rsp_rdata_q;
  assign rsp_error_o = rsp_error_q;

  // Core request fields are driven only from captured registers. flush_i gates
  // an unaccepted request immediately so no new core transaction can start.
  always_comb begin
    core_debug.gpr_req_valid = 1'b0;
    core_debug.gpr_req_write = cmd_write_q;
    core_debug.gpr_req_addr = cmd_addr_q;
    core_debug.gpr_req_wdata = cmd_wdata_q;
    core_debug.gpr_rsp_ready = 1'b0;

    if ((state_q == REG_ACCESS_CORE_REQ) && !flush_i) begin
      core_debug.gpr_req_valid = 1'b1;
      // Supporting a response on the request-accept edge avoids imposing an
      // unnecessary minimum latency on a simple halted-core register path.
      core_debug.gpr_rsp_ready = core_debug.gpr_req_ready;
    end else if ((state_q == REG_ACCESS_CORE_WAIT) ||
                 (state_q == REG_ACCESS_DROP_RSP)) begin
      core_debug.gpr_rsp_ready = 1'b1;
    end
  end

  // Combinational state transitions separate transport timing from storage.
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      REG_ACCESS_IDLE: begin
        if (cmd_fire) state_d = REG_ACCESS_CORE_REQ;
      end

      REG_ACCESS_CORE_REQ: begin
        if (flush_i) begin
          state_d = REG_ACCESS_IDLE;
        end else if (core_req_fire) begin
          state_d = core_rsp_fire ? REG_ACCESS_LOCAL_RSP : REG_ACCESS_CORE_WAIT;
        end
      end

      REG_ACCESS_CORE_WAIT: begin
        if (flush_i) begin
          state_d = core_rsp_fire ? REG_ACCESS_IDLE : REG_ACCESS_DROP_RSP;
        end else if (core_rsp_fire) begin
          state_d = REG_ACCESS_LOCAL_RSP;
        end
      end

      REG_ACCESS_LOCAL_RSP: begin
        if (flush_i || local_rsp_fire) state_d = REG_ACCESS_IDLE;
      end

      REG_ACCESS_DROP_RSP: begin
        if (core_rsp_fire) state_d = REG_ACCESS_IDLE;
      end

      default: state_d = REG_ACCESS_IDLE;
    endcase
  end

  // Command and response registers update only on their respective handshakes.
  // Reset dominates; flush changes control state but never fabricates a result.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= REG_ACCESS_IDLE;
      cmd_write_q <= 1'b0;
      cmd_addr_q <= '0;
      cmd_wdata_q <= '0;
      rsp_rdata_q <= '0;
      rsp_error_q <= 1'b0;
    end else begin
      state_q <= state_d;

      if (cmd_fire) begin
        cmd_write_q <= cmd_write_i;
        cmd_addr_q <= cmd_addr_i;
        cmd_wdata_q <= cmd_wdata_i;
      end

      // A response captured during flush is deliberately discarded. Normal
      // and same-cycle responses use the same data/error storage.
      if (core_rsp_fire && !flush_i &&
          ((state_q == REG_ACCESS_CORE_WAIT) ||
           ((state_q == REG_ACCESS_CORE_REQ) && core_req_fire))) begin
        rsp_rdata_q <= core_debug.gpr_rsp_rdata;
        rsp_error_q <= core_debug.gpr_rsp_err;
      end
    end
  end
endmodule
