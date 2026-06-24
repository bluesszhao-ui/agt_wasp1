`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Single-hart halt/resume controller between Debug Module registers and core.
module debug_halt_ctrl (
  input  logic clk_i,                // Debug/core control clock for all sequential state.
  input  logic rst_ni,               // Asynchronous active-low controller reset.
  input  logic dmactive_i,           // Debug Module activation gate from dmcontrol.
  input  logic haltreq_i,            // Level request to halt the selected hart.
  input  logic resumereq_i,          // Resume transaction request for the selected hart.
  input  logic ackhavereset_i,       // One-cycle request to clear the sticky reset report.
  input  logic hart_reset_event_i,   // Synchronous indication that the hart has reset.
  input  logic core_halted_i,        // Core reports that it is halted in Debug Mode.
  input  logic core_running_i,       // Core reports normal instruction execution.
  output logic core_halt_req_o,      // Level request held until halt or cancellation.
  output logic core_resume_req_o,    // Level request held until the core reports running.
  output logic hart_halted_o,        // Direct selected-hart halted status for dmstatus.
  output logic hart_running_o,       // Direct selected-hart running status for dmstatus.
  output logic hart_resumeack_o,     // Sticky acknowledgement of the completed resume transaction.
  output logic hart_havereset_o      // Sticky reset observation cleared by ackhavereset.
);
  // The FSM tracks only an outstanding control transaction. Architectural
  // running/halted status remains owned by the core and is never inferred.
  typedef enum logic [1:0] {
    HALT_CTRL_IDLE,
    HALT_CTRL_HALT_WAIT,
    HALT_CTRL_RESUME_WAIT
  } halt_ctrl_state_e;

  halt_ctrl_state_e state_q;
  halt_ctrl_state_e state_d;

  // Sticky status registers allow DMI polling to observe short core events.
  logic resumeack_q;
  logic havereset_q;

  // Core status is passed directly to dmstatus. The register block applies
  // dmactive and hart-selection visibility rules at the architectural boundary.
  assign hart_halted_o = core_halted_i;
  assign hart_running_o = core_running_i;
  assign hart_resumeack_o = resumeack_q;
  assign hart_havereset_o = havereset_q;

  // Requests are asserted only in their corresponding wait state. A DM reset
  // or deactivation suppresses both outputs immediately.
  always_comb begin
    core_halt_req_o = 1'b0;
    core_resume_req_o = 1'b0;
    if (dmactive_i) begin
      core_halt_req_o = (state_q == HALT_CTRL_HALT_WAIT);
      core_resume_req_o = (state_q == HALT_CTRL_RESUME_WAIT);
    end
  end

  // Transaction-state next-state logic. Halt wins over resume whenever both
  // requests are visible. Once resume starts, deasserting resumereq does not
  // cancel it because the register block may retire the request on early ack.
  always_comb begin
    state_d = state_q;
    if (!dmactive_i) begin
      state_d = HALT_CTRL_IDLE;
    end else begin
      unique case (state_q)
        HALT_CTRL_IDLE: begin
          if (haltreq_i) begin
            if (!core_halted_i) state_d = HALT_CTRL_HALT_WAIT;
          end else if (resumereq_i && !core_running_i) begin
            state_d = HALT_CTRL_RESUME_WAIT;
          end
        end

        HALT_CTRL_HALT_WAIT: begin
          if (!haltreq_i || core_halted_i) state_d = HALT_CTRL_IDLE;
        end

        HALT_CTRL_RESUME_WAIT: begin
          if (haltreq_i) begin
            state_d = core_halted_i ? HALT_CTRL_IDLE : HALT_CTRL_HALT_WAIT;
          end else if (core_running_i) begin
            state_d = HALT_CTRL_IDLE;
          end
        end

        default: state_d = HALT_CTRL_IDLE;
      endcase
    end
  end

  // State and sticky status update priority:
  // reset > hart reset event > DM inactive > request/completion > hold.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= HALT_CTRL_IDLE;
      resumeack_q <= 1'b0;
      havereset_q <= 1'b1;
    end else if (hart_reset_event_i) begin
      state_q <= HALT_CTRL_IDLE;
      resumeack_q <= 1'b0;
      havereset_q <= 1'b1;
    end else begin
      state_q <= state_d;

      // A reset indication remains visible until the active DM acknowledges it.
      if (dmactive_i && ackhavereset_i) havereset_q <= 1'b0;

      if (!dmactive_i) begin
        resumeack_q <= 1'b0;
      end else begin
        // A new resume transaction clears the previous sticky acknowledgement.
        if ((state_q != HALT_CTRL_RESUME_WAIT) && resumereq_i) begin
          resumeack_q <= 1'b0;
        end

        // Completion is recognized both for a waiting hart and for an already
        // running hart. Halt priority prevents a simultaneous false resume ack.
        if (!haltreq_i && resumereq_i && core_running_i) begin
          resumeack_q <= 1'b1;
        end else if ((state_q == HALT_CTRL_RESUME_WAIT) && !haltreq_i &&
                     core_running_i) begin
          resumeack_q <= 1'b1;
        end
      end
    end
  end
endmodule
