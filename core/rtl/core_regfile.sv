`timescale 1ns/1ps

module core_regfile (
  input  logic        clk_i,
  input  logic        rst_ni,

  input  logic [4:0]  raddr1_i,
  output logic [31:0] rdata1_o,
  input  logic [4:0]  raddr2_i,
  output logic [31:0] rdata2_o,

  input  logic        we_i,
  input  logic [4:0]  waddr_i,
  input  logic [31:0] wdata_i
);
  logic [31:0] regs_q [31:1];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      for (int unsigned idx = 1; idx < 32; idx++) begin
        regs_q[idx] <= 32'h0000_0000;
      end
    end else if (we_i && (waddr_i != 5'd0)) begin
      regs_q[waddr_i] <= wdata_i;
    end
  end

  always_comb begin
    if (raddr1_i == 5'd0) begin
      rdata1_o = 32'h0000_0000;
    end else if (we_i && (waddr_i == raddr1_i)) begin
      rdata1_o = wdata_i;
    end else begin
      rdata1_o = regs_q[raddr1_i];
    end
  end

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
