`timescale 1ns/1ps

module ahb_fabric_2m #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter int SLAVE_COUNT = wasp1_pkg::AHB_SLAVE_COUNT,
  parameter int EXT_SLAVE_COUNT = wasp1_pkg::AHB_SLAVE_DEFAULT
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

  output logic [EXT_SLAVE_COUNT-1:0]            slave_hsel_o,
  output logic [ADDR_WIDTH-1:0]                 slave_haddr_o,
  output logic [1:0]                            slave_htrans_o,
  output logic                                  slave_hwrite_o,
  output logic [2:0]                            slave_hsize_o,
  output logic [2:0]                            slave_hburst_o,
  output logic [3:0]                            slave_hprot_o,
  output logic                                  slave_hmastlock_o,
  output logic [DATA_WIDTH-1:0]                 slave_hwdata_o,
  input  logic [EXT_SLAVE_COUNT-1:0][DATA_WIDTH-1:0] slave_hrdata_i,
  input  logic [EXT_SLAVE_COUNT-1:0]            slave_hready_i,
  input  logic [EXT_SLAVE_COUNT-1:0]            slave_hresp_i,

  output logic                                  grant_valid_o,
  output logic                                  grant_idx_o,
  output logic                                  default_sel_o,
  output logic                                  slave_select_err_o
);
  import wasp1_pkg::*;

  logic [ADDR_WIDTH-1:0] arb_haddr;
  logic [1:0]            arb_htrans;
  logic                  arb_hwrite;
  logic [2:0]            arb_hsize;
  logic [2:0]            arb_hburst;
  logic [3:0]            arb_hprot;
  logic                  arb_hmastlock;
  logic [DATA_WIDTH-1:0] arb_hwdata;
  logic [DATA_WIDTH-1:0] mux_hrdata;
  logic                  mux_hready;
  logic                  mux_hresp;

  logic [SLAVE_COUNT-1:0] decoder_hsel;
  logic [SLAVE_COUNT-1:0] data_hsel_q;
  logic [SLAVE_COUNT-1:0] mux_hsel;
  logic [SLAVE_COUNT-1:0][DATA_WIDTH-1:0] mux_slave_hrdata;
  logic [SLAVE_COUNT-1:0] mux_slave_hready;
  logic [SLAVE_COUNT-1:0] mux_slave_hresp;
  logic [DATA_WIDTH-1:0] default_hrdata;
  logic                  default_hready;
  logic                  default_hresp;
  logic                  default_resp_hold_q;

  ahb_arbiter_2m #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) u_ahb_arbiter_2m (
    .hclk_i(hclk_i),
    .hresetn_i(hresetn_i),
    .m0_haddr_i(m0_haddr_i),
    .m0_htrans_i(m0_htrans_i),
    .m0_hwrite_i(m0_hwrite_i),
    .m0_hsize_i(m0_hsize_i),
    .m0_hburst_i(m0_hburst_i),
    .m0_hprot_i(m0_hprot_i),
    .m0_hmastlock_i(m0_hmastlock_i),
    .m0_hwdata_i(m0_hwdata_i),
    .m0_hrdata_o(m0_hrdata_o),
    .m0_hready_o(m0_hready_o),
    .m0_hresp_o(m0_hresp_o),
    .m1_haddr_i(m1_haddr_i),
    .m1_htrans_i(m1_htrans_i),
    .m1_hwrite_i(m1_hwrite_i),
    .m1_hsize_i(m1_hsize_i),
    .m1_hburst_i(m1_hburst_i),
    .m1_hprot_i(m1_hprot_i),
    .m1_hmastlock_i(m1_hmastlock_i),
    .m1_hwdata_i(m1_hwdata_i),
    .m1_hrdata_o(m1_hrdata_o),
    .m1_hready_o(m1_hready_o),
    .m1_hresp_o(m1_hresp_o),
    .haddr_o(arb_haddr),
    .htrans_o(arb_htrans),
    .hwrite_o(arb_hwrite),
    .hsize_o(arb_hsize),
    .hburst_o(arb_hburst),
    .hprot_o(arb_hprot),
    .hmastlock_o(arb_hmastlock),
    .hwdata_o(arb_hwdata),
    .hrdata_i(mux_hrdata),
    .hready_i(mux_hready),
    .hresp_i(mux_hresp),
    .grant_valid_o(grant_valid_o),
    .grant_idx_o(grant_idx_o)
  );

  ahb_decoder #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .SLAVE_COUNT(SLAVE_COUNT)
  ) u_ahb_decoder (
    .haddr_i(arb_haddr),
    .active_i(arb_htrans[1]),
    .hsel_o(decoder_hsel),
    .default_sel_o(default_sel_o)
  );

  ahb_default_slave #(
    .DATA_WIDTH(DATA_WIDTH)
  ) u_ahb_default_slave (
    .hclk_i(hclk_i),
    .hresetn_i(hresetn_i),
    .hsel_i(decoder_hsel[AHB_SLAVE_DEFAULT]),
    .htrans_i(arb_htrans),
    .hwrite_i(arb_hwrite),
    .hsize_i(arb_hsize),
    .hwdata_i(arb_hwdata),
    .hrdata_o(default_hrdata),
    .hready_o(default_hready),
    .hresp_o(default_hresp)
  );

  always_comb begin
    mux_slave_hrdata = '0;
    mux_slave_hready = '1;
    mux_slave_hresp = '0;

    for (int idx = 0; idx < EXT_SLAVE_COUNT; idx++) begin
      mux_slave_hrdata[idx] = slave_hrdata_i[idx];
      mux_slave_hready[idx] = slave_hready_i[idx];
      mux_slave_hresp[idx] = slave_hresp_i[idx];
    end

    mux_slave_hrdata[AHB_SLAVE_DEFAULT] = default_hrdata;
    mux_slave_hready[AHB_SLAVE_DEFAULT] = default_hready;
    mux_slave_hresp[AHB_SLAVE_DEFAULT] = default_resp_hold_q;
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      data_hsel_q <= '0;
      default_resp_hold_q <= AHB_HRESP_OKAY;
    end else if (arb_htrans[1] && |decoder_hsel) begin
      data_hsel_q <= decoder_hsel;
      default_resp_hold_q <= decoder_hsel[AHB_SLAVE_DEFAULT] ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;
    end
  end

  logic unused_default_hresp;
  assign unused_default_hresp = default_hresp;

  // Slave response muxing uses the data-phase slave captured from the previous
  // address phase. The non-pipelined arbiter keeps the fabric idle until the
  // routed response is consumed, so this select remains stable for the whole
  // WAIT/RESP interval.
  assign mux_hsel = data_hsel_q;

  ahb_slave_mux #(
    .DATA_WIDTH(DATA_WIDTH),
    .SLAVE_COUNT(SLAVE_COUNT)
  ) u_ahb_slave_mux (
    .hsel_i(mux_hsel),
    .slave_hrdata_i(mux_slave_hrdata),
    .slave_hready_i(mux_slave_hready),
    .slave_hresp_i(mux_slave_hresp),
    .hrdata_o(mux_hrdata),
    .hready_o(mux_hready),
    .hresp_o(mux_hresp),
    .select_err_o(slave_select_err_o)
  );

  assign slave_hsel_o = decoder_hsel[EXT_SLAVE_COUNT-1:0];
  assign slave_haddr_o = arb_haddr;
  assign slave_htrans_o = arb_htrans;
  assign slave_hwrite_o = arb_hwrite;
  assign slave_hsize_o = arb_hsize;
  assign slave_hburst_o = arb_hburst;
  assign slave_hprot_o = arb_hprot;
  assign slave_hmastlock_o = arb_hmastlock;
  assign slave_hwdata_o = arb_hwdata;
endmodule
