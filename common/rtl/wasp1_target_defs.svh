`ifndef WASP1_TARGET_DEFS_SVH
`define WASP1_TARGET_DEFS_SVH

`ifdef WASP1_TARGET_IC
  `ifdef WASP1_TARGET_FPGA_XILINX_VIRTEX7
    `error "Select only one wasp1 implementation target macro"
  `endif
  `ifdef WASP1_TARGET_SIM_GENERIC
    `error "Select only one wasp1 implementation target macro"
  `endif
`endif

`ifdef WASP1_TARGET_FPGA_XILINX_VIRTEX7
  `ifdef WASP1_TARGET_SIM_GENERIC
    `error "Select only one wasp1 implementation target macro"
  `endif
`endif

`ifndef WASP1_TARGET_IC
  `ifndef WASP1_TARGET_FPGA_XILINX_VIRTEX7
    `ifndef WASP1_TARGET_SIM_GENERIC
      `define WASP1_TARGET_SIM_GENERIC
    `endif
  `endif
`endif

`endif
