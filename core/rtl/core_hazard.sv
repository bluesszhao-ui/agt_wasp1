`timescale 1ns/1ps

// Core hazard and forwarding helper.
//
// This combinational module detects classic load-use hazards between the decode
// slot and the execute slot, and selects EX/WB forwarding for rs1/rs2 operands.
// It does not contain pipeline state; core_pipe will use these controls to hold
// fetch/decode and insert an execute bubble.
module core_hazard (
  input  logic       id_valid_i,        // Decode-stage instruction is valid.
  input  logic [4:0] id_rs1_i,          // Decode-stage rs1 address.
  input  logic       id_uses_rs1_i,     // Decode-stage instruction consumes rs1.
  input  logic [4:0] id_rs2_i,          // Decode-stage rs2 address.
  input  logic       id_uses_rs2_i,     // Decode-stage instruction consumes rs2.

  input  logic       ex_valid_i,        // Execute-stage instruction is valid.
  input  logic [4:0] ex_rd_i,           // Execute-stage destination register.
  input  logic       ex_writes_rd_i,    // Execute-stage instruction writes rd.
  input  logic       ex_is_load_i,      // Execute-stage result is pending load data.

  input  logic       wb_valid_i,        // Writeback-stage instruction is valid.
  input  logic [4:0] wb_rd_i,           // Writeback-stage destination register.
  input  logic       wb_writes_rd_i,    // Writeback-stage instruction writes rd.

  output logic       rs1_forward_ex_o,  // Forward rs1 from execute result.
  output logic       rs1_forward_wb_o,  // Forward rs1 from writeback result.
  output logic       rs2_forward_ex_o,  // Forward rs2 from execute result.
  output logic       rs2_forward_wb_o,  // Forward rs2 from writeback result.
  output logic       load_use_stall_o,  // Decode depends on an execute-stage load.
  output logic       fetch_stall_o,     // Hold fetch while resolving load-use hazard.
  output logic       decode_stall_o,    // Hold decode while resolving load-use hazard.
  output logic       execute_bubble_o   // Insert a bubble into execute on load-use hazard.
);
  logic rs1_ex_match; // rs1 matches a nonzero execute destination.
  logic rs2_ex_match; // rs2 matches a nonzero execute destination.
  logic rs1_wb_match; // rs1 matches a nonzero writeback destination.
  logic rs2_wb_match; // rs2 matches a nonzero writeback destination.

  // Match only valid, writing instructions with nonzero rd. x0 is never a true
  // dependency because the register file hardwires it to zero.
  assign rs1_ex_match = id_valid_i && id_uses_rs1_i && ex_valid_i &&
                        ex_writes_rd_i && (ex_rd_i != 5'd0) &&
                        (id_rs1_i == ex_rd_i);
  assign rs2_ex_match = id_valid_i && id_uses_rs2_i && ex_valid_i &&
                        ex_writes_rd_i && (ex_rd_i != 5'd0) &&
                        (id_rs2_i == ex_rd_i);
  assign rs1_wb_match = id_valid_i && id_uses_rs1_i && wb_valid_i &&
                        wb_writes_rd_i && (wb_rd_i != 5'd0) &&
                        (id_rs1_i == wb_rd_i);
  assign rs2_wb_match = id_valid_i && id_uses_rs2_i && wb_valid_i &&
                        wb_writes_rd_i && (wb_rd_i != 5'd0) &&
                        (id_rs2_i == wb_rd_i);

  // ALU-like execute results can be forwarded immediately. Load results cannot
  // be forwarded from execute in this simple core because data arrives later.
  assign rs1_forward_ex_o = rs1_ex_match && !ex_is_load_i;
  assign rs2_forward_ex_o = rs2_ex_match && !ex_is_load_i;

  // Writeback forwarding is lower priority than execute forwarding. If both
  // stages target the same source register, the younger execute result wins.
  assign rs1_forward_wb_o = rs1_wb_match && !rs1_forward_ex_o;
  assign rs2_forward_wb_o = rs2_wb_match && !rs2_forward_ex_o;

  // A load-use hazard stalls fetch/decode and injects an execute bubble.
  assign load_use_stall_o = ex_is_load_i && (rs1_ex_match || rs2_ex_match);
  assign fetch_stall_o = load_use_stall_o;
  assign decode_stall_o = load_use_stall_o;
  assign execute_bubble_o = load_use_stall_o;
endmodule
