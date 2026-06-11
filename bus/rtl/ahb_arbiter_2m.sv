`timescale 1ns/1ps

module ahb_arbiter_2m #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH
) (
  input  logic                  hclk_i,
  input  logic                  hresetn_i,

  input  logic [ADDR_WIDTH-1:0] m0_haddr_i,
  input  logic [1:0]            m0_htrans_i,
  input  logic                  m0_hwrite_i,
  input  logic [2:0]            m0_hsize_i,
  input  logic [2:0]            m0_hburst_i,
  input  logic [3:0]            m0_hprot_i,
  input  logic                  m0_hmastlock_i,
  input  logic [DATA_WIDTH-1:0] m0_hwdata_i,
  output logic [DATA_WIDTH-1:0] m0_hrdata_o,
  output logic                  m0_hready_o,
  output logic                  m0_hresp_o,

  input  logic [ADDR_WIDTH-1:0] m1_haddr_i,
  input  logic [1:0]            m1_htrans_i,
  input  logic                  m1_hwrite_i,
  input  logic [2:0]            m1_hsize_i,
  input  logic [2:0]            m1_hburst_i,
  input  logic [3:0]            m1_hprot_i,
  input  logic                  m1_hmastlock_i,
  input  logic [DATA_WIDTH-1:0] m1_hwdata_i,
  output logic [DATA_WIDTH-1:0] m1_hrdata_o,
  output logic                  m1_hready_o,
  output logic                  m1_hresp_o,

  output logic [ADDR_WIDTH-1:0] haddr_o,
  output logic [1:0]            htrans_o,
  output logic                  hwrite_o,
  output logic [2:0]            hsize_o,
  output logic [2:0]            hburst_o,
  output logic [3:0]            hprot_o,
  output logic                  hmastlock_o,
  output logic [DATA_WIDTH-1:0] hwdata_o,
  input  logic [DATA_WIDTH-1:0] hrdata_i,
  input  logic                  hready_i,
  input  logic                  hresp_i,

  output logic                  grant_valid_o,
  output logic                  grant_idx_o
);
  import wasp1_pkg::*;

  logic m0_req;
  logic m1_req;
  logic next_grant_valid;
  logic next_grant_idx;
  logic grant_valid_q;
  logic grant_idx_q;
  logic last_grant_q;

  assign m0_req = m0_htrans_i[1];
  assign m1_req = m1_htrans_i[1];

  always_comb begin
    next_grant_valid = m0_req || m1_req;
    next_grant_idx = grant_idx_q;

    unique case ({m1_req, m0_req})
      2'b01: next_grant_idx = 1'b0;
      2'b10: next_grant_idx = 1'b1;
      2'b11: next_grant_idx = (last_grant_q == 1'b0) ? 1'b1 : 1'b0;
      default: next_grant_idx = grant_idx_q;
    endcase
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      grant_valid_q <= 1'b0;
      grant_idx_q   <= 1'b0;
      last_grant_q  <= 1'b1;
    end else if (hready_i) begin
      grant_valid_q <= next_grant_valid;
      grant_idx_q   <= next_grant_idx;
      if (next_grant_valid) begin
        last_grant_q <= next_grant_idx;
      end
    end
  end

  always_comb begin
    haddr_o     = '0;
    htrans_o    = AHB_HTRANS_IDLE;
    hwrite_o    = 1'b0;
    hsize_o     = AHB_HSIZE_WORD;
    hburst_o    = AHB_HBURST_SINGLE;
    hprot_o     = 4'h0;
    hmastlock_o = 1'b0;
    hwdata_o    = '0;

    if (grant_valid_q && (grant_idx_q == 1'b0)) begin
      haddr_o     = m0_haddr_i;
      htrans_o    = m0_htrans_i;
      hwrite_o    = m0_hwrite_i;
      hsize_o     = m0_hsize_i;
      hburst_o    = m0_hburst_i;
      hprot_o     = m0_hprot_i;
      hmastlock_o = m0_hmastlock_i;
      hwdata_o    = m0_hwdata_i;
    end else if (grant_valid_q && (grant_idx_q == 1'b1)) begin
      haddr_o     = m1_haddr_i;
      htrans_o    = m1_htrans_i;
      hwrite_o    = m1_hwrite_i;
      hsize_o     = m1_hsize_i;
      hburst_o    = m1_hburst_i;
      hprot_o     = m1_hprot_i;
      hmastlock_o = m1_hmastlock_i;
      hwdata_o    = m1_hwdata_i;
    end
  end

  always_comb begin
    m0_hrdata_o = '0;
    m0_hready_o = !m0_req;
    m0_hresp_o  = AHB_HRESP_OKAY;
    m1_hrdata_o = '0;
    m1_hready_o = !m1_req;
    m1_hresp_o  = AHB_HRESP_OKAY;

    if (grant_valid_q && (grant_idx_q == 1'b0)) begin
      m0_hrdata_o = hrdata_i;
      m0_hready_o = hready_i;
      m0_hresp_o  = hresp_i;
    end else if (grant_valid_q && (grant_idx_q == 1'b1)) begin
      m1_hrdata_o = hrdata_i;
      m1_hready_o = hready_i;
      m1_hresp_o  = hresp_i;
    end
  end

  assign grant_valid_o = grant_valid_q;
  assign grant_idx_o = grant_idx_q;
endmodule
