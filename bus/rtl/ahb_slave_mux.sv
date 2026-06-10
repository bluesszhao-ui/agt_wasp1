`timescale 1ns/1ps

module ahb_slave_mux #(
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter int SLAVE_COUNT = wasp1_pkg::AHB_SLAVE_COUNT
) (
  input  logic [SLAVE_COUNT-1:0]            hsel_i,
  input  logic [SLAVE_COUNT-1:0][DATA_WIDTH-1:0] slave_hrdata_i,
  input  logic [SLAVE_COUNT-1:0]            slave_hready_i,
  input  logic [SLAVE_COUNT-1:0]            slave_hresp_i,
  output logic [DATA_WIDTH-1:0]             hrdata_o,
  output logic                              hready_o,
  output logic                              hresp_o,
  output logic                              select_err_o
);
  import wasp1_pkg::*;

  logic any_sel;
  logic onehot_sel;

  assign any_sel = |hsel_i;
  assign onehot_sel = $onehot(hsel_i);
  assign select_err_o = any_sel && !onehot_sel;

  always_comb begin
    hrdata_o = '0;
    hready_o = 1'b1;
    hresp_o = AHB_HRESP_OKAY;

    if (select_err_o) begin
      hresp_o = AHB_HRESP_ERROR;
    end else begin
      for (int idx = 0; idx < SLAVE_COUNT; idx++) begin
        if (hsel_i[idx]) begin
          hrdata_o = slave_hrdata_i[idx];
          hready_o = slave_hready_i[idx];
          hresp_o = slave_hresp_i[idx];
        end
      end
    end
  end
endmodule
