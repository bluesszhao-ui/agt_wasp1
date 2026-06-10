`timescale 1ns/1ps

interface mem_req_rsp_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input logic clk,
  input logic rst_n
);
  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  logic                  req_valid;
  logic                  req_ready;
  logic [ADDR_WIDTH-1:0] req_addr;
  logic                  req_write;
  logic [1:0]            req_size;
  logic [DATA_WIDTH-1:0] req_wdata;
  logic [STRB_WIDTH-1:0] req_wstrb;
  logic                  req_instr;

  logic                  rsp_valid;
  logic                  rsp_ready;
  logic [DATA_WIDTH-1:0] rsp_rdata;
  logic                  rsp_err;

  modport initiator (
    input  clk,
    input  rst_n,
    input  req_ready,
    input  rsp_valid,
    input  rsp_rdata,
    input  rsp_err,
    output req_valid,
    output req_addr,
    output req_write,
    output req_size,
    output req_wdata,
    output req_wstrb,
    output req_instr,
    output rsp_ready
  );

  modport target (
    input  clk,
    input  rst_n,
    input  req_valid,
    input  req_addr,
    input  req_write,
    input  req_size,
    input  req_wdata,
    input  req_wstrb,
    input  req_instr,
    input  rsp_ready,
    output req_ready,
    output rsp_valid,
    output rsp_rdata,
    output rsp_err
  );

  modport monitor (
    input clk,
    input rst_n,
    input req_valid,
    input req_ready,
    input req_addr,
    input req_write,
    input req_size,
    input req_wdata,
    input req_wstrb,
    input req_instr,
    input rsp_valid,
    input rsp_ready,
    input rsp_rdata,
    input rsp_err
  );
endinterface
