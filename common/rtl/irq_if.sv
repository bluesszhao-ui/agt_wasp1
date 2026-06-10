`timescale 1ns/1ps

interface irq_if #(
  parameter int IRQ_COUNT = 1
) (
  input logic clk,
  input logic rst_n
);
  logic [IRQ_COUNT-1:0] irq;

  modport source (
    input  clk,
    input  rst_n,
    output irq
  );

  modport sink (
    input clk,
    input rst_n,
    input irq
  );

  modport monitor (
    input clk,
    input rst_n,
    input irq
  );
endinterface
