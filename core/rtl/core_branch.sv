`timescale 1ns/1ps

// Branch and jump target helper.
//
// This combinational module compares branch operands, computes PC-relative and
// register-relative targets, and emits the link address used by JAL/JALR.
module core_branch (
  input  logic [31:0]                    pc_i,        // Current instruction PC.
  input  logic [31:0]                    rs1_i,       // First branch operand or JALR base.
  input  logic [31:0]                    rs2_i,       // Second branch operand.
  input  logic [31:0]                    imm_i,       // Sign-extended branch/jump immediate.

  input  logic                           branch_i,    // Branch instruction qualifier.
  input  core_types_pkg::core_branch_e   branch_op_i, // Specific branch comparison operation.
  input  logic                           jal_i,       // JAL qualifier; highest control-flow priority.
  input  logic                           jalr_i,      // JALR qualifier; clears target bit 0.

  output logic                           taken_o,     // Redirect request for branch/jump.
  output logic [31:0]                    target_o,    // Redirect target or fall-through PC.
  output logic [31:0]                    link_o       // Return link value, always pc_i + 4.
);
  import core_types_pkg::*;

  logic branch_taken;       // Raw branch comparator result before branch_i gating.
  logic [31:0] pc_plus_imm; // PC-relative target for branches and JAL.
  logic [31:0] rs1_plus_imm;// Register-relative target base for JALR.

  assign pc_plus_imm = pc_i + imm_i;
  assign rs1_plus_imm = rs1_i + imm_i;
  assign link_o = pc_i + 32'd4;

  // Evaluate each RV32I branch condition. Signed branches explicitly cast both
  // operands so high-bit cases do not accidentally use unsigned comparison.
  always_comb begin
    unique case (branch_op_i)
      CORE_BRANCH_BEQ:  branch_taken = (rs1_i == rs2_i);
      CORE_BRANCH_BNE:  branch_taken = (rs1_i != rs2_i);
      CORE_BRANCH_BLT:  branch_taken = ($signed(rs1_i) < $signed(rs2_i));
      CORE_BRANCH_BGE:  branch_taken = ($signed(rs1_i) >= $signed(rs2_i));
      CORE_BRANCH_BLTU: branch_taken = (rs1_i < rs2_i);
      CORE_BRANCH_BGEU: branch_taken = (rs1_i >= rs2_i);
      default:          branch_taken = 1'b0;
    endcase
  end

  // Resolve control-flow priority. JAL has priority over JALR and branches only
  // to keep behavior deterministic if decode ever asserts multiple class bits.
  always_comb begin
    taken_o = 1'b0;
    target_o = link_o;

    if (jal_i) begin
      taken_o = 1'b1;
      target_o = pc_plus_imm;
    end else if (jalr_i) begin
      taken_o = 1'b1;
      target_o = {rs1_plus_imm[31:1], 1'b0};
    end else if (branch_i && branch_taken) begin
      taken_o = 1'b1;
      target_o = pc_plus_imm;
    end
  end
endmodule
