`timescale 1ns/1ps

// Core pipeline control skeleton.
//
// This module owns the first executable pipeline registers for the simple
// in-order core: an IF/ID slot and an EX/WB slot. It tracks the fetch PC,
// accepts instruction responses, applies load-use stalls/bubbles from
// core_hazard, and flushes younger work on redirects.
module core_pipe (
  input  logic        clk_i,             // Pipeline register clock.
  input  logic        rst_ni,            // Active-low asynchronous reset.

  input  logic [31:0] boot_pc_i,         // Reset fetch PC, normally OTP_BASE.

  output logic        if_req_valid_o,    // Fetch request valid for the frontend.
  output logic [31:0] if_req_pc_o,       // Fetch request PC.
  input  logic        if_rsp_valid_i,    // Frontend response valid.
  output logic        if_rsp_ready_o,    // Pipeline can accept the frontend response.
  input  logic [31:0] if_rsp_instr_i,    // Fetched 32-bit instruction word.
  input  logic        if_rsp_fault_i,    // Fetch fault associated with if_rsp_instr_i.

  input  logic        fetch_stall_i,     // Hold fetch request/response acceptance.
  input  logic        decode_stall_i,    // Hold IF/ID slot.
  input  logic        execute_bubble_i,  // Insert a bubble into EX/WB.

  input  logic        redirect_valid_i,  // Flush pipeline and redirect fetch PC.
  input  logic [31:0] redirect_pc_i,     // Redirect target PC.

  output logic        id_valid_o,        // IF/ID slot contains a valid instruction.
  output logic [31:0] id_pc_o,           // IF/ID instruction PC.
  output logic [31:0] id_instr_o,        // IF/ID instruction word.
  output logic        id_fetch_fault_o,  // IF/ID fetch fault flag.

  output logic        ex_valid_o,        // EX/WB slot contains a valid instruction.
  output logic [31:0] ex_pc_o,           // EX/WB instruction PC.
  output logic [31:0] ex_instr_o,        // EX/WB instruction word.
  output logic        ex_fetch_fault_o   // EX/WB fetch fault flag.
);
  logic [31:0] fetch_pc_q;       // PC used for the next fetch request.
  logic        id_valid_q;       // Stored IF/ID valid bit.
  logic [31:0] id_pc_q;          // Stored IF/ID PC.
  logic [31:0] id_instr_q;       // Stored IF/ID instruction.
  logic        id_fault_q;       // Stored IF/ID fetch fault.
  logic        ex_valid_q;       // Stored EX/WB valid bit.
  logic [31:0] ex_pc_q;          // Stored EX/WB PC.
  logic [31:0] ex_instr_q;       // Stored EX/WB instruction.
  logic        ex_fault_q;       // Stored EX/WB fetch fault.

  logic        fetch_accept;     // Fetch response can be consumed this cycle.
  logic        fetch_fire;       // Fetch response handshake completed.
  logic        advance_decode;   // IF/ID is allowed to advance into EX/WB.
  logic [31:0] next_fetch_pc;    // Sequential next PC after a normal fetch.

  assign if_req_valid_o = !fetch_stall_i;
  assign if_req_pc_o = fetch_pc_q;
  assign fetch_accept = !fetch_stall_i && !decode_stall_i && !redirect_valid_i;
  assign if_rsp_ready_o = fetch_accept;
  assign fetch_fire = if_rsp_valid_i && fetch_accept;
  assign advance_decode = !decode_stall_i;
  assign next_fetch_pc = fetch_pc_q + 32'd4;

  assign id_valid_o = id_valid_q;
  assign id_pc_o = id_pc_q;
  assign id_instr_o = id_instr_q;
  assign id_fetch_fault_o = id_fault_q;

  assign ex_valid_o = ex_valid_q;
  assign ex_pc_o = ex_pc_q;
  assign ex_instr_o = ex_instr_q;
  assign ex_fetch_fault_o = ex_fault_q;

  // Pipeline state update. Redirects have highest priority because they flush
  // younger instructions and overwrite the fetch PC. Load-use bubbles hold ID
  // through decode_stall_i while clearing EX/WB for one cycle.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      fetch_pc_q <= boot_pc_i;
      id_valid_q <= 1'b0;
      id_pc_q <= 32'h0000_0000;
      id_instr_q <= 32'h0000_0013;
      id_fault_q <= 1'b0;
      ex_valid_q <= 1'b0;
      ex_pc_q <= 32'h0000_0000;
      ex_instr_q <= 32'h0000_0013;
      ex_fault_q <= 1'b0;
    end else if (redirect_valid_i) begin
      fetch_pc_q <= redirect_pc_i;
      id_valid_q <= 1'b0;
      id_pc_q <= 32'h0000_0000;
      id_instr_q <= 32'h0000_0013;
      id_fault_q <= 1'b0;
      ex_valid_q <= 1'b0;
      ex_pc_q <= 32'h0000_0000;
      ex_instr_q <= 32'h0000_0013;
      ex_fault_q <= 1'b0;
    end else begin
      if (fetch_fire) begin
        fetch_pc_q <= next_fetch_pc;
      end

      if (execute_bubble_i) begin
        ex_valid_q <= 1'b0;
        ex_pc_q <= 32'h0000_0000;
        ex_instr_q <= 32'h0000_0013;
        ex_fault_q <= 1'b0;
      end else if (advance_decode) begin
        ex_valid_q <= id_valid_q;
        ex_pc_q <= id_pc_q;
        ex_instr_q <= id_instr_q;
        ex_fault_q <= id_fault_q;
      end

      if (fetch_fire) begin
        id_valid_q <= 1'b1;
        id_pc_q <= fetch_pc_q;
        id_instr_q <= if_rsp_instr_i;
        id_fault_q <= if_rsp_fault_i;
      end else if (advance_decode) begin
        id_valid_q <= 1'b0;
        id_pc_q <= 32'h0000_0000;
        id_instr_q <= 32'h0000_0013;
        id_fault_q <= 1'b0;
      end
    end
  end
endmodule
