`timescale 1ns/1ps

// RV32I integer register file.
//
// Provides two combinational read ports and one rising-edge write port. The
// architectural x0 register is not physically stored and always reads as zero.
module core_regfile (
  input  logic        clk_i,    // Register write clock.
  input  logic        rst_ni,   // Active-low asynchronous reset for deterministic bring-up.

  input  logic [4:0]  raddr1_i, // Read port 1 architectural register address.
  output logic [31:0] rdata1_o, // Read port 1 data, including x0 and bypass handling.
  input  logic [4:0]  raddr2_i, // Read port 2 architectural register address.
  output logic [31:0] rdata2_o, // Read port 2 data, including x0 and bypass handling.

  input  logic        we_i,     // Write enable for x1-x31.
  input  logic [4:0]  waddr_i,  // Write architectural register address; x0 writes are ignored.
  input  logic [31:0] wdata_i   // Write data committed on clk_i rising edge.
);
  logic [31:0] regs_q [31:1]; // Physical storage for x1-x31 only.

  // Reset all stored registers for deterministic simulation and FPGA bring-up.
  // x0 is hardwired by the read muxes below, so it does not appear here.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned idx = 1; idx < 32; idx++) begin
        regs_q[idx] <= 32'h0000_0000;
      end
    end else if (we_i && (waddr_i != 5'd0)) begin
      regs_q[waddr_i] <= wdata_i;
    end
  end

  // Read port 1 priority: x0 zero, same-cycle write bypass, stored value.
  always_comb begin
    if (raddr1_i == 5'd0) begin
      rdata1_o = 32'h0000_0000;
    end else if (we_i && (waddr_i == raddr1_i)) begin
      rdata1_o = wdata_i;
    end else begin
      rdata1_o = regs_q[raddr1_i];
    end
  end

  // Read port 2 mirrors read port 1 behavior and is independent.
  always_comb begin
    if (raddr2_i == 5'd0) begin
      rdata2_o = 32'h0000_0000;
    end else if (we_i && (waddr_i == raddr2_i)) begin
      rdata2_o = wdata_i;
    end else begin
      rdata2_o = regs_q[raddr2_i];
    end
  end
endmodule
