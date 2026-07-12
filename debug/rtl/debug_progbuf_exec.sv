`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Sequential executor for the Debug Module Program Buffer instruction words.
//
// The controller sends at most one non-EBREAK instruction to the halted core
// at a time. It waits for the matching completion before selecting the next
// word and consumes an explicit EBREAK locally as successful termination.
module debug_progbuf_exec #(
  parameter int unsigned WORD_COUNT = debug_dmi_pkg::PROGBUF_WORD_COUNT,
  parameter int unsigned INDEX_WIDTH = (WORD_COUNT <= 1) ? 1 : $clog2(WORD_COUNT)
) (
  input  logic                              clk_i,             // Debug Module execution clock.
  input  logic                              rst_ni,            // Asynchronous active-low controller reset.
  input  logic                              dmactive_i,        // Debug Module active qualification.
  input  logic                              hart_halted_i,     // Hart remains in halted Debug Mode.
  input  logic                              start_i,           // One-cycle request to execute word zero.
  input  logic [WORD_COUNT-1:0][31:0]       words_i,           // Stable Program Buffer instruction image.
  output logic                              busy_o,            // Execution is checking, issuing, or completing.
  output logic                              done_o,            // One-cycle successful or failed completion pulse.
  output logic [2:0]                        error_o,           // Abstract-command error associated with done_o.
  output logic                              instr_valid_o,     // Current non-EBREAK instruction request is valid.
  input  logic                              instr_ready_i,     // Halted core accepts the instruction request.
  output logic [31:0]                       instr_o,           // Current RV32 instruction sent to the core.
  output logic [INDEX_WIDTH-1:0]            instr_index_o,     // Program Buffer index associated with instr_o.
  input  logic                              instr_rsp_valid_i, // Core completed the outstanding instruction.
  output logic                              instr_rsp_ready_o, // Controller accepts the completion response.
  input  logic                              instr_rsp_error_i  // Core reports illegal, memory, or execution fault.
);
  import debug_dmi_pkg::*;

  // CHECK consumes EBREAK locally; ISSUE and WAIT implement one outstanding
  // core instruction; COMPLETE presents one registered result cycle.
  typedef enum logic [2:0] {
    EXEC_IDLE,
    EXEC_CHECK,
    EXEC_ISSUE,
    EXEC_WAIT,
    EXEC_COMPLETE
  } exec_state_e;

  exec_state_e state_q;                  // Registered executor protocol state.
  exec_state_e state_d;                  // Combinational next protocol state.
  logic [INDEX_WIDTH-1:0] index_q;        // Current Program Buffer word index.
  logic [2:0] completion_error_q;         // Sticky result reported in COMPLETE.
  logic current_is_ebreak;                // Current word is the explicit terminator.
  logic current_is_last;                  // Current word is the final physical entry.
  logic instr_req_fire;                   // Core accepted the current instruction.
  logic instr_rsp_fire;                   // Controller accepted the core completion.

  assign current_is_ebreak = (words_i[index_q] == PROGBUF_EBREAK_INSN);
  assign current_is_last = (index_q == INDEX_WIDTH'(WORD_COUNT - 1));
  assign instr_req_fire = instr_valid_o && instr_ready_i;
  assign instr_rsp_fire = instr_rsp_valid_i && instr_rsp_ready_o;

  assign busy_o = (state_q != EXEC_IDLE);
  assign done_o = (state_q == EXEC_COMPLETE);
  assign error_o = completion_error_q;
  assign instr_valid_o = (state_q == EXEC_ISSUE) && dmactive_i && hart_halted_i;
  assign instr_o = words_i[index_q];
  assign instr_index_o = index_q;
  assign instr_rsp_ready_o = (state_q == EXEC_WAIT) && dmactive_i && hart_halted_i;

  // State transition priority is DM abort, halted-state loss, normal protocol
  // progress, then hold. Running off the last physical word is an exception
  // because this implementation advertises impebreak=0.
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      EXEC_IDLE: begin
        if (start_i && dmactive_i) begin
          state_d = hart_halted_i ? EXEC_CHECK : EXEC_COMPLETE;
        end
      end

      EXEC_CHECK: begin
        if (!dmactive_i) begin
          state_d = EXEC_IDLE;
        end else if (!hart_halted_i) begin
          state_d = EXEC_COMPLETE;
        end else if (current_is_ebreak) begin
          state_d = EXEC_COMPLETE;
        end else begin
          state_d = EXEC_ISSUE;
        end
      end

      EXEC_ISSUE: begin
        if (!dmactive_i) begin
          state_d = EXEC_IDLE;
        end else if (!hart_halted_i) begin
          state_d = EXEC_COMPLETE;
        end else if (instr_req_fire) begin
          state_d = EXEC_WAIT;
        end
      end

      EXEC_WAIT: begin
        if (!dmactive_i) begin
          state_d = EXEC_IDLE;
        end else if (!hart_halted_i) begin
          state_d = EXEC_COMPLETE;
        end else if (instr_rsp_fire) begin
          if (instr_rsp_error_i || current_is_last) begin
            state_d = EXEC_COMPLETE;
          end else begin
            state_d = EXEC_CHECK;
          end
        end
      end

      EXEC_COMPLETE: state_d = EXEC_IDLE;

      default: state_d = EXEC_IDLE;
    endcase
  end

  // Registered state, index, and completion result. DM deactivation silently
  // aborts and scrubs progress. Hart loss reports HALT_RESUME; core faults and
  // a missing explicit EBREAK report EXCEPTION.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= EXEC_IDLE;
      index_q <= '0;
      completion_error_q <= CMDERR_NONE;
    end else begin
      state_q <= state_d;

      if (!dmactive_i) begin
        index_q <= '0;
        completion_error_q <= CMDERR_NONE;
      end else if ((state_q == EXEC_IDLE) && start_i) begin
        index_q <= '0;
        completion_error_q <= hart_halted_i ? CMDERR_NONE : CMDERR_HALT_RESUME;
      end else if (((state_q == EXEC_CHECK) ||
                    (state_q == EXEC_ISSUE) ||
                    (state_q == EXEC_WAIT)) && !hart_halted_i) begin
        completion_error_q <= CMDERR_HALT_RESUME;
      end else if ((state_q == EXEC_WAIT) && instr_rsp_fire) begin
        if (instr_rsp_error_i || current_is_last) begin
          completion_error_q <= CMDERR_EXCEPTION;
        end else begin
          index_q <= index_q + 1'b1;
        end
      end
    end
  end
endmodule
