`timescale 1ns/1ps

interface debug_if #(
  parameter int XLEN = 32 // Core integer register width carried by the GPR channel.
) (
  input logic clk,   // Shared core/debug handshake clock.
  input logic rst_n  // Active-low reset associated with the interface endpoints.
);
  // Hart execution control request and status signals.
  logic            halt_req;       // Debug Module requests entry into Debug Mode.
  logic            resume_req;     // Debug Module requests exit from Debug Mode.
  logic            step_req;       // Debug Module requests one instruction step.
  logic            halted;         // Core reports that it is halted in Debug Mode.
  logic            running;        // Core reports normal instruction execution.
  logic [XLEN-1:0] dpc;            // Debug PC captured by the core when it enters Debug Mode.

  // Ready/valid GPR access request from Debug Module to the halted core.
  logic            gpr_req_valid;  // Request fields are valid and held until ready.
  logic            gpr_req_ready;  // Core can accept the current GPR request.
  logic            gpr_req_write;  // One selects write; zero selects read.
  logic [4:0]      gpr_req_addr;   // RV32I integer register index x0-x31.
  logic [XLEN-1:0] gpr_req_wdata;  // Write payload, ignored for reads.

  // Ready/valid GPR response from the core back to the Debug Module.
  logic            gpr_rsp_valid;  // Response data/error are valid until ready.
  logic            gpr_rsp_ready;  // Debug Module can consume the response.
  logic [XLEN-1:0] gpr_rsp_rdata;  // Read result; zero/ignored for writes.
  logic            gpr_rsp_err;    // Core rejected or faulted the GPR operation.

  // Hart-control-only DM view for the independently owned halt controller.
  modport dm_ctrl (
    input  clk,
    input  rst_n,
    input  halted,
    input  running,
    input  dpc,
    output halt_req,
    output resume_req,
    output step_req
  );

  // GPR-only DM view prevents register-access logic from driving hart control.
  modport dm_gpr (
    input  clk,
    input  rst_n,
    input  gpr_req_ready,
    input  gpr_rsp_valid,
    input  gpr_rsp_rdata,
    input  gpr_rsp_err,
    output gpr_req_valid,
    output gpr_req_write,
    output gpr_req_addr,
    output gpr_req_wdata,
    output gpr_rsp_ready
  );

  modport dm (
    input  clk,
    input  rst_n,
    input  halted,
    input  running,
    input  dpc,
    input  gpr_req_ready,
    input  gpr_rsp_valid,
    input  gpr_rsp_rdata,
    input  gpr_rsp_err,
    output halt_req,
    output resume_req,
    output step_req,
    output gpr_req_valid,
    output gpr_req_write,
    output gpr_req_addr,
    output gpr_req_wdata,
    output gpr_rsp_ready
  );

  modport core (
    input  clk,
    input  rst_n,
    input  halt_req,
    input  resume_req,
    input  step_req,
    input  gpr_req_valid,
    input  gpr_req_write,
    input  gpr_req_addr,
    input  gpr_req_wdata,
    input  gpr_rsp_ready,
    output halted,
    output running,
    output dpc,
    output gpr_req_ready,
    output gpr_rsp_valid,
    output gpr_rsp_rdata,
    output gpr_rsp_err
  );

  modport monitor (
    input clk,
    input rst_n,
    input halt_req,
    input resume_req,
    input step_req,
    input halted,
    input running,
    input dpc,
    input gpr_req_valid,
    input gpr_req_ready,
    input gpr_req_write,
    input gpr_req_addr,
    input gpr_req_wdata,
    input gpr_rsp_valid,
    input gpr_rsp_ready,
    input gpr_rsp_rdata,
    input gpr_rsp_err
  );
endinterface
