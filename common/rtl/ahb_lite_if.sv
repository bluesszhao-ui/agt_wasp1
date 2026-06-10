interface ahb_lite_if #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32
) (
  input logic hclk,
  input logic hresetn
);
  logic                    hsel;
  logic [ADDR_WIDTH-1:0]   haddr;
  logic [1:0]              htrans;
  logic                    hwrite;
  logic [2:0]              hsize;
  logic [2:0]              hburst;
  logic [3:0]              hprot;
  logic                    hmastlock;
  logic [DATA_WIDTH-1:0]   hwdata;
  logic [DATA_WIDTH-1:0]   hrdata;
  logic                    hready;
  logic                    hresp;

  modport master (
    input  hclk,
    input  hresetn,
    input  hrdata,
    input  hready,
    input  hresp,
    output haddr,
    output htrans,
    output hwrite,
    output hsize,
    output hburst,
    output hprot,
    output hmastlock,
    output hwdata
  );

  modport slave (
    input  hclk,
    input  hresetn,
    input  hsel,
    input  haddr,
    input  htrans,
    input  hwrite,
    input  hsize,
    input  hburst,
    input  hprot,
    input  hmastlock,
    input  hwdata,
    output hrdata,
    output hready,
    output hresp
  );

  modport fabric_master_side (
    input  hclk,
    input  hresetn,
    input  haddr,
    input  htrans,
    input  hwrite,
    input  hsize,
    input  hburst,
    input  hprot,
    input  hmastlock,
    input  hwdata,
    output hrdata,
    output hready,
    output hresp
  );

  modport fabric_slave_side (
    input  hclk,
    input  hresetn,
    input  hrdata,
    input  hready,
    input  hresp,
    output hsel,
    output haddr,
    output htrans,
    output hwrite,
    output hsize,
    output hburst,
    output hprot,
    output hmastlock,
    output hwdata
  );

  modport monitor (
    input hclk,
    input hresetn,
    input hsel,
    input haddr,
    input htrans,
    input hwrite,
    input hsize,
    input hburst,
    input hprot,
    input hmastlock,
    input hwdata,
    input hrdata,
    input hready,
    input hresp
  );
endinterface
