`timescale 1ns/1ps

// Self-checking testbench for core_branch.
//
// Directed branch pairs cover taken/not-taken cases for all comparisons. Jump
// and priority checks cover JAL/JALR target behavior, and random branches are
// compared against a local reference comparator.
module tb_core_branch;
  import core_types_pkg::*;

  logic [31:0] pc;       // PC stimulus.
  logic [31:0] rs1;      // First operand/JALR base stimulus.
  logic [31:0] rs2;      // Second operand stimulus.
  logic [31:0] imm;      // Branch/jump immediate stimulus.
  logic branch;          // Branch qualifier stimulus.
  core_branch_e branch_op;// Branch operation stimulus.
  logic jal;             // JAL qualifier stimulus.
  logic jalr;            // JALR qualifier stimulus.
  logic taken;           // DUT redirect/taken output.
  logic [31:0] target;   // DUT target output.
  logic [31:0] link;     // DUT link output.

  int unsigned pass_count;             // Number of successful checks.
  int unsigned branch_taken_count;     // Directed taken branch coverage.
  int unsigned branch_not_taken_count; // Directed not-taken branch coverage.
  int unsigned signed_count;           // Signed comparison edge coverage.
  int unsigned unsigned_count;         // Unsigned comparison edge coverage.
  int unsigned jump_count;             // JAL/JALR coverage counter.
  int unsigned priority_count;         // Multi-control priority coverage.
  int unsigned random_count;           // Deterministic random coverage.

  core_branch u_core_branch (
    .pc_i(pc),
    .rs1_i(rs1),
    .rs2_i(rs2),
    .imm_i(imm),
    .branch_i(branch),
    .branch_op_i(branch_op),
    .jal_i(jal),
    .jalr_i(jalr),
    .taken_o(taken),
    .target_o(target),
    .link_o(link)
  );

  // Golden branch comparator used by random checks.
  function automatic logic ref_branch_taken(
    input core_branch_e op,
    input logic [31:0] lhs,
    input logic [31:0] rhs
  );
    begin
      unique case (op)
        CORE_BRANCH_BEQ:  ref_branch_taken = (lhs == rhs);
        CORE_BRANCH_BNE:  ref_branch_taken = (lhs != rhs);
        CORE_BRANCH_BLT:  ref_branch_taken = ($signed(lhs) < $signed(rhs));
        CORE_BRANCH_BGE:  ref_branch_taken = ($signed(lhs) >= $signed(rhs));
        CORE_BRANCH_BLTU: ref_branch_taken = (lhs < rhs);
        CORE_BRANCH_BGEU: ref_branch_taken = (lhs >= rhs);
        default:          ref_branch_taken = 1'b0;
      endcase
    end
  endfunction

  // Drive one branch/jump case and check taken, target, and link outputs.
  task automatic check_case(
    input logic [31:0] check_pc,
    input logic [31:0] check_rs1,
    input logic [31:0] check_rs2,
    input logic [31:0] check_imm,
    input logic check_branch,
    input core_branch_e check_branch_op,
    input logic check_jal,
    input logic check_jalr,
    input logic exp_taken,
    input logic [31:0] exp_target,
    input string label
  );
    begin
      pc = check_pc;
      rs1 = check_rs1;
      rs2 = check_rs2;
      imm = check_imm;
      branch = check_branch;
      branch_op = check_branch_op;
      jal = check_jal;
      jalr = check_jalr;
      #1ns;
      if (taken !== exp_taken || target !== exp_target || link !== (check_pc + 32'd4)) begin
        $error("%s: taken=%0b/%0b target=0x%08h/0x%08h link=0x%08h/0x%08h",
               label, taken, exp_taken, target, exp_target, link, check_pc + 32'd4);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // For one branch op, check one taken case and one not-taken case.
  task automatic check_branch_pair(
    input core_branch_e op,
    input logic [31:0] lhs_take,
    input logic [31:0] rhs_take,
    input logic [31:0] lhs_skip,
    input logic [31:0] rhs_skip,
    input string label
  );
    logic [31:0] base_pc;
    logic [31:0] offset;
    begin
      base_pc = 32'h0000_1000 + (pass_count << 2);
      offset = 32'h0000_0020;
      check_case(base_pc, lhs_take, rhs_take, offset, 1'b1, op, 1'b0, 1'b0,
                 1'b1, base_pc + offset, {label, " taken"});
      branch_taken_count++;
      check_case(base_pc, lhs_skip, rhs_skip, offset, 1'b1, op, 1'b0, 1'b0,
                 1'b0, base_pc + 32'd4, {label, " not taken"});
      branch_not_taken_count++;
    end
  endtask

  // Directed checks for JAL forward/backward and JALR bit-zero clearing.
  task automatic check_jumps;
    begin
      check_case(32'h0000_2000, 32'h0000_0000, 32'h0000_0000, 32'h0000_0100,
                 1'b0, CORE_BRANCH_NONE, 1'b1, 1'b0,
                 1'b1, 32'h0000_2100, "jal forward");
      jump_count++;

      check_case(32'h0000_2000, 32'h0000_0000, 32'h0000_0000, 32'hFFFF_FF00,
                 1'b0, CORE_BRANCH_NONE, 1'b1, 1'b0,
                 1'b1, 32'h0000_1F00, "jal backward");
      jump_count++;

      check_case(32'h0000_3000, 32'h0000_4001, 32'h0000_0000, 32'h0000_0004,
                 1'b0, CORE_BRANCH_NONE, 1'b0, 1'b1,
                 1'b1, 32'h0000_4004, "jalr clears bit zero");
      jump_count++;

      check_case(32'h0000_3000, 32'hFFFF_FFFF, 32'h0000_0000, 32'h0000_0003,
                 1'b0, CORE_BRANCH_NONE, 1'b0, 1'b1,
                 1'b1, 32'h0000_0002, "jalr wrap clears bit zero");
      jump_count++;
    end
  endtask

  task automatic check_priority;
    begin
      check_case(32'h0000_5000, 32'h0000_6001, 32'h0000_6001, 32'h0000_0010,
                 1'b1, CORE_BRANCH_BEQ, 1'b1, 1'b1,
                 1'b1, 32'h0000_5010, "jal priority over jalr branch");
      priority_count++;

      check_case(32'h0000_5000, 32'h0000_6001, 32'h0000_6001, 32'h0000_0010,
                 1'b1, CORE_BRANCH_BEQ, 1'b0, 1'b1,
                 1'b1, 32'h0000_6010, "jalr priority over branch");
      priority_count++;
    end
  endtask

  task automatic check_random(input int unsigned count);
    logic [31:0] rand_pc;
    logic [31:0] rand_rs1;
    logic [31:0] rand_rs2;
    logic [31:0] rand_imm;
    core_branch_e rand_op;
    logic exp_taken;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        rand_pc = {$urandom()[29:0], 2'b00};
        rand_rs1 = $urandom();
        rand_rs2 = $urandom();
        rand_imm = {$urandom()[29:0], 2'b00};
        rand_op = core_branch_e'($urandom_range(1, 6));
        exp_taken = ref_branch_taken(rand_op, rand_rs1, rand_rs2);
        check_case(rand_pc, rand_rs1, rand_rs2, rand_imm, 1'b1, rand_op, 1'b0, 1'b0,
                   exp_taken, exp_taken ? (rand_pc + rand_imm) : (rand_pc + 32'd4),
                   "random branch");
        random_count++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (branch_taken_count < 6 || branch_not_taken_count < 6 ||
          signed_count < 2 || unsigned_count < 2 || jump_count < 4 ||
          priority_count < 2 || random_count < 100) begin
        $error("coverage miss: taken=%0d not_taken=%0d signed=%0d unsigned=%0d jump=%0d priority=%0d random=%0d",
               branch_taken_count, branch_not_taken_count, signed_count,
               unsigned_count, jump_count, priority_count, random_count);
        $fatal(1);
      end
      $display("tb_core_branch coverage: pass_count=%0d branch_taken=%0d branch_not_taken=%0d signed=%0d unsigned=%0d jump=%0d priority=%0d random=%0d",
               pass_count, branch_taken_count, branch_not_taken_count,
               signed_count, unsigned_count, jump_count, priority_count, random_count);
    end
  endtask

  initial begin
    void'($urandom(32'hB0A0_0004));
    pass_count = 0;
    branch_taken_count = 0;
    branch_not_taken_count = 0;
    signed_count = 0;
    unsigned_count = 0;
    jump_count = 0;
    priority_count = 0;
    random_count = 0;

    check_case(32'h0000_0800, 32'h1, 32'h2, 32'h20, 1'b0,
               CORE_BRANCH_BEQ, 1'b0, 1'b0, 1'b0, 32'h0000_0804, "idle link");

    check_branch_pair(CORE_BRANCH_BEQ, 32'h1234_5678, 32'h1234_5678,
                      32'h1234_5678, 32'h8765_4321, "beq");
    check_branch_pair(CORE_BRANCH_BNE, 32'h1234_5678, 32'h8765_4321,
                      32'h1234_5678, 32'h1234_5678, "bne");
    check_branch_pair(CORE_BRANCH_BLT, 32'hFFFF_FFFF, 32'h0000_0001,
                      32'h0000_0001, 32'hFFFF_FFFF, "blt signed");
    signed_count++;
    check_branch_pair(CORE_BRANCH_BGE, 32'h0000_0001, 32'hFFFF_FFFF,
                      32'hFFFF_FFFF, 32'h0000_0001, "bge signed");
    signed_count++;
    check_branch_pair(CORE_BRANCH_BLTU, 32'h0000_0001, 32'hFFFF_FFFF,
                      32'hFFFF_FFFF, 32'h0000_0001, "bltu unsigned");
    unsigned_count++;
    check_branch_pair(CORE_BRANCH_BGEU, 32'hFFFF_FFFF, 32'h0000_0001,
                      32'h0000_0001, 32'hFFFF_FFFF, "bgeu unsigned");
    unsigned_count++;

    check_jumps();
    check_priority();
    check_random(100);
    check_coverage_summary();

    $display("tb_core_branch PASS");
    $finish;
  end
endmodule
