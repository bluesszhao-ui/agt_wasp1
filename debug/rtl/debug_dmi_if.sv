`timescale 1ns/1ps

// Ready/valid Debug Module Interface between the JTAG DTM and Debug Module.
interface debug_dmi_if #(
  parameter int ADDR_WIDTH = debug_dmi_pkg::DMI_ADDR_WIDTH
) (
  input logic clk,
  input logic rst_n
);
  // Request channel; fields remain stable while req_valid is held without ready.
  logic                  req_valid;
  logic                  req_ready;
  logic [1:0]            req_op;
  logic [ADDR_WIDTH-1:0] req_addr;
  logic [31:0]           req_data;

  // Response channel; fields remain stable while rsp_valid is held without ready.
  logic                  rsp_valid;
  logic                  rsp_ready;
  logic [1:0]            rsp_resp;
  logic [31:0]           rsp_data;

  // DTM drives requests and consumes responses.
  modport dtm (
    input  clk,
    input  rst_n,
    input  req_ready,
    input  rsp_valid,
    input  rsp_resp,
    input  rsp_data,
    output req_valid,
    output req_op,
    output req_addr,
    output req_data,
    output rsp_ready
  );

  // Debug Module consumes requests and produces responses.
  modport dm (
    input  clk,
    input  rst_n,
    input  req_valid,
    input  req_op,
    input  req_addr,
    input  req_data,
    input  rsp_ready,
    output req_ready,
    output rsp_valid,
    output rsp_resp,
    output rsp_data
  );

  // Passive verification view of both handshake channels.
  modport monitor (
    input clk,
    input rst_n,
    input req_valid,
    input req_ready,
    input req_op,
    input req_addr,
    input req_data,
    input rsp_valid,
    input rsp_ready,
    input rsp_resp,
    input rsp_data
  );
endinterface
