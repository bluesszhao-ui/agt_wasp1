`timescale 1ns/1ps

// Self-checking testbench for core_alu.
//
// The bench combines directed edge cases with deterministic random checks and
// compares every result against a local reference model.
module tb_core_alu;
  import core_types_pkg::*;

  core_alu_op_e op;       // Operation driven into DUT.
  logic [31:0] lhs;       // Left operand driven into DUT.
  logic [31:0] rhs;       // Right operand driven into DUT.
  logic [31:0] result;    // DUT result observed by checks.

  int unsigned pass_count;   // Number of successful checks.
  int unsigned op_count [10];// Per-operation coverage counters.
  int unsigned edge_count;   // Directed edge-case coverage counter.
  int unsigned signed_count; // Signed compare/shift coverage counter.
  int unsigned random_count; // Deterministic random check counter.

  core_alu u_core_alu (
    .op_i(op),
    .lhs_i(lhs),
    .rhs_i(rhs),
    .result_o(result)
  );

  // Golden ALU model used by all directed and random checks.
  function automatic logic [31:0] ref_alu(
    input core_alu_op_e ref_op,
    input logic [31:0] ref_lhs,
    input logic [31:0] ref_rhs
  );
    logic [4:0] shamt;
    begin
      shamt = ref_rhs[4:0];
      unique case (ref_op)
        CORE_ALU_ADD:  ref_alu = ref_lhs + ref_rhs;
        CORE_ALU_SUB:  ref_alu = ref_lhs - ref_rhs;
        CORE_ALU_SLL:  ref_alu = ref_lhs << shamt;
        CORE_ALU_SLT:  ref_alu = ($signed(ref_lhs) < $signed(ref_rhs)) ? 32'd1 : 32'd0;
        CORE_ALU_SLTU: ref_alu = (ref_lhs < ref_rhs) ? 32'd1 : 32'd0;
        CORE_ALU_XOR:  ref_alu = ref_lhs ^ ref_rhs;
        CORE_ALU_SRL:  ref_alu = ref_lhs >> shamt;
        CORE_ALU_SRA:  ref_alu = 32'($signed(ref_lhs) >>> shamt);
        CORE_ALU_OR:   ref_alu = ref_lhs | ref_rhs;
        CORE_ALU_AND:  ref_alu = ref_lhs & ref_rhs;
        default:       ref_alu = '0;
      endcase
    end
  endfunction

  // Drive one transaction, wait for combinational settle, and compare result.
  task automatic check(
    input core_alu_op_e check_op,
    input logic [31:0] check_lhs,
    input logic [31:0] check_rhs,
    input string label
  );
    logic [31:0] expected;
    begin
      op = check_op;
      lhs = check_lhs;
      rhs = check_rhs;
      #1ns;
      expected = ref_alu(check_op, check_lhs, check_rhs);
      if (result !== expected) begin
        $error("%s: op=%0d lhs=0x%08h rhs=0x%08h expected=0x%08h got=0x%08h",
               label, check_op, check_lhs, check_rhs, expected, result);
        $fatal(1);
      end
      op_count[int'(check_op)]++;
      pass_count++;
    end
  endtask

  // Directed vectors cover wrapping arithmetic, shift masking, signedness, and
  // representative logic patterns.
  task automatic check_directed;
    begin
      check(CORE_ALU_ADD, 32'h0000_0001, 32'h0000_0002, "add small");
      check(CORE_ALU_ADD, 32'hFFFF_FFFF, 32'h0000_0001, "add wrap");
      check(CORE_ALU_SUB, 32'h0000_0000, 32'h0000_0001, "sub wrap");
      check(CORE_ALU_SUB, 32'h8000_0000, 32'h0000_0001, "sub edge");
      check(CORE_ALU_SLL, 32'h0000_0001, 32'h0000_001F, "sll 31");
      check(CORE_ALU_SLL, 32'h0000_0001, 32'hFFFF_FFFF, "sll masked");
      check(CORE_ALU_SLT, 32'h8000_0000, 32'h0000_0001, "slt signed neg");
      check(CORE_ALU_SLT, 32'h7FFF_FFFF, 32'h8000_0000, "slt signed pos");
      check(CORE_ALU_SLTU, 32'h8000_0000, 32'h0000_0001, "sltu unsigned");
      check(CORE_ALU_SLTU, 32'h0000_0001, 32'h8000_0000, "sltu low");
      check(CORE_ALU_XOR, 32'hAAAA_5555, 32'hFFFF_0000, "xor pattern");
      check(CORE_ALU_SRL, 32'h8000_0000, 32'h0000_001F, "srl sign clear");
      check(CORE_ALU_SRA, 32'h8000_0000, 32'h0000_001F, "sra sign fill");
      check(CORE_ALU_SRA, 32'h7FFF_FFFF, 32'h0000_0004, "sra positive");
      check(CORE_ALU_OR, 32'h1234_0000, 32'h0000_5678, "or pattern");
      check(CORE_ALU_AND, 32'hFFFF_00FF, 32'h0F0F_0F0F, "and pattern");
      edge_count += 16;
      signed_count += 4;
    end
  endtask

  task automatic check_random(input int unsigned count);
    core_alu_op_e rand_op;
    logic [31:0] rand_lhs;
    logic [31:0] rand_rhs;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        rand_op = core_alu_op_e'($urandom_range(0, 9));
        rand_lhs = $urandom();
        rand_rhs = $urandom();
        check(rand_op, rand_lhs, rand_rhs, "random");
        random_count++;
      end
    end
  endtask

  task automatic check_invalid_default;
    begin
      op = core_alu_op_e'(4'hF);
      lhs = 32'hFFFF_FFFF;
      rhs = 32'h1234_5678;
      #1ns;
      if (result !== 32'h0000_0000) begin
        $error("invalid op expected zero got 0x%08h", result);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic check_coverage_summary;
    begin
      for (int idx = 0; idx < 10; idx++) begin
        if (op_count[idx] == 0) begin
          $error("coverage miss: op %0d not hit", idx);
          $fatal(1);
        end
      end
      if (edge_count < 16 || signed_count < 4 || random_count < 200) begin
        $error("coverage miss: edge=%0d signed=%0d random=%0d",
               edge_count, signed_count, random_count);
        $fatal(1);
      end
      $display("tb_core_alu coverage: pass_count=%0d edge_count=%0d signed_count=%0d random_count=%0d",
               pass_count, edge_count, signed_count, random_count);
      for (int idx = 0; idx < 10; idx++) begin
        $display("tb_core_alu coverage: op[%0d] hits=%0d", idx, op_count[idx]);
      end
    end
  endtask

  initial begin
    void'($urandom(32'hC0A1_0001));
    pass_count = 0;
    edge_count = 0;
    signed_count = 0;
    random_count = 0;
    for (int idx = 0; idx < 10; idx++) begin
      op_count[idx] = 0;
    end

    check_directed();
    check_random(200);
    check_invalid_default();
    check_coverage_summary();

    $display("tb_core_alu PASS");
    $finish;
  end
endmodule
