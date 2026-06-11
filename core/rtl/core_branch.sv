`timescale 1ns/1ps

module core_branch (
  input  logic [31:0]                    pc_i,
  input  logic [31:0]                    rs1_i,
  input  logic [31:0]                    rs2_i,
  input  logic [31:0]                    imm_i,

  input  logic                           branch_i,
  input  core_types_pkg::core_branch_e   branch_op_i,
  input  logic                           jal_i,
  input  logic                           jalr_i,

  output logic                           taken_o,
  output logic [31:0]                    target_o,
  output logic [31:0]                    link_o
);
  import core_types_pkg::*;

  logic branch_taken;
  logic [31:0] pc_plus_imm;
  logic [31:0] rs1_plus_imm;

  assign pc_plus_imm = pc_i + imm_i;
  assign rs1_plus_imm = rs1_i + imm_i;
  assign link_o = pc_i + 32'd4;

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
