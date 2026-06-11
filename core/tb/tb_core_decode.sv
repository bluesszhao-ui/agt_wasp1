`timescale 1ns/1ps

module tb_core_decode;
  import core_types_pkg::*;

  logic [31:0] instr;
  logic [4:0] rd;
  logic [4:0] rs1;
  logic [4:0] rs2;
  logic [31:0] imm;
  core_imm_sel_e imm_sel;
  logic uses_rs1;
  logic uses_rs2;
  logic writes_rd;
  logic alu_valid;
  core_alu_op_e alu_op;
  logic alu_src_imm;
  logic load;
  logic store;
  core_lsu_size_e lsu_size;
  logic lsu_unsigned;
  logic branch;
  core_branch_e branch_op;
  logic jal;
  logic jalr;
  logic lui;
  logic auipc;
  logic csr;
  core_csr_cmd_e csr_cmd;
  logic [11:0] csr_addr;
  logic ecall;
  logic ebreak;
  logic mret;
  logic illegal;

  int unsigned pass_count;
  int unsigned alu_r_count;
  int unsigned alu_i_count;
  int unsigned branch_count;
  int unsigned load_count;
  int unsigned store_count;
  int unsigned jump_count;
  int unsigned csr_count;
  int unsigned system_count;
  int unsigned illegal_count;

  core_decode u_core_decode (
    .instr_i(instr),
    .rd_o(rd),
    .rs1_o(rs1),
    .rs2_o(rs2),
    .imm_o(imm),
    .imm_sel_o(imm_sel),
    .uses_rs1_o(uses_rs1),
    .uses_rs2_o(uses_rs2),
    .writes_rd_o(writes_rd),
    .alu_valid_o(alu_valid),
    .alu_op_o(alu_op),
    .alu_src_imm_o(alu_src_imm),
    .load_o(load),
    .store_o(store),
    .lsu_size_o(lsu_size),
    .lsu_unsigned_o(lsu_unsigned),
    .branch_o(branch),
    .branch_op_o(branch_op),
    .jal_o(jal),
    .jalr_o(jalr),
    .lui_o(lui),
    .auipc_o(auipc),
    .csr_o(csr),
    .csr_cmd_o(csr_cmd),
    .csr_addr_o(csr_addr),
    .ecall_o(ecall),
    .ebreak_o(ebreak),
    .mret_o(mret),
    .illegal_o(illegal)
  );

  function automatic logic [31:0] enc_r(
    input logic [6:0] funct7,
    input logic [4:0] enc_rs2,
    input logic [4:0] enc_rs1,
    input logic [2:0] funct3,
    input logic [4:0] enc_rd
  );
    enc_r = {funct7, enc_rs2, enc_rs1, funct3, enc_rd, 7'b0110011};
  endfunction

  function automatic logic [31:0] enc_i(
    input logic [11:0] imm12,
    input logic [4:0] enc_rs1,
    input logic [2:0] funct3,
    input logic [4:0] enc_rd,
    input logic [6:0] opcode
  );
    enc_i = {imm12, enc_rs1, funct3, enc_rd, opcode};
  endfunction

  function automatic logic [31:0] enc_s(
    input logic [11:0] imm12,
    input logic [4:0] enc_rs2,
    input logic [4:0] enc_rs1,
    input logic [2:0] funct3
  );
    enc_s = {imm12[11:5], enc_rs2, enc_rs1, funct3, imm12[4:0], 7'b0100011};
  endfunction

  function automatic logic [31:0] enc_b(
    input logic [12:0] imm13,
    input logic [4:0] enc_rs2,
    input logic [4:0] enc_rs1,
    input logic [2:0] funct3
  );
    enc_b = {imm13[12], imm13[10:5], enc_rs2, enc_rs1, funct3,
             imm13[4:1], imm13[11], 7'b1100011};
  endfunction

  function automatic logic [31:0] enc_u(
    input logic [19:0] imm20,
    input logic [4:0] enc_rd,
    input logic [6:0] opcode
  );
    enc_u = {imm20, enc_rd, opcode};
  endfunction

  function automatic logic [31:0] enc_j(
    input logic [20:0] imm21,
    input logic [4:0] enc_rd
  );
    enc_j = {imm21[20], imm21[10:1], imm21[11], imm21[19:12],
             enc_rd, 7'b1101111};
  endfunction

  task automatic apply_instr(input logic [31:0] inst);
    begin
      instr = inst;
      #1ns;
    end
  endtask

  task automatic require_common(
    input logic [4:0] exp_rd,
    input logic [4:0] exp_rs1,
    input logic [4:0] exp_rs2,
    input logic [31:0] exp_imm,
    input core_imm_sel_e exp_imm_sel,
    input logic exp_uses_rs1,
    input logic exp_uses_rs2,
    input logic exp_writes_rd,
    input string label
  );
    begin
      if (rd !== exp_rd || rs1 !== exp_rs1 || rs2 !== exp_rs2 ||
          imm !== exp_imm || imm_sel !== exp_imm_sel ||
          uses_rs1 !== exp_uses_rs1 || uses_rs2 !== exp_uses_rs2 ||
          writes_rd !== exp_writes_rd) begin
        $error("%s common mismatch rd=%0d/%0d rs1=%0d/%0d rs2=%0d/%0d imm=0x%08h/0x%08h imm_sel=%0d/%0d use=%0b%0b/%0b%0b wr=%0b/%0b",
               label, rd, exp_rd, rs1, exp_rs1, rs2, exp_rs2, imm, exp_imm,
               imm_sel, exp_imm_sel, uses_rs1, uses_rs2, exp_uses_rs1,
               exp_uses_rs2, writes_rd, exp_writes_rd);
        $fatal(1);
      end
    end
  endtask

  task automatic require_no_mem_branch_csr(input string label);
    begin
      if (load || store || branch || jal || jalr || lui || auipc || csr ||
          ecall || ebreak || mret || illegal) begin
        $error("%s unexpected sideband asserted", label);
        $fatal(1);
      end
    end
  endtask

  task automatic check_r_alu(
    input logic [31:0] inst,
    input core_alu_op_e exp_op,
    input string label
  );
    begin
      apply_instr(inst);
      require_common(inst[11:7], inst[19:15], inst[24:20], 32'h0000_0000,
                     CORE_IMM_NONE, 1'b1, 1'b1, 1'b1, label);
      if (!alu_valid || alu_src_imm || alu_op !== exp_op) begin
        $error("%s ALU-R mismatch valid=%0b src_imm=%0b op=%0d exp=%0d",
               label, alu_valid, alu_src_imm, alu_op, exp_op);
        $fatal(1);
      end
      require_no_mem_branch_csr(label);
      alu_r_count++;
      pass_count++;
    end
  endtask

  task automatic check_i_alu(
    input logic [31:0] inst,
    input core_alu_op_e exp_op,
    input logic [31:0] exp_imm,
    input string label
  );
    begin
      apply_instr(inst);
      require_common(inst[11:7], inst[19:15], inst[24:20], exp_imm,
                     CORE_IMM_I, 1'b1, 1'b0, 1'b1, label);
      if (!alu_valid || !alu_src_imm || alu_op !== exp_op) begin
        $error("%s ALU-I mismatch valid=%0b src_imm=%0b op=%0d exp=%0d",
               label, alu_valid, alu_src_imm, alu_op, exp_op);
        $fatal(1);
      end
      require_no_mem_branch_csr(label);
      alu_i_count++;
      pass_count++;
    end
  endtask

  task automatic check_branch(
    input logic [31:0] inst,
    input core_branch_e exp_branch,
    input logic [31:0] exp_imm,
    input string label
  );
    begin
      apply_instr(inst);
      require_common(inst[11:7], inst[19:15], inst[24:20], exp_imm,
                     CORE_IMM_B, 1'b1, 1'b1, 1'b0, label);
      if (!branch || branch_op !== exp_branch || illegal) begin
        $error("%s branch mismatch branch=%0b op=%0d exp=%0d illegal=%0b",
               label, branch, branch_op, exp_branch, illegal);
        $fatal(1);
      end
      branch_count++;
      pass_count++;
    end
  endtask

  task automatic check_load(
    input logic [31:0] inst,
    input core_lsu_size_e exp_size,
    input logic exp_unsigned,
    input logic [31:0] exp_imm,
    input string label
  );
    begin
      apply_instr(inst);
      require_common(inst[11:7], inst[19:15], inst[24:20], exp_imm,
                     CORE_IMM_I, 1'b1, 1'b0, 1'b1, label);
      if (!load || store || lsu_size !== exp_size ||
          lsu_unsigned !== exp_unsigned || illegal) begin
        $error("%s load mismatch load=%0b size=%0d/%0d unsigned=%0b/%0b illegal=%0b",
               label, load, lsu_size, exp_size, lsu_unsigned, exp_unsigned, illegal);
        $fatal(1);
      end
      load_count++;
      pass_count++;
    end
  endtask

  task automatic check_store(
    input logic [31:0] inst,
    input core_lsu_size_e exp_size,
    input logic [31:0] exp_imm,
    input string label
  );
    begin
      apply_instr(inst);
      require_common(inst[11:7], inst[19:15], inst[24:20], exp_imm,
                     CORE_IMM_S, 1'b1, 1'b1, 1'b0, label);
      if (!store || load || lsu_size !== exp_size || illegal) begin
        $error("%s store mismatch store=%0b size=%0d/%0d illegal=%0b",
               label, store, lsu_size, exp_size, illegal);
        $fatal(1);
      end
      store_count++;
      pass_count++;
    end
  endtask

  task automatic check_csr(
    input logic [31:0] inst,
    input core_csr_cmd_e exp_cmd,
    input logic exp_uses_rs1,
    input string label
  );
    begin
      apply_instr(inst);
      require_common(inst[11:7], inst[19:15], inst[24:20],
                     {27'd0, inst[19:15]}, CORE_IMM_CSR,
                     exp_uses_rs1, 1'b0, 1'b1, label);
      if (!csr || csr_cmd !== exp_cmd || csr_addr !== inst[31:20] || illegal) begin
        $error("%s csr mismatch csr=%0b cmd=%0d/%0d addr=0x%03h/0x%03h illegal=%0b",
               label, csr, csr_cmd, exp_cmd, csr_addr, inst[31:20], illegal);
        $fatal(1);
      end
      csr_count++;
      pass_count++;
    end
  endtask

  task automatic check_illegal(input logic [31:0] inst, input string label);
    begin
      apply_instr(inst);
      if (!illegal) begin
        $error("%s expected illegal for instr=0x%08h", label, inst);
        $fatal(1);
      end
      illegal_count++;
      pass_count++;
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (alu_r_count < 10 || alu_i_count < 9 || branch_count < 6 ||
          load_count < 5 || store_count < 3 || jump_count < 4 ||
          csr_count < 6 || system_count < 3 || illegal_count < 6) begin
        $error("coverage miss: alu_r=%0d alu_i=%0d branch=%0d load=%0d store=%0d jump=%0d csr=%0d system=%0d illegal=%0d",
               alu_r_count, alu_i_count, branch_count, load_count, store_count,
               jump_count, csr_count, system_count, illegal_count);
        $fatal(1);
      end
      $display("tb_core_decode coverage: pass_count=%0d alu_r=%0d alu_i=%0d branch=%0d load=%0d store=%0d jump=%0d csr=%0d system=%0d illegal=%0d",
               pass_count, alu_r_count, alu_i_count, branch_count, load_count,
               store_count, jump_count, csr_count, system_count, illegal_count);
    end
  endtask

  initial begin
    pass_count = 0;
    alu_r_count = 0;
    alu_i_count = 0;
    branch_count = 0;
    load_count = 0;
    store_count = 0;
    jump_count = 0;
    csr_count = 0;
    system_count = 0;
    illegal_count = 0;

    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b000, 5'd1), CORE_ALU_ADD, "add");
    check_r_alu(enc_r(7'b0100000, 5'd3, 5'd2, 3'b000, 5'd1), CORE_ALU_SUB, "sub");
    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b001, 5'd1), CORE_ALU_SLL, "sll");
    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b010, 5'd1), CORE_ALU_SLT, "slt");
    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b011, 5'd1), CORE_ALU_SLTU, "sltu");
    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b100, 5'd1), CORE_ALU_XOR, "xor");
    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b101, 5'd1), CORE_ALU_SRL, "srl");
    check_r_alu(enc_r(7'b0100000, 5'd3, 5'd2, 3'b101, 5'd1), CORE_ALU_SRA, "sra");
    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b110, 5'd1), CORE_ALU_OR, "or");
    check_r_alu(enc_r(7'b0000000, 5'd3, 5'd2, 3'b111, 5'd1), CORE_ALU_AND, "and");

    check_i_alu(enc_i(12'h801, 5'd4, 3'b000, 5'd5, 7'b0010011), CORE_ALU_ADD, 32'hFFFF_F801, "addi neg");
    check_i_alu(enc_i(12'h07F, 5'd4, 3'b010, 5'd5, 7'b0010011), CORE_ALU_SLT, 32'h0000_007F, "slti");
    check_i_alu(enc_i(12'h080, 5'd4, 3'b011, 5'd5, 7'b0010011), CORE_ALU_SLTU, 32'h0000_0080, "sltiu");
    check_i_alu(enc_i(12'h055, 5'd4, 3'b100, 5'd5, 7'b0010011), CORE_ALU_XOR, 32'h0000_0055, "xori");
    check_i_alu(enc_i(12'h0AA, 5'd4, 3'b110, 5'd5, 7'b0010011), CORE_ALU_OR, 32'h0000_00AA, "ori");
    check_i_alu(enc_i(12'h0F0, 5'd4, 3'b111, 5'd5, 7'b0010011), CORE_ALU_AND, 32'h0000_00F0, "andi");
    check_i_alu(enc_i(12'h003, 5'd4, 3'b001, 5'd5, 7'b0010011), CORE_ALU_SLL, 32'h0000_0003, "slli");
    check_i_alu(enc_i(12'h004, 5'd4, 3'b101, 5'd5, 7'b0010011), CORE_ALU_SRL, 32'h0000_0004, "srli");
    check_i_alu(enc_i(12'h405, 5'd4, 3'b101, 5'd5, 7'b0010011), CORE_ALU_SRA, 32'h0000_0405, "srai");

    check_branch(enc_b(13'h0008, 5'd8, 5'd7, 3'b000), CORE_BRANCH_BEQ, 32'h0000_0008, "beq");
    check_branch(enc_b(13'h1FF0, 5'd8, 5'd7, 3'b001), CORE_BRANCH_BNE, 32'hFFFF_FFF0, "bne neg");
    check_branch(enc_b(13'h0004, 5'd8, 5'd7, 3'b100), CORE_BRANCH_BLT, 32'h0000_0004, "blt");
    check_branch(enc_b(13'h0006, 5'd8, 5'd7, 3'b101), CORE_BRANCH_BGE, 32'h0000_0006, "bge");
    check_branch(enc_b(13'h000A, 5'd8, 5'd7, 3'b110), CORE_BRANCH_BLTU, 32'h0000_000A, "bltu");
    check_branch(enc_b(13'h000C, 5'd8, 5'd7, 3'b111), CORE_BRANCH_BGEU, 32'h0000_000C, "bgeu");

    check_load(enc_i(12'hFFC, 5'd9, 3'b000, 5'd10, 7'b0000011), CORE_LSU_BYTE, 1'b0, 32'hFFFF_FFFC, "lb");
    check_load(enc_i(12'h004, 5'd9, 3'b001, 5'd10, 7'b0000011), CORE_LSU_HALF, 1'b0, 32'h0000_0004, "lh");
    check_load(enc_i(12'h008, 5'd9, 3'b010, 5'd10, 7'b0000011), CORE_LSU_WORD, 1'b0, 32'h0000_0008, "lw");
    check_load(enc_i(12'h00C, 5'd9, 3'b100, 5'd10, 7'b0000011), CORE_LSU_BYTE, 1'b1, 32'h0000_000C, "lbu");
    check_load(enc_i(12'h010, 5'd9, 3'b101, 5'd10, 7'b0000011), CORE_LSU_HALF, 1'b1, 32'h0000_0010, "lhu");

    check_store(enc_s(12'hFFC, 5'd11, 5'd12, 3'b000), CORE_LSU_BYTE, 32'hFFFF_FFFC, "sb");
    check_store(enc_s(12'h004, 5'd11, 5'd12, 3'b001), CORE_LSU_HALF, 32'h0000_0004, "sh");
    check_store(enc_s(12'h008, 5'd11, 5'd12, 3'b010), CORE_LSU_WORD, 32'h0000_0008, "sw");

    apply_instr(enc_u(20'hABCDE, 5'd13, 7'b0110111));
    require_common(instr[11:7], instr[19:15], instr[24:20], 32'hABCDE000,
                   CORE_IMM_U, 1'b0, 1'b0, 1'b1, "lui");
    if (!lui || illegal) $fatal(1);
    jump_count++;
    pass_count++;

    apply_instr(enc_u(20'h12345, 5'd14, 7'b0010111));
    require_common(instr[11:7], instr[19:15], instr[24:20], 32'h12345000,
                   CORE_IMM_U, 1'b0, 1'b0, 1'b1, "auipc");
    if (!auipc || illegal) $fatal(1);
    jump_count++;
    pass_count++;

    apply_instr(enc_j(21'h00010, 5'd15));
    require_common(instr[11:7], instr[19:15], instr[24:20], 32'h0000_0010,
                   CORE_IMM_J, 1'b0, 1'b0, 1'b1, "jal");
    if (!jal || illegal) $fatal(1);
    jump_count++;
    pass_count++;

    apply_instr(enc_i(12'hFF8, 5'd16, 3'b000, 5'd17, 7'b1100111));
    require_common(instr[11:7], instr[19:15], instr[24:20], 32'hFFFF_FFF8,
                   CORE_IMM_I, 1'b1, 1'b0, 1'b1, "jalr");
    if (!jalr || illegal) $fatal(1);
    jump_count++;
    pass_count++;

    check_csr(enc_i(12'h300, 5'd18, 3'b001, 5'd19, 7'b1110011), CORE_CSR_RW, 1'b1, "csrrw");
    check_csr(enc_i(12'h304, 5'd18, 3'b010, 5'd19, 7'b1110011), CORE_CSR_RS, 1'b1, "csrrs");
    check_csr(enc_i(12'h305, 5'd18, 3'b011, 5'd19, 7'b1110011), CORE_CSR_RC, 1'b1, "csrrc");
    check_csr(enc_i(12'h341, 5'd18, 3'b101, 5'd19, 7'b1110011), CORE_CSR_RWI, 1'b0, "csrrwi");
    check_csr(enc_i(12'h342, 5'd18, 3'b110, 5'd19, 7'b1110011), CORE_CSR_RSI, 1'b0, "csrrsi");
    check_csr(enc_i(12'h343, 5'd18, 3'b111, 5'd19, 7'b1110011), CORE_CSR_RCI, 1'b0, "csrrci");

    apply_instr(32'h0000_0073);
    if (!ecall || illegal || ebreak || mret) $fatal(1);
    system_count++;
    pass_count++;

    apply_instr(32'h0010_0073);
    if (!ebreak || illegal || ecall || mret) $fatal(1);
    system_count++;
    pass_count++;

    apply_instr(32'h3020_0073);
    if (!mret || illegal || ecall || ebreak) $fatal(1);
    system_count++;
    pass_count++;

    check_illegal(32'h0000_0000, "zero instruction");
    check_illegal(enc_r(7'b0000001, 5'd3, 5'd2, 3'b000, 5'd1), "mul encoding excluded");
    check_illegal(enc_i(12'h123, 5'd4, 3'b001, 5'd5, 7'b0010011), "bad slli funct7");
    check_illegal(enc_i(12'h000, 5'd9, 3'b011, 5'd10, 7'b0000011), "bad load funct3");
    check_illegal(enc_s(12'h000, 5'd11, 5'd12, 3'b011), "bad store funct3");
    check_illegal(enc_b(13'h0008, 5'd8, 5'd7, 3'b010), "bad branch funct3");
    check_illegal(enc_i(12'h000, 5'd16, 3'b001, 5'd17, 7'b1100111), "bad jalr funct3");
    check_illegal(32'h1230_0073, "bad system funct3 zero");

    check_coverage_summary();
    $display("tb_core_decode PASS");
    $finish;
  end
endmodule
