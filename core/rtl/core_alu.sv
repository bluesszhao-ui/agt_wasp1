`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module core_alu (
  input  core_types_pkg::core_alu_op_e op_i,
  input  logic [31:0]                  lhs_i,
  input  logic [31:0]                  rhs_i,
  output logic [31:0]                  result_o
);
  import core_types_pkg::*;

  logic [4:0] shamt;

  assign shamt = rhs_i[4:0];

  always_comb begin
    unique case (op_i)
      CORE_ALU_ADD:  result_o = lhs_i + rhs_i;
      CORE_ALU_SUB:  result_o = lhs_i - rhs_i;
      CORE_ALU_SLL:  result_o = lhs_i << shamt;
      CORE_ALU_SLT:  result_o = ($signed(lhs_i) < $signed(rhs_i)) ? 32'd1 : 32'd0;
      CORE_ALU_SLTU: result_o = (lhs_i < rhs_i) ? 32'd1 : 32'd0;
      CORE_ALU_XOR:  result_o = lhs_i ^ rhs_i;
      CORE_ALU_SRL:  result_o = lhs_i >> shamt;
      CORE_ALU_SRA:  result_o = 32'($signed(lhs_i) >>> shamt);
      CORE_ALU_OR:   result_o = lhs_i | rhs_i;
      CORE_ALU_AND:  result_o = lhs_i & rhs_i;
      default:       result_o = '0;
    endcase
  end
endmodule
