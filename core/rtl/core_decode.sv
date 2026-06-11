`timescale 1ns/1ps

// RV32I + Zicsr instruction decoder.
//
// The decoder is combinational and emits raw register fields, immediate data,
// functional-unit controls, and illegal-instruction indication for one 32-bit
// instruction. Later pipeline stages use the explicit use/write qualifiers
// instead of inferring whether rs/rd fields are architecturally consumed.
module core_decode (
  input  logic [31:0]                 instr_i,       // Raw 32-bit instruction word.

  output logic [4:0]                  rd_o,          // Raw rd field instr[11:7].
  output logic [4:0]                  rs1_o,         // Raw rs1 field instr[19:15].
  output logic [4:0]                  rs2_o,         // Raw rs2 field instr[24:20].
  output logic [31:0]                 imm_o,         // Decoded immediate, sign/zero extended.
  output core_types_pkg::core_imm_sel_e imm_sel_o,   // Immediate format selected by opcode.

  output logic                        uses_rs1_o,    // Instruction reads rs1 architecturally.
  output logic                        uses_rs2_o,    // Instruction reads rs2 architecturally.
  output logic                        writes_rd_o,   // Instruction writes rd architecturally.

  output logic                        alu_valid_o,   // ALU operation is requested.
  output core_types_pkg::core_alu_op_e alu_op_o,     // ALU operation code for execute.
  output logic                        alu_src_imm_o, // ALU rhs comes from imm_o instead of rs2.

  output logic                        load_o,        // Load instruction qualifier.
  output logic                        store_o,       // Store instruction qualifier.
  output core_types_pkg::core_lsu_size_e lsu_size_o, // LSU byte/half/word size.
  output logic                        lsu_unsigned_o,// Load is zero-extending when asserted.

  output logic                        branch_o,      // Conditional branch qualifier.
  output core_types_pkg::core_branch_e branch_op_o,  // Specific branch comparison operation.
  output logic                        jal_o,         // JAL qualifier.
  output logic                        jalr_o,        // JALR qualifier.
  output logic                        lui_o,         // LUI qualifier.
  output logic                        auipc_o,       // AUIPC qualifier.

  output logic                        csr_o,         // CSR instruction qualifier.
  output core_types_pkg::core_csr_cmd_e csr_cmd_o,   // Zicsr read/write/set/clear command.
  output logic [11:0]                 csr_addr_o,    // CSR address instr[31:20].
  output logic                        ecall_o,       // ECALL system instruction.
  output logic                        ebreak_o,      // EBREAK system instruction.
  output logic                        mret_o,        // MRET system instruction.

  output logic                        illegal_o      // Unsupported or reserved encoding.
);
  import core_types_pkg::*;

  // RV32I opcode constants used by the top-level decode case.
  localparam logic [6:0] OPCODE_LUI    = 7'b0110111;
  localparam logic [6:0] OPCODE_AUIPC  = 7'b0010111;
  localparam logic [6:0] OPCODE_JAL    = 7'b1101111;
  localparam logic [6:0] OPCODE_JALR   = 7'b1100111;
  localparam logic [6:0] OPCODE_BRANCH = 7'b1100011;
  localparam logic [6:0] OPCODE_LOAD   = 7'b0000011;
  localparam logic [6:0] OPCODE_STORE  = 7'b0100011;
  localparam logic [6:0] OPCODE_OP_IMM = 7'b0010011;
  localparam logic [6:0] OPCODE_OP     = 7'b0110011;
  localparam logic [6:0] OPCODE_SYSTEM = 7'b1110011;

  logic [6:0] opcode; // Primary opcode field instr[6:0].
  logic [2:0] funct3; // Secondary operation field instr[14:12].
  logic [6:0] funct7; // Extended operation field instr[31:25].

  assign opcode = instr_i[6:0];
  assign funct3 = instr_i[14:12];
  assign funct7 = instr_i[31:25];

  // Decode one instruction. Defaults describe a non-operation with raw fields
  // still exposed; each opcode branch selectively enables consumed resources.
  always_comb begin
    rd_o = instr_i[11:7];
    rs1_o = instr_i[19:15];
    rs2_o = instr_i[24:20];
    imm_o = 32'h0000_0000;
    imm_sel_o = CORE_IMM_NONE;

    uses_rs1_o = 1'b0;
    uses_rs2_o = 1'b0;
    writes_rd_o = 1'b0;

    alu_valid_o = 1'b0;
    alu_op_o = CORE_ALU_ADD;
    alu_src_imm_o = 1'b0;

    load_o = 1'b0;
    store_o = 1'b0;
    lsu_size_o = CORE_LSU_WORD;
    lsu_unsigned_o = 1'b0;

    branch_o = 1'b0;
    branch_op_o = CORE_BRANCH_NONE;
    jal_o = 1'b0;
    jalr_o = 1'b0;
    lui_o = 1'b0;
    auipc_o = 1'b0;

    csr_o = 1'b0;
    csr_cmd_o = CORE_CSR_NONE;
    csr_addr_o = instr_i[31:20];
    ecall_o = 1'b0;
    ebreak_o = 1'b0;
    mret_o = 1'b0;

    illegal_o = 1'b0;

    unique case (opcode)
      OPCODE_LUI: begin
        // LUI writes the U immediate directly to rd.
        imm_sel_o = CORE_IMM_U;
        imm_o = {instr_i[31:12], 12'h000};
        writes_rd_o = 1'b1;
        lui_o = 1'b1;
      end

      OPCODE_AUIPC: begin
        // AUIPC writes PC + U immediate in the execute/writeback path.
        imm_sel_o = CORE_IMM_U;
        imm_o = {instr_i[31:12], 12'h000};
        writes_rd_o = 1'b1;
        auipc_o = 1'b1;
      end

      OPCODE_JAL: begin
        // J immediate is sign-extended and includes an implicit low zero bit.
        imm_sel_o = CORE_IMM_J;
        imm_o = {{11{instr_i[31]}}, instr_i[31], instr_i[19:12],
                 instr_i[20], instr_i[30:21], 1'b0};
        writes_rd_o = 1'b1;
        jal_o = 1'b1;
      end

      OPCODE_JALR: begin
        // JALR uses rs1 + I immediate; only funct3=000 is legal in RV32I.
        imm_sel_o = CORE_IMM_I;
        imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
        uses_rs1_o = 1'b1;
        writes_rd_o = 1'b1;
        jalr_o = 1'b1;
        illegal_o = (funct3 != 3'b000);
      end

      OPCODE_BRANCH: begin
        // Branch immediates are PC-relative and have an implicit low zero bit.
        imm_sel_o = CORE_IMM_B;
        imm_o = {{19{instr_i[31]}}, instr_i[31], instr_i[7],
                 instr_i[30:25], instr_i[11:8], 1'b0};
        uses_rs1_o = 1'b1;
        uses_rs2_o = 1'b1;
        branch_o = 1'b1;
        unique case (funct3)
          3'b000: branch_op_o = CORE_BRANCH_BEQ;
          3'b001: branch_op_o = CORE_BRANCH_BNE;
          3'b100: branch_op_o = CORE_BRANCH_BLT;
          3'b101: branch_op_o = CORE_BRANCH_BGE;
          3'b110: branch_op_o = CORE_BRANCH_BLTU;
          3'b111: branch_op_o = CORE_BRANCH_BGEU;
          default: illegal_o = 1'b1;
        endcase
      end

      OPCODE_LOAD: begin
        // Load funct3 selects size and signedness for the LSU helper.
        imm_sel_o = CORE_IMM_I;
        imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
        uses_rs1_o = 1'b1;
        writes_rd_o = 1'b1;
        load_o = 1'b1;
        unique case (funct3)
          3'b000: lsu_size_o = CORE_LSU_BYTE;
          3'b001: lsu_size_o = CORE_LSU_HALF;
          3'b010: lsu_size_o = CORE_LSU_WORD;
          3'b100: begin
            lsu_size_o = CORE_LSU_BYTE;
            lsu_unsigned_o = 1'b1;
          end
          3'b101: begin
            lsu_size_o = CORE_LSU_HALF;
            lsu_unsigned_o = 1'b1;
          end
          default: illegal_o = 1'b1;
        endcase
      end

      OPCODE_STORE: begin
        // Store immediates are split between instr[31:25] and instr[11:7].
        imm_sel_o = CORE_IMM_S;
        imm_o = {{20{instr_i[31]}}, instr_i[31:25], instr_i[11:7]};
        uses_rs1_o = 1'b1;
        uses_rs2_o = 1'b1;
        store_o = 1'b1;
        unique case (funct3)
          3'b000: lsu_size_o = CORE_LSU_BYTE;
          3'b001: lsu_size_o = CORE_LSU_HALF;
          3'b010: lsu_size_o = CORE_LSU_WORD;
          default: illegal_o = 1'b1;
        endcase
      end

      OPCODE_OP_IMM: begin
        // Immediate ALU operations consume rs1 and the decoded I immediate.
        imm_sel_o = CORE_IMM_I;
        imm_o = {{20{instr_i[31]}}, instr_i[31:20]};
        uses_rs1_o = 1'b1;
        writes_rd_o = 1'b1;
        alu_valid_o = 1'b1;
        alu_src_imm_o = 1'b1;
        unique case (funct3)
          3'b000: alu_op_o = CORE_ALU_ADD;
          3'b010: alu_op_o = CORE_ALU_SLT;
          3'b011: alu_op_o = CORE_ALU_SLTU;
          3'b100: alu_op_o = CORE_ALU_XOR;
          3'b110: alu_op_o = CORE_ALU_OR;
          3'b111: alu_op_o = CORE_ALU_AND;
          3'b001: begin
            alu_op_o = CORE_ALU_SLL;
            illegal_o = (funct7 != 7'b0000000);
          end
          3'b101: begin
            alu_op_o = (funct7 == 7'b0100000) ? CORE_ALU_SRA : CORE_ALU_SRL;
            illegal_o = !((funct7 == 7'b0000000) || (funct7 == 7'b0100000));
          end
          default: illegal_o = 1'b1;
        endcase
      end

      OPCODE_OP: begin
        // Register-register ALU operations consume both source registers.
        uses_rs1_o = 1'b1;
        uses_rs2_o = 1'b1;
        writes_rd_o = 1'b1;
        alu_valid_o = 1'b1;
        unique case (funct3)
          3'b000: begin
            alu_op_o = (funct7 == 7'b0100000) ? CORE_ALU_SUB : CORE_ALU_ADD;
            illegal_o = !((funct7 == 7'b0000000) || (funct7 == 7'b0100000));
          end
          3'b001: begin
            alu_op_o = CORE_ALU_SLL;
            illegal_o = (funct7 != 7'b0000000);
          end
          3'b010: begin
            alu_op_o = CORE_ALU_SLT;
            illegal_o = (funct7 != 7'b0000000);
          end
          3'b011: begin
            alu_op_o = CORE_ALU_SLTU;
            illegal_o = (funct7 != 7'b0000000);
          end
          3'b100: begin
            alu_op_o = CORE_ALU_XOR;
            illegal_o = (funct7 != 7'b0000000);
          end
          3'b101: begin
            alu_op_o = (funct7 == 7'b0100000) ? CORE_ALU_SRA : CORE_ALU_SRL;
            illegal_o = !((funct7 == 7'b0000000) || (funct7 == 7'b0100000));
          end
          3'b110: begin
            alu_op_o = CORE_ALU_OR;
            illegal_o = (funct7 != 7'b0000000);
          end
          3'b111: begin
            alu_op_o = CORE_ALU_AND;
            illegal_o = (funct7 != 7'b0000000);
          end
          default: illegal_o = 1'b1;
        endcase
      end

      OPCODE_SYSTEM: begin
        // SYSTEM covers ECALL/EBREAK/MRET when funct3=000 and Zicsr otherwise.
        unique case (funct3)
          3'b000: begin
            ecall_o = (instr_i == 32'h0000_0073);
            ebreak_o = (instr_i == 32'h0010_0073);
            mret_o = (instr_i == 32'h3020_0073);
            illegal_o = !(ecall_o || ebreak_o || mret_o);
          end
          3'b001: begin
            csr_o = 1'b1;
            csr_cmd_o = CORE_CSR_RW;
          end
          3'b010: begin
            csr_o = 1'b1;
            csr_cmd_o = CORE_CSR_RS;
          end
          3'b011: begin
            csr_o = 1'b1;
            csr_cmd_o = CORE_CSR_RC;
          end
          3'b101: begin
            csr_o = 1'b1;
            csr_cmd_o = CORE_CSR_RWI;
          end
          3'b110: begin
            csr_o = 1'b1;
            csr_cmd_o = CORE_CSR_RSI;
          end
          3'b111: begin
            csr_o = 1'b1;
            csr_cmd_o = CORE_CSR_RCI;
          end
          default: illegal_o = 1'b1;
        endcase
        if (csr_o) begin
          // CSR immediate forms use zimm in rs1 field; register forms use rs1.
          imm_sel_o = CORE_IMM_CSR;
          imm_o = {27'h000_0000, instr_i[19:15]};
          uses_rs1_o = !funct3[2];
          writes_rd_o = 1'b1;
        end
      end

      default: begin
        illegal_o = 1'b1;
      end
    endcase
  end
endmodule
