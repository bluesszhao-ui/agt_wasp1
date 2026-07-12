`timescale 1ns/1ps

// Core pipeline control skeleton.
//
// This module owns the first executable pipeline registers for the simple
// in-order core: an IF/ID slot and an EX/WB slot. The frontend owns fetch PC
// generation, so core_pipe consumes an instruction stream that already carries
// its PC, applies load-use stalls/bubbles from core_hazard, and flushes younger
// work on redirects.
module core_pipe (
  input  logic        clk_i,             // Pipeline register clock.
  input  logic        rst_ni,            // Active-low asynchronous reset.

  input  logic        instr_valid_i,     // Frontend instruction stream valid.
  output logic        instr_ready_o,     // Pipeline can accept the instruction stream.
  input  logic [31:0] instr_pc_i,        // PC associated with instr_i.
  input  logic [31:0] instr_i,           // Fetched 32-bit instruction word.
  input  logic        instr_fault_i,     // Fetch fault associated with instr_i.

  input  logic        debug_inject_valid_i, // Halted-core instruction injection request.
  output logic        debug_inject_ready_o, // Empty pipeline can accept the debug instruction.
  input  logic [31:0] debug_inject_pc_i,    // Synthetic Program Buffer PC.
  input  logic [31:0] debug_inject_instr_i, // Injected RV32 instruction word.

  input  logic        fetch_stall_i,     // Hold frontend instruction stream acceptance.
  input  logic        decode_stall_i,    // Hold IF/ID slot.
  input  logic        execute_bubble_i,  // Insert a bubble into EX/WB.

  input  logic        redirect_valid_i,  // Flush pipeline and request frontend redirect.
  input  logic [31:0] redirect_pc_i,     // Redirect target PC.
  output logic        redirect_valid_o,  // Redirect request forwarded to frontend.
  output logic [31:0] redirect_pc_o,     // Redirect target forwarded to frontend.

  output logic        id_valid_o,        // IF/ID slot contains a valid instruction.
  output logic [31:0] id_pc_o,           // IF/ID instruction PC.
  output logic [31:0] id_instr_o,        // IF/ID instruction word.
  output logic        id_fetch_fault_o,  // IF/ID fetch fault flag.
  output logic        id_debug_o,        // IF/ID word came from debug injection.

  output logic        ex_valid_o,        // EX/WB slot contains a valid instruction.
  output logic [31:0] ex_pc_o,           // EX/WB instruction PC.
  output logic [31:0] ex_instr_o,        // EX/WB instruction word.
  output logic        ex_fetch_fault_o,  // EX/WB fetch fault flag.
  output logic        ex_debug_o         // EX/WB word came from debug injection.
);
  logic        id_valid_q;       // Stored IF/ID valid bit.
  logic [31:0] id_pc_q;          // Stored IF/ID PC.
  logic [31:0] id_instr_q;       // Stored IF/ID instruction.
  logic        id_fault_q;       // Stored IF/ID fetch fault.
  logic        id_debug_q;       // Stored IF/ID debug source tag.
  logic        ex_valid_q;       // Stored EX/WB valid bit.
  logic [31:0] ex_pc_q;          // Stored EX/WB PC.
  logic [31:0] ex_instr_q;       // Stored EX/WB instruction.
  logic        ex_fault_q;       // Stored EX/WB fetch fault.
  logic        ex_debug_q;       // Stored EX/WB debug source tag.

  logic        instr_accept;     // Instruction stream can be consumed this cycle.
  logic        instr_fire;       // Instruction stream handshake completed.
  logic        debug_inject_fire;// Debug injection handshake completed.
  logic        advance_decode;   // IF/ID is allowed to advance into EX/WB.

  assign instr_accept = !fetch_stall_i && !decode_stall_i &&
                        !redirect_valid_i && !debug_inject_valid_i;
  assign instr_ready_o = instr_accept;
  assign instr_fire = instr_valid_i && instr_accept;
  assign debug_inject_ready_o = !id_valid_q && !ex_valid_q && !redirect_valid_i;
  assign debug_inject_fire = debug_inject_valid_i && debug_inject_ready_o;
  assign advance_decode = !decode_stall_i;
  assign redirect_valid_o = redirect_valid_i;
  assign redirect_pc_o = redirect_pc_i;

  assign id_valid_o = id_valid_q;
  assign id_pc_o = id_pc_q;
  assign id_instr_o = id_instr_q;
  assign id_fetch_fault_o = id_fault_q;
  assign id_debug_o = id_debug_q;

  assign ex_valid_o = ex_valid_q;
  assign ex_pc_o = ex_pc_q;
  assign ex_instr_o = ex_instr_q;
  assign ex_fetch_fault_o = ex_fault_q;
  assign ex_debug_o = ex_debug_q;

  // Pipeline state update. Redirects have highest priority because they flush
  // younger instructions and forward a target PC to the frontend. Load-use
  // bubbles hold ID through decode_stall_i while clearing EX/WB for one cycle.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      id_valid_q <= 1'b0;
      id_pc_q <= 32'h0000_0000;
      id_instr_q <= 32'h0000_0013;
      id_fault_q <= 1'b0;
      id_debug_q <= 1'b0;
      ex_valid_q <= 1'b0;
      ex_pc_q <= 32'h0000_0000;
      ex_instr_q <= 32'h0000_0013;
      ex_fault_q <= 1'b0;
      ex_debug_q <= 1'b0;
    end else if (redirect_valid_i) begin
      id_valid_q <= 1'b0;
      id_pc_q <= 32'h0000_0000;
      id_instr_q <= 32'h0000_0013;
      id_fault_q <= 1'b0;
      id_debug_q <= 1'b0;
      ex_valid_q <= 1'b0;
      ex_pc_q <= 32'h0000_0000;
      ex_instr_q <= 32'h0000_0013;
      ex_fault_q <= 1'b0;
      ex_debug_q <= 1'b0;
    end else if (debug_inject_fire) begin
      // Debug injection owns an empty pipeline even while normal stalls hold
      // the halted core. The source tag follows the word through EX/WB.
      id_valid_q <= 1'b1;
      id_pc_q <= debug_inject_pc_i;
      id_instr_q <= debug_inject_instr_i;
      id_fault_q <= 1'b0;
      id_debug_q <= 1'b1;
      ex_valid_q <= 1'b0;
      ex_pc_q <= 32'h0000_0000;
      ex_instr_q <= 32'h0000_0013;
      ex_fault_q <= 1'b0;
      ex_debug_q <= 1'b0;
    end else begin
      if (execute_bubble_i) begin
        ex_valid_q <= 1'b0;
        ex_pc_q <= 32'h0000_0000;
        ex_instr_q <= 32'h0000_0013;
        ex_fault_q <= 1'b0;
        ex_debug_q <= 1'b0;
      end else if (advance_decode) begin
        ex_valid_q <= id_valid_q;
        ex_pc_q <= id_pc_q;
        ex_instr_q <= id_instr_q;
        ex_fault_q <= id_fault_q;
        ex_debug_q <= id_debug_q;
      end

      if (instr_fire) begin
        id_valid_q <= 1'b1;
        id_pc_q <= instr_pc_i;
        id_instr_q <= instr_i;
        id_fault_q <= instr_fault_i;
        id_debug_q <= 1'b0;
      end else if (advance_decode) begin
        id_valid_q <= 1'b0;
        id_pc_q <= 32'h0000_0000;
        id_instr_q <= 32'h0000_0013;
        id_fault_q <= 1'b0;
        id_debug_q <= 1'b0;
      end
    end
  end
endmodule
