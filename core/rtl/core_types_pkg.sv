`timescale 1ns/1ps

// Shared core-local type definitions.
//
// These enums are intentionally kept in one package so decode, execute helpers,
// CSR logic, and later pipeline integration use the same compact encodings.
package core_types_pkg;
  // ALU operation selector for RV32I integer arithmetic, logic, shifts, and
  // comparisons. Values are not software visible.
  typedef enum logic [3:0] {
    CORE_ALU_ADD  = 4'd0,
    CORE_ALU_SUB  = 4'd1,
    CORE_ALU_SLL  = 4'd2,
    CORE_ALU_SLT  = 4'd3,
    CORE_ALU_SLTU = 4'd4,
    CORE_ALU_XOR  = 4'd5,
    CORE_ALU_SRL  = 4'd6,
    CORE_ALU_SRA  = 4'd7,
    CORE_ALU_OR   = 4'd8,
    CORE_ALU_AND  = 4'd9
  } core_alu_op_e;

  // Immediate format selected by decode. CORE_IMM_CSR carries the zero-extended
  // zimm field used by immediate CSR instructions.
  typedef enum logic [2:0] {
    CORE_IMM_NONE = 3'd0,
    CORE_IMM_I    = 3'd1,
    CORE_IMM_S    = 3'd2,
    CORE_IMM_B    = 3'd3,
    CORE_IMM_U    = 3'd4,
    CORE_IMM_J    = 3'd5,
    CORE_IMM_CSR  = 3'd6
  } core_imm_sel_e;

  // Branch comparison selector for the branch helper.
  typedef enum logic [2:0] {
    CORE_BRANCH_NONE = 3'd0,
    CORE_BRANCH_BEQ  = 3'd1,
    CORE_BRANCH_BNE  = 3'd2,
    CORE_BRANCH_BLT  = 3'd3,
    CORE_BRANCH_BGE  = 3'd4,
    CORE_BRANCH_BLTU = 3'd5,
    CORE_BRANCH_BGEU = 3'd6
  } core_branch_e;

  // CSR command selector matching the six Zicsr operations.
  typedef enum logic [2:0] {
    CORE_CSR_NONE = 3'd0,
    CORE_CSR_RW   = 3'd1,
    CORE_CSR_RS   = 3'd2,
    CORE_CSR_RC   = 3'd3,
    CORE_CSR_RWI  = 3'd4,
    CORE_CSR_RSI  = 3'd5,
    CORE_CSR_RCI  = 3'd6
  } core_csr_cmd_e;

  // Load/store access size used by decode and the LSU helper.
  typedef enum logic [1:0] {
    CORE_LSU_BYTE = 2'd0,
    CORE_LSU_HALF = 2'd1,
    CORE_LSU_WORD = 2'd2
  } core_lsu_size_e;

  // Register writeback source selector used by the execute/writeback pipeline
  // boundary. Loads, CSR instructions, jumps, and LUI choose non-ALU sources.
  typedef enum logic [2:0] {
    CORE_WB_ALU  = 3'd0,
    CORE_WB_LOAD = 3'd1,
    CORE_WB_CSR  = 3'd2,
    CORE_WB_PC4  = 3'd3,
    CORE_WB_IMM  = 3'd4
  } core_wb_sel_e;
endpackage
