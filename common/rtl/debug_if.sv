interface debug_if #(
  parameter int XLEN = 32
) (
  input logic clk,
  input logic rst_n
);
  logic            halt_req;
  logic            resume_req;
  logic            step_req;
  logic            halted;
  logic            running;

  logic            gpr_req_valid;
  logic            gpr_req_ready;
  logic            gpr_req_write;
  logic [4:0]      gpr_req_addr;
  logic [XLEN-1:0] gpr_req_wdata;
  logic            gpr_rsp_valid;
  logic            gpr_rsp_ready;
  logic [XLEN-1:0] gpr_rsp_rdata;
  logic            gpr_rsp_err;

  modport dm (
    input  clk,
    input  rst_n,
    input  halted,
    input  running,
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
