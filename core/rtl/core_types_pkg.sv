`timescale 1ns/1ps

package core_types_pkg;
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
endpackage
