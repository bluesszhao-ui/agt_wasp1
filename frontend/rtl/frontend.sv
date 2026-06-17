`timescale 1ns/1ps

// frontend integrates the verified PC, fetch, and instruction-buffer leaves.
//
// This top-level frontend boundary owns instruction address generation,
// instruction-memory request/response control, redirect flushing, and the
// buffered instruction response presented to the later core/tile integration.
module frontend #(
  parameter int IBUF_DEPTH = 2
) (
  input  logic        clk_i,              // Frontend clock for all child sequential state.
  input  logic        rst_ni,             // Active-low asynchronous frontend reset.

  input  logic [31:0] boot_pc_i,          // Reset PC, normally OTP_BASE.
  input  logic        stall_i,            // Holds new PC request generation when high.
  input  logic        redirect_valid_i,   // Redirect request from branch/trap/debug control.
  input  logic [31:0] redirect_pc_i,      // Redirect target captured by frontend_pc.

  output logic        instr_valid_o,      // Buffered instruction valid to the core side.
  input  logic        instr_ready_i,      // Core side accepted the buffered instruction.
  output logic [31:0] instr_pc_o,         // Buffered instruction PC.
  output logic [31:0] instr_o,            // Buffered instruction word.
  output logic        instr_fault_o,      // Buffered fetch fault flag.
  output logic        instr_misaligned_o, // Buffered misaligned-PC fault flag.

  mem_req_rsp_if.initiator imem_if        // Instruction cache/memory request interface.
);
  logic        pc_valid;          // Current PC request valid from frontend_pc.
  logic        pc_ready;          // Fetch block accepted the current PC.
  logic [31:0] pc;                // Current PC request address.
  logic        pc_misaligned;     // Current PC is not word aligned.

  logic        fetch_valid;       // Fetch response valid before ibuf.
  logic        fetch_ready;       // Ibuf can accept fetch response.
  logic [31:0] fetch_pc;          // Fetch response PC before ibuf.
  logic [31:0] fetch_instr;       // Fetch response instruction before ibuf.
  logic        fetch_fault;       // Fetch response fault before ibuf.
  logic        fetch_misaligned;  // Fetch response misaligned flag before ibuf.
  logic        ibuf_empty;        // Ibuf empty status, retained for debug visibility.
  logic        ibuf_full;         // Ibuf full status, retained for debug visibility.

  frontend_pc pc_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .boot_pc_i(boot_pc_i),
    .stall_i(stall_i),
    .fetch_ready_i(pc_ready),
    .redirect_valid_i(redirect_valid_i),
    .redirect_pc_i(redirect_pc_i),
    .pc_valid_o(pc_valid),
    .pc_o(pc),
    .pc_misaligned_o(pc_misaligned)
  );

  frontend_fetch fetch_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .pc_valid_i(pc_valid),
    .pc_ready_o(pc_ready),
    .pc_i(pc),
    .pc_misaligned_i(pc_misaligned),
    .flush_i(redirect_valid_i),
    .instr_valid_o(fetch_valid),
    .instr_ready_i(fetch_ready),
    .instr_pc_o(fetch_pc),
    .instr_o(fetch_instr),
    .instr_fault_o(fetch_fault),
    .instr_misaligned_o(fetch_misaligned),
    .imem_if(imem_if)
  );

  frontend_ibuf #(
    .DEPTH(IBUF_DEPTH)
  ) ibuf_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(redirect_valid_i),
    .push_valid_i(fetch_valid),
    .push_ready_o(fetch_ready),
    .push_pc_i(fetch_pc),
    .push_instr_i(fetch_instr),
    .push_fault_i(fetch_fault),
    .push_misaligned_i(fetch_misaligned),
    .pop_valid_o(instr_valid_o),
    .pop_ready_i(instr_ready_i),
    .pop_pc_o(instr_pc_o),
    .pop_instr_o(instr_o),
    .pop_fault_o(instr_fault_o),
    .pop_misaligned_o(instr_misaligned_o),
    .empty_o(ibuf_empty),
    .full_o(ibuf_full)
  );
endmodule
