module ahb_default_slave #(
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH
) (
  input  logic                  hsel_i,
  input  logic [1:0]            htrans_i,
  input  logic                  hwrite_i,
  input  logic [2:0]            hsize_i,
  input  logic [DATA_WIDTH-1:0] hwdata_i,
  output logic [DATA_WIDTH-1:0] hrdata_o,
  output logic                  hready_o,
  output logic                  hresp_o
);
  import wasp1_pkg::*;

  logic active_transfer;

  assign active_transfer = hsel_i && htrans_i[1];
  assign hrdata_o = '0;
  assign hready_o = 1'b1;
  assign hresp_o = active_transfer ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

  logic unused_inputs;
  assign unused_inputs = hwrite_i ^ hsize_i[0] ^ hsize_i[1] ^ hsize_i[2] ^ ^hwdata_i;
endmodule
