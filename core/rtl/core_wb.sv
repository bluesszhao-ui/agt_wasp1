`timescale 1ns/1ps

// Core register writeback helper.
//
// This combinational module centralizes the final value selection and write
// enable qualification for the integer register file. It has no architectural
// state; core_pipe will provide the writeback-stage valid bit and exception
// qualifiers.
module core_wb (
  input  logic                         wb_valid_i,       // Writeback-stage instruction is valid.
  input  logic [4:0]                   rd_i,             // Destination integer register address.
  input  logic                         rd_write_i,       // Decoded instruction intends to write rd.
  input  core_types_pkg::core_wb_sel_e wb_sel_i,         // Selects the source value for rd.
  input  logic                         trap_i,           // Trap/exception suppresses architectural writeback.
  input  logic                         fault_i,          // Late memory/CSR fault suppresses writeback.

  input  logic [31:0]                  alu_result_i,     // ALU or address-generation result.
  input  logic [31:0]                  load_data_i,      // Formatted load result from core_lsu.
  input  logic [31:0]                  csr_rdata_i,      // Old CSR value returned by core_csr.
  input  logic [31:0]                  pc_plus4_i,       // Return address for JAL/JALR.
  input  logic [31:0]                  imm_u_i,          // Upper immediate value for LUI.

  output logic                         rf_we_o,          // Final integer register file write enable.
  output logic [4:0]                   rf_waddr_o,       // Final integer register file write address.
  output logic [31:0]                  rf_wdata_o        // Final integer register file write data.
);
  import core_types_pkg::*;

  logic writes_nonzero_rd; // rd write request after x0 suppression.
  logic write_allowed;     // Final architectural writeback qualifier.

  // x0 is architecturally hardwired to zero, so writes to x0 are dropped here
  // even if decode marks the instruction as writing rd.
  assign writes_nonzero_rd = rd_write_i && (rd_i != 5'd0);

  // Faulting or trapping instructions must not update the integer register
  // file. The CSR/trap path updates CSRs separately before redirecting.
  assign write_allowed = wb_valid_i && writes_nonzero_rd && !trap_i && !fault_i;

  assign rf_we_o = write_allowed;
  assign rf_waddr_o = rd_i;

  // Select the value that will be written to rd. The default ALU path covers
  // arithmetic, logic, comparisons, address computations, and AUIPC.
  always_comb begin
    unique case (wb_sel_i)
      CORE_WB_LOAD: rf_wdata_o = load_data_i;
      CORE_WB_CSR:  rf_wdata_o = csr_rdata_i;
      CORE_WB_PC4:  rf_wdata_o = pc_plus4_i;
      CORE_WB_IMM:  rf_wdata_o = imm_u_i;
      default:      rf_wdata_o = alu_result_i;
    endcase
  end
endmodule
