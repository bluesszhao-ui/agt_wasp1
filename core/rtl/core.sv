`timescale 1ns/1ps

// wasp1 first core top-level wrapper.
//
// This module establishes the first stable `core` boundary for the SoC.  The
// current implementation delegates execution to `core_int_datapath`, preserving
// lightweight valid/ready instruction and data-memory interfaces that later
// frontend, I-cache, D-cache, tile, and debug integration stages can connect to.
module core (
  input  logic        clk_i,              // Core clock for all sequential state.
  input  logic        rst_ni,             // Active-low asynchronous core reset.

  input  logic [31:0] boot_pc_i,          // Reset fetch PC, normally OTP_BASE.

  output logic        if_req_valid_o,     // Fetch request valid toward frontend.
  output logic [31:0] if_req_pc_o,        // Fetch request PC in byte address form.
  input  logic        if_rsp_valid_i,     // Frontend instruction response valid.
  output logic        if_rsp_ready_o,     // Core can accept the instruction response.
  input  logic [31:0] if_rsp_instr_i,     // Fetched 32-bit instruction word.
  input  logic        if_rsp_fault_i,     // Fetch fault for this instruction response.

  output logic        dmem_req_valid_o,   // Data-memory request valid.
  output logic [31:0] dmem_req_addr_o,    // Data-memory byte address.
  output logic        dmem_req_write_o,   // Store when high, load when low.
  output logic [1:0]  dmem_req_size_o,    // Access size: byte, halfword, or word.
  output logic [31:0] dmem_req_wdata_o,   // Store data aligned to byte lanes.
  output logic [3:0]  dmem_req_wstrb_o,   // Store byte write strobes.
  input  logic [31:0] dmem_rsp_rdata_i,   // Data-memory read response data.
  input  logic        dmem_rsp_err_i,     // Data-memory response error.

  input  logic        timer_irq_i,        // Machine timer interrupt pending input.
  input  logic        external_irq_i,     // Machine external interrupt pending input.

  output logic        commit_valid_o,     // Architectural register writeback valid.
  output logic [4:0]  commit_rd_o,        // Architectural destination register.
  output logic [31:0] commit_data_o,      // Architectural writeback data.
  output logic        ex_valid_o,         // Execute/writeback slot valid indicator.
  output logic [31:0] ex_pc_o,            // Execute/writeback slot PC.
  output logic [31:0] ex_instr_o,         // Execute/writeback slot instruction.
  output logic        illegal_o,          // Illegal instruction indication.
  output logic        lsu_fault_o,        // Load/store alignment or response fault.
  output logic        trap_valid_o,       // Trap entry selected for current slot.
  output logic        trap_interrupt_o,   // Trap is interrupt rather than exception.
  output logic [4:0]  trap_cause_o,       // Trap cause without interrupt MSB.
  output logic [31:0] trap_tval_o,        // Trap value written to mtval.
  output logic [31:0] trap_pc_o,          // Trap PC written to mepc.
  output logic        mret_taken_o,       // MRET redirect selected.
  output logic [31:0] csr_rdata_o,        // CSR read data observed by writeback.
  output logic        hazard_load_use_o,  // Load-use stall indication.
  output logic        hazard_fwd_rs1_ex_o,// Hazard unit rs1 EX-forward decision.
  output logic        hazard_fwd_rs1_wb_o,// Hazard unit rs1 WB-forward decision.
  output logic        hazard_fwd_rs2_ex_o,// Hazard unit rs2 EX-forward decision.
  output logic        hazard_fwd_rs2_wb_o,// Hazard unit rs2 WB-forward decision.
  output logic        unsupported_o       // Unsupported instruction class indication.
);
  core_int_datapath datapath_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .boot_pc_i(boot_pc_i),
    .if_req_valid_o(if_req_valid_o),
    .if_req_pc_o(if_req_pc_o),
    .if_rsp_valid_i(if_rsp_valid_i),
    .if_rsp_ready_o(if_rsp_ready_o),
    .if_rsp_instr_i(if_rsp_instr_i),
    .if_rsp_fault_i(if_rsp_fault_i),
    .dmem_req_valid_o(dmem_req_valid_o),
    .dmem_req_addr_o(dmem_req_addr_o),
    .dmem_req_write_o(dmem_req_write_o),
    .dmem_req_size_o(dmem_req_size_o),
    .dmem_req_wdata_o(dmem_req_wdata_o),
    .dmem_req_wstrb_o(dmem_req_wstrb_o),
    .dmem_rsp_rdata_i(dmem_rsp_rdata_i),
    .dmem_rsp_err_i(dmem_rsp_err_i),
    .timer_irq_i(timer_irq_i),
    .external_irq_i(external_irq_i),
    .commit_valid_o(commit_valid_o),
    .commit_rd_o(commit_rd_o),
    .commit_data_o(commit_data_o),
    .ex_valid_o(ex_valid_o),
    .ex_pc_o(ex_pc_o),
    .ex_instr_o(ex_instr_o),
    .illegal_o(illegal_o),
    .lsu_fault_o(lsu_fault_o),
    .trap_valid_o(trap_valid_o),
    .trap_interrupt_o(trap_interrupt_o),
    .trap_cause_o(trap_cause_o),
    .trap_tval_o(trap_tval_o),
    .trap_pc_o(trap_pc_o),
    .mret_taken_o(mret_taken_o),
    .csr_rdata_o(csr_rdata_o),
    .hazard_load_use_o(hazard_load_use_o),
    .hazard_fwd_rs1_ex_o(hazard_fwd_rs1_ex_o),
    .hazard_fwd_rs1_wb_o(hazard_fwd_rs1_wb_o),
    .hazard_fwd_rs2_ex_o(hazard_fwd_rs2_ex_o),
    .hazard_fwd_rs2_wb_o(hazard_fwd_rs2_wb_o),
    .unsupported_o(unsupported_o)
  );
endmodule
