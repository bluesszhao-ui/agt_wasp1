`timescale 1ns/1ps

// First executable integer datapath integration for the wasp1 core.
//
// This milestone wires the verified pipeline skeleton, decoder, register file,
// ALU, and writeback helper into one small executable path. It intentionally
// supports integer ALU, upper-immediate, branch/jump redirect, CSR/trap,
// single-cycle load/store requests, and load-use hazard control.
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
  input  logic        timer_irq_i,        // Machine timer interrupt pending.
  input  logic        external_irq_i,     // Machine external interrupt pending.

  output logic        commit_valid_o,     // Register writeback happened this cycle.
  output logic [4:0]  commit_rd_o,        // Committed destination register.
  output logic [31:0] commit_data_o,      // Committed writeback data.
  output logic        ex_valid_o,         // Execute/writeback slot is valid.
  output logic [31:0] ex_pc_o,            // Execute/writeback slot PC.
  output logic [31:0] ex_instr_o,         // Execute/writeback slot instruction.
  output logic        illegal_o,          // Decode reported illegal instruction.
  output logic        lsu_fault_o,        // Load/store misalignment or response fault.
  output logic        trap_valid_o,       // Trap entry selected for current EX slot.
  output logic        trap_interrupt_o,   // Trap is an interrupt when asserted.
  output logic [4:0]  trap_cause_o,       // Trap cause without interrupt MSB.
  output logic [31:0] trap_tval_o,        // Trap value written to mtval.
  output logic [31:0] trap_pc_o,          // Trap PC written to mepc.
  output logic        mret_taken_o,       // MRET redirect selected.
  output logic [31:0] csr_rdata_o,        // CSR read data observed by writeback.
  output logic        hazard_load_use_o,  // Decode slot is stalled behind EX load.
  output logic        hazard_fwd_rs1_ex_o,// Hazard unit rs1 EX-forward decision.
  output logic        hazard_fwd_rs1_wb_o,// Hazard unit rs1 WB-forward decision.
  output logic        hazard_fwd_rs2_ex_o,// Hazard unit rs2 EX-forward decision.
  output logic        hazard_fwd_rs2_wb_o,// Hazard unit rs2 WB-forward decision.
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

  logic [4:0]  id_dec_rd;         // Destination register decoded from ID instruction.
  logic [4:0]  id_dec_rs1;        // Source register 1 decoded from ID instruction.
  logic [4:0]  id_dec_rs2;        // Source register 2 decoded from ID instruction.
  logic [31:0] id_dec_imm;        // ID immediate, unused by hazard.
  core_imm_sel_e id_dec_imm_sel;  // ID immediate format, unused by hazard.
  logic        id_dec_uses_rs1;   // ID instruction consumes rs1.
  logic        id_dec_uses_rs2;   // ID instruction consumes rs2.
  logic        id_dec_writes_rd;  // ID instruction writes rd.
  logic        id_dec_alu_valid;  // ID ALU qualifier, unused by hazard.
  core_alu_op_e id_dec_alu_op;    // ID ALU op, unused by hazard.
  logic        id_dec_alu_src_imm;// ID ALU immediate flag, unused by hazard.
  logic        id_dec_load;       // ID load qualifier, unused by hazard.
  logic        id_dec_store;      // ID store qualifier, unused by hazard.
  core_lsu_size_e id_dec_lsu_size;// ID LSU size, unused by hazard.
  logic        id_dec_lsu_unsigned;// ID LSU unsigned flag, unused by hazard.
  logic        id_dec_branch;     // ID branch qualifier, unused by hazard.
  core_branch_e id_dec_branch_op; // ID branch op, unused by hazard.
  logic        id_dec_jal;        // ID JAL qualifier, unused by hazard.
  logic        id_dec_jalr;       // ID JALR qualifier, unused by hazard.
  logic        id_dec_lui;        // ID LUI qualifier, unused by hazard.
  logic        id_dec_auipc;      // ID AUIPC qualifier, unused by hazard.
  logic        id_dec_csr;        // ID CSR qualifier, unused by hazard.
  core_csr_cmd_e id_dec_csr_cmd;  // ID CSR command, unused by hazard.
  logic [11:0] id_dec_csr_addr;   // ID CSR address, unused by hazard.
  logic        id_dec_ecall;      // ID ECALL qualifier, unused by hazard.
  logic        id_dec_ebreak;     // ID EBREAK qualifier, unused by hazard.
  logic        id_dec_mret;       // ID MRET qualifier, unused by hazard.
  logic        id_dec_illegal;    // ID illegal decode, unused by hazard.

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
  logic        pipe_redirect_valid;// Final redirect request into core_pipe.
  logic [31:0] pipe_redirect_pc;   // Final redirect target into core_pipe.
  logic [31:0] lsu_load_data;     // Load data after byte/half extension.
  logic        lsu_misaligned;    // Load/store alignment fault from LSU.
  logic        lsu_fault;         // Combined local/memory LSU helper fault.
  logic        lsu_active_fault;  // LSU fault qualified by a load/store op.
  logic [31:0] csr_wdata;         // CSR write data from rs1 or zero-extended zimm.
  logic [31:0] csr_rdata;         // CSR old value returned for rd writeback.
  logic        csr_illegal;       // CSR access fault from core_csr.
  logic [31:0] mtvec;             // Trap vector base from core_csr.
  logic [31:0] mepc;              // MRET target from core_csr.
  logic        mie_global;        // Global M-mode interrupt enable.
  logic        mtie;              // Timer interrupt enable.
  logic        meie;              // External interrupt enable.
  logic        mtip;              // Timer interrupt pending reflection.
  logic        meip;              // External interrupt pending reflection.
  logic        trap_valid;        // Trap selected by core_trap.
  logic        trap_interrupt;    // Trap is interrupt.
  logic [4:0]  trap_cause;        // Trap cause without interrupt MSB.
  logic [31:0] trap_tval;         // Trap value for mtval.
  logic [31:0] trap_pc;           // Trap PC for mepc.
  logic        mret_taken;        // MRET redirect selected.
  logic        trap_redirect;     // Trap/MRET redirect selected by core_trap.
  logic [31:0] trap_redirect_pc;  // Trap/MRET redirect target.
  logic [31:0] auipc_result;      // PC-relative AUIPC result.
  core_wb_sel_e wb_sel;           // Writeback source selector.
  logic        wb_rd_write;       // Final write intent before x0/fault suppression.
  logic        rf_we;             // Register file write enable from writeback helper.
  logic [4:0]  rf_waddr;          // Register file write address.
  logic [31:0] rf_wdata;          // Register file write data.
  logic        unsupported;       // Instruction class not connected yet.
  logic        write_fault;       // Any condition that suppresses architectural writeback.
  logic        hazard_rs1_fwd_ex; // Hazard unit rs1 EX-forward indication.
  logic        hazard_rs1_fwd_wb; // Hazard unit rs1 WB-forward indication.
  logic        hazard_rs2_fwd_ex; // Hazard unit rs2 EX-forward indication.
  logic        hazard_rs2_fwd_wb; // Hazard unit rs2 WB-forward indication.
  logic        hazard_load_use;   // Load-use hazard between ID and EX.
  logic        hazard_fetch_stall;// Fetch stall from hazard unit.
  logic        hazard_decode_stall;// Decode stall from hazard unit.
  logic        hazard_execute_bubble;// Execute bubble from hazard unit.

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
    .fetch_stall_i(hazard_fetch_stall),
    .decode_stall_i(hazard_decode_stall),
    .execute_bubble_i(hazard_execute_bubble),
    .redirect_valid_i(pipe_redirect_valid),
    .redirect_pc_i(pipe_redirect_pc),
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

  core_decode id_decode_u (
    .instr_i(id_instr),
    .rd_o(id_dec_rd),
    .rs1_o(id_dec_rs1),
    .rs2_o(id_dec_rs2),
    .imm_o(id_dec_imm),
    .imm_sel_o(id_dec_imm_sel),
    .uses_rs1_o(id_dec_uses_rs1),
    .uses_rs2_o(id_dec_uses_rs2),
    .writes_rd_o(id_dec_writes_rd),
    .alu_valid_o(id_dec_alu_valid),
    .alu_op_o(id_dec_alu_op),
    .alu_src_imm_o(id_dec_alu_src_imm),
    .load_o(id_dec_load),
    .store_o(id_dec_store),
    .lsu_size_o(id_dec_lsu_size),
    .lsu_unsigned_o(id_dec_lsu_unsigned),
    .branch_o(id_dec_branch),
    .branch_op_o(id_dec_branch_op),
    .jal_o(id_dec_jal),
    .jalr_o(id_dec_jalr),
    .lui_o(id_dec_lui),
    .auipc_o(id_dec_auipc),
    .csr_o(id_dec_csr),
    .csr_cmd_o(id_dec_csr_cmd),
    .csr_addr_o(id_dec_csr_addr),
    .ecall_o(id_dec_ecall),
    .ebreak_o(id_dec_ebreak),
    .mret_o(id_dec_mret),
    .illegal_o(id_dec_illegal)
  );

  core_hazard hazard_u (
    .id_valid_i(id_valid && !id_fetch_fault),
    .id_rs1_i(id_dec_rs1),
    .id_uses_rs1_i(id_dec_uses_rs1),
    .id_rs2_i(id_dec_rs2),
    .id_uses_rs2_i(id_dec_uses_rs2),
    .ex_valid_i(ex_valid && !ex_fetch_fault),
    .ex_rd_i(dec_rd),
    .ex_writes_rd_i(wb_rd_write && !write_fault && !trap_valid && !mret_taken),
    .ex_is_load_i(dec_load),
    .wb_valid_i(rf_we),
    .wb_rd_i(rf_waddr),
    .wb_writes_rd_i(rf_we),
    .rs1_forward_ex_o(hazard_rs1_fwd_ex),
    .rs1_forward_wb_o(hazard_rs1_fwd_wb),
    .rs2_forward_ex_o(hazard_rs2_fwd_ex),
    .rs2_forward_wb_o(hazard_rs2_fwd_wb),
    .load_use_stall_o(hazard_load_use),
    .fetch_stall_o(hazard_fetch_stall),
    .decode_stall_o(hazard_decode_stall),
    .execute_bubble_o(hazard_execute_bubble)
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

  assign csr_wdata = dec_csr_cmd[2] ? dec_imm : rs1_data;

  core_csr csr_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .csr_valid_i(ex_valid && dec_csr && !ex_fetch_fault && !dec_illegal),
    .csr_cmd_i(dec_csr_cmd),
    .csr_addr_i(dec_csr_addr),
    .csr_wdata_i(csr_wdata),
    .csr_rdata_o(csr_rdata),
    .csr_illegal_o(csr_illegal),
    .retire_i(ex_valid && !write_fault && !trap_valid),
    .trap_valid_i(trap_valid),
    .trap_interrupt_i(trap_interrupt),
    .trap_cause_i(trap_cause),
    .trap_pc_i(trap_pc),
    .trap_tval_i(trap_tval),
    .mret_i(ex_valid && mret_taken),
    .timer_irq_i(timer_irq_i),
    .external_irq_i(external_irq_i),
    .mtvec_o(mtvec),
    .mepc_o(mepc),
    .mie_global_o(mie_global),
    .mtie_o(mtie),
    .meie_o(meie),
    .mtip_o(mtip),
    .meip_o(meip)
  );

  core_trap trap_u (
    .valid_i(ex_valid),
    .pc_i(ex_pc),
    .instr_i(ex_instr),
    .instr_misaligned_i(1'b0),
    .instr_fault_addr_i(32'h0000_0000),
    .illegal_instr_i(dec_illegal),
    .csr_illegal_i(csr_illegal),
    .ecall_i(dec_ecall),
    .ebreak_i(dec_ebreak),
    .load_i(dec_load),
    .store_i(dec_store),
    .lsu_misaligned_i(lsu_misaligned),
    .lsu_fault_addr_i(dmem_req_addr_o),
    .mret_i(dec_mret),
    .mie_global_i(mie_global),
    .mtie_i(mtie),
    .meie_i(meie),
    .mtip_i(mtip),
    .meip_i(meip),
    .mtvec_i(mtvec),
    .mepc_i(mepc),
    .trap_valid_o(trap_valid),
    .trap_interrupt_o(trap_interrupt),
    .trap_cause_o(trap_cause),
    .trap_tval_o(trap_tval),
    .trap_pc_o(trap_pc),
    .mret_taken_o(mret_taken),
    .redirect_valid_o(trap_redirect),
    .redirect_pc_o(trap_redirect_pc)
  );

  assign auipc_result = ex_pc + dec_imm;
  assign lsu_active_fault = (dec_load || dec_store) && lsu_fault;
  assign redirect_valid = ex_valid && branch_taken && !ex_fetch_fault &&
                          !dec_illegal && !lsu_active_fault;
  assign pipe_redirect_valid = trap_redirect || redirect_valid;
  assign pipe_redirect_pc = trap_redirect ? trap_redirect_pc : branch_target;

  // Select writeback source for the instruction classes integrated in this
  // milestone. Unsupported classes are allowed through decode for observability
  // but suppress architectural writeback below.
  always_comb begin
    wb_sel = CORE_WB_ALU;
    if (dec_lui) begin
      wb_sel = CORE_WB_IMM;
    end else if (dec_load) begin
      wb_sel = CORE_WB_LOAD;
    end else if (dec_csr) begin
      wb_sel = CORE_WB_CSR;
    end else if (dec_jal || dec_jalr) begin
      wb_sel = CORE_WB_PC4;
    end else begin
      wb_sel = CORE_WB_ALU;
    end
  end

  assign unsupported = 1'b0;
  assign wb_rd_write = dec_writes_rd && (dec_alu_valid || dec_lui ||
                       dec_auipc || dec_jal || dec_jalr || dec_load ||
                       dec_csr);
  assign write_fault = ex_fetch_fault || dec_illegal || unsupported ||
                       lsu_active_fault || csr_illegal;

  core_wb wb_u (
    .wb_valid_i(ex_valid),
    .rd_i(dec_rd),
    .rd_write_i(wb_rd_write),
    .wb_sel_i(wb_sel),
    .trap_i(trap_valid || mret_taken),
    .fault_i(write_fault),
    .alu_result_i(dec_auipc ? auipc_result : alu_result),
    .load_data_i(lsu_load_data),
    .csr_rdata_i(csr_rdata),
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
  assign trap_valid_o = trap_valid;
  assign trap_interrupt_o = trap_interrupt;
  assign trap_cause_o = trap_cause;
  assign trap_tval_o = trap_tval;
  assign trap_pc_o = trap_pc;
  assign mret_taken_o = mret_taken;
  assign csr_rdata_o = csr_rdata;
  assign hazard_load_use_o = hazard_load_use;
  assign hazard_fwd_rs1_ex_o = hazard_rs1_fwd_ex;
  assign hazard_fwd_rs1_wb_o = hazard_rs1_fwd_wb;
  assign hazard_fwd_rs2_ex_o = hazard_rs2_fwd_ex;
  assign hazard_fwd_rs2_wb_o = hazard_rs2_fwd_wb;
  assign unsupported_o = ex_valid && unsupported;

  // These decoded controls are intentionally unused in this staged datapath.
  // Keeping them named documents the integration boundary for the next steps.
  logic unused_decode_controls;
  assign unused_decode_controls = id_pc[0] ^ id_dec_rd[0] ^ id_dec_imm[0] ^
                                  id_dec_imm_sel[0] ^ id_dec_writes_rd ^
                                  id_dec_alu_valid ^ id_dec_alu_op[0] ^
                                  id_dec_alu_src_imm ^ id_dec_load ^
                                  id_dec_store ^ id_dec_lsu_size[0] ^
                                  id_dec_lsu_unsigned ^ id_dec_branch ^
                                  id_dec_branch_op[0] ^ id_dec_jal ^
                                  id_dec_jalr ^ id_dec_lui ^
                                  id_dec_auipc ^ id_dec_csr ^
                                  id_dec_csr_cmd[0] ^ id_dec_csr_addr[0] ^
                                  id_dec_ecall ^ id_dec_ebreak ^
                                  id_dec_mret ^ id_dec_illegal ^
                                  dec_uses_rs1 ^ dec_uses_rs2 ^
                                  lsu_misaligned ^ dec_csr_cmd[0] ^
                                  dec_csr_addr[0] ^ dec_imm_sel[0];
endmodule
