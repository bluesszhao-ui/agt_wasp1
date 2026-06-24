`timescale 1ns/1ps

// Core Debug Mode control FSM.
//
// This block owns the minimal halted/running state used by the external Debug
// Module. It stops new frontend acceptance when a halt is requested, waits for
// the in-order pipeline to drain, then allows GPR debug accesses only while the
// hart is halted. A step request releases one instruction and then returns to
// halt-pending so later Debug Module integration has a clean hook.
module core_debug_ctrl (
  input  logic clk_i,             // Core/debug control clock.
  input  logic rst_ni,            // Active-low asynchronous reset.

  input  logic halt_req_i,        // Debug Module requests entry to Debug Mode.
  input  logic resume_req_i,      // Debug Module requests exit from Debug Mode.
  input  logic step_req_i,        // Debug Module requests one retired instruction.
  input  logic pipe_idle_i,       // Pipeline and LSU are fully drained.
  input  logic retire_valid_i,    // One architectural instruction retires this cycle.
  input  logic debug_busy_i,      // GPR debug response is pending or being accepted.

  output logic stop_fetch_o,      // Stop accepting new frontend instructions.
  output logic freeze_pipe_o,     // Hold the already-drained pipeline in Debug Mode.
  output logic halted_o,          // Hart is halted and accepts debug GPR traffic.
  output logic running_o          // Hart is executing or available to execute code.
);
  typedef enum logic [1:0] {
    DBG_RUNNING      = 2'b00, // Normal execution; frontend may flow.
    DBG_HALT_PENDING = 2'b01, // Fetch stopped, existing work is draining.
    DBG_HALTED       = 2'b10, // Debug Mode; pipeline is empty and frozen.
    DBG_STEP_RUNNING = 2'b11  // One-instruction single-step release.
  } debug_state_e;

  debug_state_e state_q; // Registered Debug Mode control state.
  debug_state_e state_d; // Next Debug Mode control state.

  // Next-state priority:
  // 1. halt request wins over resume/step;
  // 2. pending halt completes only after pipeline and debug response drain;
  // 3. halted resume waits until no GPR response is outstanding;
  // 4. single-step returns to halt-pending after one retirement.
  always_comb begin
    state_d = state_q;

    unique case (state_q)
      DBG_RUNNING: begin
        if (halt_req_i) begin
          state_d = (pipe_idle_i && !debug_busy_i) ? DBG_HALTED :
                                                   DBG_HALT_PENDING;
        end
      end

      DBG_HALT_PENDING: begin
        if (!halt_req_i && resume_req_i) begin
          state_d = DBG_RUNNING;
        end else if (pipe_idle_i && !debug_busy_i) begin
          state_d = DBG_HALTED;
        end
      end

      DBG_HALTED: begin
        if (halt_req_i) begin
          state_d = DBG_HALTED;
        end else if (step_req_i && !debug_busy_i) begin
          state_d = DBG_STEP_RUNNING;
        end else if (resume_req_i && !debug_busy_i) begin
          state_d = DBG_RUNNING;
        end
      end

      DBG_STEP_RUNNING: begin
        if (halt_req_i || retire_valid_i) begin
          state_d = pipe_idle_i ? DBG_HALTED : DBG_HALT_PENDING;
        end
      end

      default: begin
        state_d = DBG_RUNNING;
      end
    endcase
  end

  // Registered state update. Reset leaves the hart in normal running state so
  // system boot does not require debug handshakes.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= DBG_RUNNING;
    end else begin
      state_q <= state_d;
    end
  end

  // Fetch is stopped as soon as a halt request is visible, even before the FSM
  // samples it, so no extra instruction is accepted behind a debug halt.
  assign stop_fetch_o = halt_req_i || (state_q == DBG_HALT_PENDING) ||
                        (state_q == DBG_HALTED);
  assign freeze_pipe_o = (state_q == DBG_HALTED);
  assign halted_o = (state_q == DBG_HALTED);
  assign running_o = (state_q == DBG_RUNNING) ||
                     (state_q == DBG_STEP_RUNNING);
endmodule
