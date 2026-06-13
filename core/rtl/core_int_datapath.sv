`timescale 1ns/1ps

// First executable integer datapath integration for the wasp1 core.
//
// This milestone wires the verified pipeline skeleton, decoder, register file,
// ALU, and writeback helper into one small executable path. It intentionally
// supports integer ALU, upper-immediate, branch/jump redirect, and a simple
// single-cycle load/store data path for now; CSR, trap, and full hazard
// integration are staged separately.
module core_int_datapath (
  input  logic        clk_i,              // Core pipeline/register clock.
  input  logic        rst_ni,             // Active-low asynchronous reset.

  input  logic [31:0] boot_pc_i,          // Reset fetch PC, normally OTP_BASE.

  output logic        if_req_valid_o,     // Fetch request valid toward frontend.
  output logic [31:0] if_req_pc_o,        // Fetch request PC.
  input  logic        if_rsp_valid_i,     // Frontend response valid.
  output logic        if_rsp_ready_o,     // Datapath can accept response.
  input  logic [31:0] if_rsp_instr_i,     // Fetched instruction word.
  input  logic        if_rsp_fault_i,     // Fetch fault associated with response.

  output logic        dmem_req_valid_o,   // Data memory request valid.
  output logic [31:0] dmem_req_addr_o,    // Data memory byte address.
  output logic        dmem_req_write_o,   // Data memory store qualifier.
  output logic [1:0]  dmem_req_size_o,    // Data memory access size.
  output logic [31:0] dmem_req_wdata_o,   // Data memory store data aligned to lanes.
  output logic [3:0]  dmem_req_wstrb_o,   // Data memory byte write strobes.
  input  logic [31:0] dmem_rsp_rdata_i,   // Data memory read response data.
  input  logic        dmem_rsp_err_i,     // Data memory response error.

  output logic        commit_valid_o,     // Register writeback happened this cycle.
  output logic [4:0]  commit_rd_o,        // Committed destination register.
  output logic [31:0] commit_data_o,      // Committed writeback data.
  output logic        ex_valid_o,         // Execute/writeback slot is valid.
  output logic [31:0] ex_pc_o,            // Execute/writeback slot PC.
  output logic [31:0] ex_instr_o,         // Execute/writeback slot instruction.
  output logic        illegal_o,          // Decode reported illegal instruction.
  output logic        lsu_fault_o,        // Load/store misalignment or response fault.
  output logic        unsupported_o       // Instruction class is not integrated yet.
);
  import core_types_pkg::*;

  logic        id_valid;          // IF/ID valid from core_pipe; not decoded here yet.
  logic [31:0] id_pc;             // IF/ID PC from core_pipe.
  logic [31:0] id_instr;          // IF/ID instruction from core_pipe.
  logic        id_fetch_fault;    // IF/ID fetch fault from core_pipe.
  logic        ex_valid;          // EX/WB valid from core_pipe.
  logic [31:0] ex_pc;             // EX/WB PC from core_pipe.
  logic [31:0] ex_instr;          // EX/WB instruction from core_pipe.
  logic        ex_fetch_fault;    // EX/WB fetch fault from core_pipe.

  logic [4:0]  dec_rd;            // Destination register decoded from EX instruction.
  logic [4:0]  dec_rs1;           // Source register 1 decoded from EX instruction.
  logic [4:0]  dec_rs2;           // Source register 2 decoded from EX instruction.
  logic [31:0] dec_imm;           // Decoded immediate for EX instruction.
  core_imm_sel_e dec_imm_sel;     // Immediate format, exposed for completeness.
  logic        dec_uses_rs1;      // EX instruction consumes rs1.
  logic        dec_uses_rs2;      // EX instruction consumes rs2.
  logic        dec_writes_rd;     // EX instruction writes rd in the full ISA.
  logic        dec_alu_valid;     // EX instruction uses ALU op encoding.
  core_alu_op_e dec_alu_op;       // ALU operation selector.
  logic        dec_alu_src_imm;   // ALU rhs immediate selector.
  logic        dec_load;          // Load class, not integrated in this milestone.
  logic        dec_store;         // Store class, not integrated in this milestone.
  core_lsu_size_e dec_lsu_size;   // LSU size, unused until LSU integration.
  logic        dec_lsu_unsigned;  // LSU unsigned flag, unused until LSU integration.
  logic        dec_branch;        // Branch class, redirect not integrated yet.
  core_branch_e dec_branch_op;    // Branch op, unused until branch integration.
  logic        dec_jal;           // JAL class; link writeback is integrated.
  logic        dec_jalr;          // JALR class; link writeback is integrated.
  logic        dec_lui;           // LUI class.
  logic        dec_auipc;         // AUIPC class.
  logic        dec_csr;           // CSR class, not integrated in this milestone.
  core_csr_cmd_e dec_csr_cmd;     // CSR command, unused until CSR integration.
  logic [11:0] dec_csr_addr;      // CSR address, unused until CSR integration.
  logic        dec_ecall;         // ECALL, not integrated in this milestone.
  logic        dec_ebreak;        // EBREAK, not integrated in this milestone.
  logic        dec_mret;          // MRET, not integrated in this milestone.
  logic        dec_illegal;       // Illegal instruction indication from decode.

  logic [31:0] rs1_data;          // Register file rs1 read data.
  logic [31:0] rs2_data;          // Register file rs2 read data.
  logic [31:0] alu_lhs;           // ALU left operand.
  logic [31:0] alu_rhs;           // ALU right operand.
  logic [31:0] alu_result;        // ALU result.
  logic        branch_taken;      // Branch helper redirect request.
  logic [31:0] branch_target;     // Branch helper redirect target.
  logic [31:0] branch_link;       // Branch helper link value, ex_pc + 4.
  logic        redirect_valid;    // Redirect request after fault/illegal gating.
  logic [31:0] lsu_load_data;     // Load data after byte/half extension.
  logic        lsu_misaligned;    // Load/store alignment fault from LSU.
  logic        lsu_fault;         // Combined local/memory LSU helper fault.
  logic        lsu_active_fault;  // LSU fault qualified by a load/store op.
  logic [31:0] auipc_result;      // PC-relative AUIPC result.
  core_wb_sel_e wb_sel;           // Writeback source selector.
  logic        wb_rd_write;       // Final write intent before x0/fault suppression.
  logic        rf_we;             // Register file write enable from writeback helper.
  logic [4:0]  rf_waddr;          // Register file write address.
  logic [31:0] rf_wdata;          // Register file write data.
  logic        unsupported;       // Instruction class not connected yet.
  logic        write_fault;       // Any condition that suppresses architectural writeback.

  core_pipe pipe_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .boot_pc_i(boot_pc_i),
    .if_req_valid_o(if_req_valid_o),
    .if_req_pc_o(if_req_pc_o),
    .if_rsp_valid_i(if_rsp_valid_i),
    .if_rsp_ready_o(if_rsp_ready_o),
    .if_rsp_instr_i(if_rsp_instr_i),
    .if_rsp_fault_i(if_rsp_fault_i),
    .fetch_stall_i(1'b0),
    .decode_stall_i(1'b0),
    .execute_bubble_i(1'b0),
    .redirect_valid_i(redirect_valid),
    .redirect_pc_i(branch_target),
    .id_valid_o(id_valid),
    .id_pc_o(id_pc),
    .id_instr_o(id_instr),
    .id_fetch_fault_o(id_fetch_fault),
    .ex_valid_o(ex_valid),
    .ex_pc_o(ex_pc),
    .ex_instr_o(ex_instr),
    .ex_fetch_fault_o(ex_fetch_fault)
  );

  core_decode decode_u (
    .instr_i(ex_instr),
    .rd_o(dec_rd),
    .rs1_o(dec_rs1),
    .rs2_o(dec_rs2),
    .imm_o(dec_imm),
    .imm_sel_o(dec_imm_sel),
    .uses_rs1_o(dec_uses_rs1),
    .uses_rs2_o(dec_uses_rs2),
    .writes_rd_o(dec_writes_rd),
    .alu_valid_o(dec_alu_valid),
    .alu_op_o(dec_alu_op),
    .alu_src_imm_o(dec_alu_src_imm),
    .load_o(dec_load),
    .store_o(dec_store),
    .lsu_size_o(dec_lsu_size),
    .lsu_unsigned_o(dec_lsu_unsigned),
    .branch_o(dec_branch),
    .branch_op_o(dec_branch_op),
    .jal_o(dec_jal),
    .jalr_o(dec_jalr),
    .lui_o(dec_lui),
    .auipc_o(dec_auipc),
    .csr_o(dec_csr),
    .csr_cmd_o(dec_csr_cmd),
    .csr_addr_o(dec_csr_addr),
    .ecall_o(dec_ecall),
    .ebreak_o(dec_ebreak),
    .mret_o(dec_mret),
    .illegal_o(dec_illegal)
  );

  core_regfile #(
    .BYPASS_EN(1'b0)
  ) regfile_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .raddr1_i(dec_rs1),
    .rdata1_o(rs1_data),
    .raddr2_i(dec_rs2),
    .rdata2_o(rs2_data),
    .we_i(rf_we),
    .waddr_i(rf_waddr),
    .wdata_i(rf_wdata)
  );

  // AUIPC uses the PC as the left operand even though decode does not mark it
  // as a normal ALU instruction. JAL/JALR link writes use core_wb PC+4 path.
  assign alu_lhs = dec_auipc ? ex_pc : rs1_data;
  assign alu_rhs = (dec_alu_src_imm || dec_auipc) ? dec_imm : rs2_data;

  core_alu alu_u (
    .op_i(dec_alu_op),
    .lhs_i(alu_lhs),
    .rhs_i(alu_rhs),
    .result_o(alu_result)
  );

  core_branch branch_u (
    .pc_i(ex_pc),
    .rs1_i(rs1_data),
    .rs2_i(rs2_data),
    .imm_i(dec_imm),
    .branch_i(dec_branch),
    .branch_op_i(dec_branch_op),
    .jal_i(dec_jal),
    .jalr_i(dec_jalr),
    .taken_o(branch_taken),
    .target_o(branch_target),
    .link_o(branch_link)
  );

  core_lsu lsu_u (
    .base_i(rs1_data),
    .imm_i(dec_imm),
    .store_data_i(rs2_data),
    .size_i(dec_lsu_size),
    .unsigned_i(dec_lsu_unsigned),
    .load_i(ex_valid && dec_load && !ex_fetch_fault && !dec_illegal),
    .store_i(ex_valid && dec_store && !ex_fetch_fault && !dec_illegal),
    .rsp_rdata_i(dmem_rsp_rdata_i),
    .rsp_err_i(dmem_rsp_err_i),
    .req_valid_o(dmem_req_valid_o),
    .req_addr_o(dmem_req_addr_o),
    .req_write_o(dmem_req_write_o),
    .req_size_o(dmem_req_size_o),
    .req_wdata_o(dmem_req_wdata_o),
    .req_wstrb_o(dmem_req_wstrb_o),
    .load_data_o(lsu_load_data),
    .misaligned_o(lsu_misaligned),
    .fault_o(lsu_fault)
  );

  assign auipc_result = ex_pc + dec_imm;
  assign lsu_active_fault = (dec_load || dec_store) && lsu_fault;
  assign redirect_valid = ex_valid && branch_taken && !ex_fetch_fault &&
                          !dec_illegal && !lsu_active_fault;

  // Select writeback source for the instruction classes integrated in this
  // milestone. Unsupported classes are allowed through decode for observability
  // but suppress architectural writeback below.
  always_comb begin
    wb_sel = CORE_WB_ALU;
    if (dec_lui) begin
      wb_sel = CORE_WB_IMM;
    end else if (dec_load) begin
      wb_sel = CORE_WB_LOAD;
    end else if (dec_jal || dec_jalr) begin
      wb_sel = CORE_WB_PC4;
    end else begin
      wb_sel = CORE_WB_ALU;
    end
  end

  assign unsupported = dec_csr || dec_ecall || dec_ebreak || dec_mret;
  assign wb_rd_write = dec_writes_rd && (dec_alu_valid || dec_lui ||
                       dec_auipc || dec_jal || dec_jalr || dec_load);
  assign write_fault = ex_fetch_fault || dec_illegal || unsupported ||
                       lsu_active_fault;

  core_wb wb_u (
    .wb_valid_i(ex_valid),
    .rd_i(dec_rd),
    .rd_write_i(wb_rd_write),
    .wb_sel_i(wb_sel),
    .trap_i(1'b0),
    .fault_i(write_fault),
    .alu_result_i(dec_auipc ? auipc_result : alu_result),
    .load_data_i(lsu_load_data),
    .csr_rdata_i(32'h0000_0000),
    .pc_plus4_i(branch_link),
    .imm_u_i(dec_imm),
    .rf_we_o(rf_we),
    .rf_waddr_o(rf_waddr),
    .rf_wdata_o(rf_wdata)
  );

  assign commit_valid_o = rf_we;
  assign commit_rd_o = rf_waddr;
  assign commit_data_o = rf_wdata;
  assign ex_valid_o = ex_valid;
  assign ex_pc_o = ex_pc;
  assign ex_instr_o = ex_instr;
  assign illegal_o = ex_valid && dec_illegal;
  assign lsu_fault_o = ex_valid && lsu_active_fault;
  assign unsupported_o = ex_valid && unsupported;

  // These decoded controls are intentionally unused in this staged datapath.
  // Keeping them named documents the integration boundary for the next steps.
  logic unused_decode_controls;
  assign unused_decode_controls = id_valid ^ id_pc[0] ^ id_instr[0] ^
                                  id_fetch_fault ^ dec_uses_rs1 ^
                                  dec_uses_rs2 ^ lsu_misaligned ^
                                  dec_csr_cmd[0] ^ dec_csr_addr[0] ^
                                  dec_imm_sel[0];
endmodule
