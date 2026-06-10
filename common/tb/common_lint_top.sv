module common_lint_top (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        async_i,
  input  logic        fifo_push_valid_i,
  input  logic [31:0] fifo_push_data_i,
  input  logic        fifo_pop_ready_i,
  input  logic        skid_in_valid_i,
  input  logic [31:0] skid_in_data_i,
  input  logic        skid_out_ready_i,
  output logic        sync_rst_no,
  output logic        sync_o,
  output logic        fifo_push_ready_o,
  output logic        fifo_pop_valid_o,
  output logic [31:0] fifo_pop_data_o,
  output logic        skid_in_ready_o,
  output logic        skid_out_valid_o,
  output logic [31:0] skid_out_data_o
);
  import wasp1_pkg::*;

  ahb_lite_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) ahb_if (
    .hclk(clk_i),
    .hresetn(rst_ni)
  );

  mem_req_rsp_if #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) mem_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  irq_if #(
    .IRQ_COUNT(IRQ_SRC_COUNT)
  ) irq_bus_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  debug_if #(
    .XLEN(XLEN)
  ) dbg_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  reset_sync u_reset_sync (
    .clk_i(clk_i),
    .arst_ni(rst_ni),
    .srst_no(sync_rst_no)
  );

  sync_reg u_sync_reg (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .async_i(async_i),
    .sync_o(sync_o)
  );

  simple_fifo #(
    .WIDTH(DATA_WIDTH),
    .DEPTH(4)
  ) u_simple_fifo (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .push_valid_i(fifo_push_valid_i),
    .push_ready_o(fifo_push_ready_o),
    .push_data_i(fifo_push_data_i),
    .pop_valid_o(fifo_pop_valid_o),
    .pop_ready_i(fifo_pop_ready_i),
    .pop_data_o(fifo_pop_data_o)
  );

  skid_buffer #(
    .WIDTH(DATA_WIDTH)
  ) u_skid_buffer (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .in_valid_i(skid_in_valid_i),
    .in_ready_o(skid_in_ready_o),
    .in_data_i(skid_in_data_i),
    .out_valid_o(skid_out_valid_o),
    .out_ready_i(skid_out_ready_i),
    .out_data_o(skid_out_data_o)
  );

  always_comb begin
    ahb_if.hsel      = 1'b0;
    ahb_if.haddr     = '0;
    ahb_if.htrans    = AHB_HTRANS_IDLE;
    ahb_if.hwrite    = 1'b0;
    ahb_if.hsize     = AHB_HSIZE_WORD;
    ahb_if.hburst    = AHB_HBURST_SINGLE;
    ahb_if.hprot     = 4'h0;
    ahb_if.hmastlock = 1'b0;
    ahb_if.hwdata    = '0;
    ahb_if.hrdata    = '0;
    ahb_if.hready    = 1'b1;
    ahb_if.hresp     = AHB_HRESP_OKAY;

    mem_if.req_valid = 1'b0;
    mem_if.req_addr  = '0;
    mem_if.req_write = 1'b0;
    mem_if.req_size  = MEM_SIZE_WORD;
    mem_if.req_wdata = '0;
    mem_if.req_wstrb = '0;
    mem_if.req_instr = 1'b0;
    mem_if.rsp_ready = 1'b1;
    mem_if.req_ready = 1'b1;
    mem_if.rsp_valid = 1'b0;
    mem_if.rsp_rdata = '0;
    mem_if.rsp_err   = 1'b0;

    irq_bus_if.irq = '0;

    dbg_if.halt_req      = 1'b0;
    dbg_if.resume_req    = 1'b0;
    dbg_if.step_req      = 1'b0;
    dbg_if.halted        = 1'b0;
    dbg_if.running       = 1'b1;
    dbg_if.gpr_req_valid = 1'b0;
    dbg_if.gpr_req_ready = 1'b1;
    dbg_if.gpr_req_write = 1'b0;
    dbg_if.gpr_req_addr  = '0;
    dbg_if.gpr_req_wdata = '0;
    dbg_if.gpr_rsp_valid = 1'b0;
    dbg_if.gpr_rsp_ready = 1'b1;
    dbg_if.gpr_rsp_rdata = '0;
    dbg_if.gpr_rsp_err   = 1'b0;
  end
endmodule
