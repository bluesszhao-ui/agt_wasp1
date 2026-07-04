`timescale 1ns/1ps

module tb_ahb_fabric_2m;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int EXT_SLAVE_COUNT = AHB_SLAVE_DEFAULT;

  logic hclk;
  logic hresetn;

  logic [ADDR_WIDTH-1:0] m0_haddr;
  logic [1:0]            m0_htrans;
  logic                  m0_hwrite;
  logic [2:0]            m0_hsize;
  logic [2:0]            m0_hburst;
  logic [3:0]            m0_hprot;
  logic                  m0_hmastlock;
  logic [DATA_WIDTH-1:0] m0_hwdata;
  logic [DATA_WIDTH-1:0] m0_hrdata;
  logic                  m0_hready;
  logic                  m0_hresp;

  logic [ADDR_WIDTH-1:0] m1_haddr;
  logic [1:0]            m1_htrans;
  logic                  m1_hwrite;
  logic [2:0]            m1_hsize;
  logic [2:0]            m1_hburst;
  logic [3:0]            m1_hprot;
  logic                  m1_hmastlock;
  logic [DATA_WIDTH-1:0] m1_hwdata;
  logic [DATA_WIDTH-1:0] m1_hrdata;
  logic                  m1_hready;
  logic                  m1_hresp;

  logic [EXT_SLAVE_COUNT-1:0] slave_hsel;
  logic [ADDR_WIDTH-1:0]      slave_haddr;
  logic [1:0]                 slave_htrans;
  logic                       slave_hwrite;
  logic [2:0]                 slave_hsize;
  logic [2:0]                 slave_hburst;
  logic [3:0]                 slave_hprot;
  logic                       slave_hmastlock;
  logic [DATA_WIDTH-1:0]      slave_hwdata;
  logic [EXT_SLAVE_COUNT-1:0][DATA_WIDTH-1:0] slave_hrdata;
  logic [EXT_SLAVE_COUNT-1:0] slave_hready;
  logic [EXT_SLAVE_COUNT-1:0] slave_hresp;
  logic                       grant_valid;
  logic                       grant_idx;
  logic                       default_sel;
  logic                       slave_select_err;

  int unsigned pass_count;
  int unsigned m0_route_count;
  int unsigned m1_route_count;
  int unsigned default_error_count;
  int unsigned stall_count;
  int unsigned both_req_count;
  int unsigned write_data_hold_count;

  ahb_fabric_2m u_ahb_fabric_2m (
    .hclk_i(hclk),
    .hresetn_i(hresetn),
    .m0_haddr_i(m0_haddr),
    .m0_htrans_i(m0_htrans),
    .m0_hwrite_i(m0_hwrite),
    .m0_hsize_i(m0_hsize),
    .m0_hburst_i(m0_hburst),
    .m0_hprot_i(m0_hprot),
    .m0_hmastlock_i(m0_hmastlock),
    .m0_hwdata_i(m0_hwdata),
    .m0_hrdata_o(m0_hrdata),
    .m0_hready_o(m0_hready),
    .m0_hresp_o(m0_hresp),
    .m1_haddr_i(m1_haddr),
    .m1_htrans_i(m1_htrans),
    .m1_hwrite_i(m1_hwrite),
    .m1_hsize_i(m1_hsize),
    .m1_hburst_i(m1_hburst),
    .m1_hprot_i(m1_hprot),
    .m1_hmastlock_i(m1_hmastlock),
    .m1_hwdata_i(m1_hwdata),
    .m1_hrdata_o(m1_hrdata),
    .m1_hready_o(m1_hready),
    .m1_hresp_o(m1_hresp),
    .slave_hsel_o(slave_hsel),
    .slave_haddr_o(slave_haddr),
    .slave_htrans_o(slave_htrans),
    .slave_hwrite_o(slave_hwrite),
    .slave_hsize_o(slave_hsize),
    .slave_hburst_o(slave_hburst),
    .slave_hprot_o(slave_hprot),
    .slave_hmastlock_o(slave_hmastlock),
    .slave_hwdata_o(slave_hwdata),
    .slave_hrdata_i(slave_hrdata),
    .slave_hready_i(slave_hready),
    .slave_hresp_i(slave_hresp),
    .grant_valid_o(grant_valid),
    .grant_idx_o(grant_idx),
    .default_sel_o(default_sel),
    .slave_select_err_o(slave_select_err)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

  task automatic init_slaves;
    begin
      for (int idx = 0; idx < EXT_SLAVE_COUNT; idx++) begin
        slave_hrdata[idx] = 32'h5A00_0000 + DATA_WIDTH'(idx);
        slave_hready[idx] = 1'b1;
        slave_hresp[idx] = AHB_HRESP_OKAY;
      end
    end
  endtask

  task automatic drive_idle(input int master_idx);
    begin
      if (master_idx == 0) begin
        m0_htrans = AHB_HTRANS_IDLE;
      end else begin
        m1_htrans = AHB_HTRANS_IDLE;
      end
    end
  endtask

  task automatic drive_req(
    input int master_idx,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [DATA_WIDTH-1:0] wdata
  );
    begin
      if (master_idx == 0) begin
        m0_haddr = addr;
        m0_htrans = AHB_HTRANS_NONSEQ;
        m0_hwrite = write;
        m0_hsize = AHB_HSIZE_WORD;
        m0_hburst = AHB_HBURST_SINGLE;
        m0_hprot = 4'h3;
        m0_hmastlock = 1'b0;
        m0_hwdata = wdata;
      end else begin
        m1_haddr = addr;
        m1_htrans = AHB_HTRANS_NONSEQ;
        m1_hwrite = write;
        m1_hsize = AHB_HSIZE_WORD;
        m1_hburst = AHB_HBURST_SINGLE;
        m1_hprot = 4'h5;
        m1_hmastlock = 1'b0;
        m1_hwdata = wdata;
      end
    end
  endtask

  task automatic apply_reset;
    begin
      hresetn = 1'b0;
      init_slaves();
      m0_haddr = '0;
      m0_htrans = AHB_HTRANS_IDLE;
      m0_hwrite = 1'b0;
      m0_hsize = AHB_HSIZE_WORD;
      m0_hburst = AHB_HBURST_SINGLE;
      m0_hprot = '0;
      m0_hmastlock = 1'b0;
      m0_hwdata = '0;
      m1_haddr = '0;
      m1_htrans = AHB_HTRANS_IDLE;
      m1_hwrite = 1'b0;
      m1_hsize = AHB_HSIZE_WORD;
      m1_hburst = AHB_HBURST_SINGLE;
      m1_hprot = '0;
      m1_hmastlock = 1'b0;
      m1_hwdata = '0;
      repeat (2) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (grant_valid !== 1'b0 || slave_hsel !== '0 || default_sel !== 1'b0) begin
        $error("reset: expected idle fabric outputs");
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic expect_non_owner_stalled(input int owner_idx);
    begin
      if ((owner_idx == 0) && m1_htrans[1] && (m1_hready !== 1'b0)) begin
        $error("non-owner m1 should be stalled");
        $fatal(1);
      end
      if ((owner_idx == 1) && m0_htrans[1] && (m0_hready !== 1'b0)) begin
        $error("non-owner m0 should be stalled");
        $fatal(1);
      end
    end
  endtask

  task automatic check_addr_phase(
    input int master_idx,
    input int slave_idx,
    input logic [ADDR_WIDTH-1:0] expected_addr,
    input logic expected_write,
    input logic [DATA_WIDTH-1:0] expected_wdata,
    input string label
  );
    logic [EXT_SLAVE_COUNT-1:0] expected_hsel;
    begin
      @(posedge hclk);
      #1ns;
      expected_hsel = '0;
      if (slave_idx >= 0 && slave_idx < EXT_SLAVE_COUNT) begin
        expected_hsel[slave_idx] = 1'b1;
      end

      if (grant_valid !== 1'b1 || grant_idx !== 1'(master_idx)) begin
        $error("%s: grant mismatch valid=%0b idx=%0b", label, grant_valid, grant_idx);
        $fatal(1);
      end
      if (slave_haddr !== expected_addr || slave_hwrite !== expected_write ||
          slave_htrans !== AHB_HTRANS_NONSEQ || slave_hsize !== AHB_HSIZE_WORD ||
          slave_hburst !== AHB_HBURST_SINGLE) begin
        $error("%s: shared bus control mismatch", label);
        $fatal(1);
      end
      if (slave_idx == AHB_SLAVE_DEFAULT) begin
        if (default_sel !== 1'b1 || slave_hsel !== '0) begin
          $error("%s: default select mismatch default=%0b hsel=0x%0h", label, default_sel, slave_hsel);
          $fatal(1);
        end
      end else if (slave_hsel !== expected_hsel || default_sel !== 1'b0) begin
        $error("%s: slave select mismatch expected=0x%0h got=0x%0h default=%0b",
               label, expected_hsel, slave_hsel, default_sel);
        $fatal(1);
      end
      if ((master_idx == 0 && m0_hready !== 1'b1) ||
          (master_idx == 1 && m1_hready !== 1'b1)) begin
        $error("%s: owner did not see address-ready pulse", label);
        $fatal(1);
      end
      if (expected_write && (slave_hwdata !== expected_wdata)) begin
        $error("%s: write data mismatch in address phase", label);
        $fatal(1);
      end
      expect_non_owner_stalled(master_idx);
      if (slave_select_err !== 1'b0) begin
        $error("%s: unexpected mux select error", label);
        $fatal(1);
      end

      if (master_idx == 0) begin
        m0_route_count++;
      end else begin
        m1_route_count++;
      end
      pass_count++;
    end
  endtask

  task automatic check_wait_phase(
    input int master_idx,
    input logic expected_write,
    input logic [DATA_WIDTH-1:0] expected_wdata,
    input string label
  );
    begin
      @(posedge hclk);
      #1ns;
      if (grant_valid !== 1'b0 || slave_htrans !== AHB_HTRANS_IDLE ||
          slave_hsel !== '0 || default_sel !== 1'b0) begin
        $error("%s: expected idle address bus during wait", label);
        $fatal(1);
      end
      if ((master_idx == 0 && m0_hready !== 1'b0) ||
          (master_idx == 1 && m1_hready !== 1'b0)) begin
        $error("%s: owner should be stalled in wait phase", label);
        $fatal(1);
      end
      if (expected_write && (slave_hwdata !== expected_wdata)) begin
        $error("%s: write data was not held in wait phase", label);
        $fatal(1);
      end
      expect_non_owner_stalled(master_idx);
      if (expected_write) begin
        write_data_hold_count++;
      end
      pass_count++;
    end
  endtask

  task automatic check_resp_phase(
    input int master_idx,
    input logic [DATA_WIDTH-1:0] expected_rdata,
    input logic expected_resp,
    input string label
  );
    begin
      @(posedge hclk);
      #1ns;
      if (grant_valid !== 1'b0 || slave_htrans !== AHB_HTRANS_IDLE ||
          slave_hsel !== '0 || default_sel !== 1'b0) begin
        $error("%s: response phase emitted an address", label);
        $fatal(1);
      end
      if (master_idx == 0) begin
        if (m0_hready !== 1'b1 || m0_hrdata !== expected_rdata || m0_hresp !== expected_resp) begin
          $error("%s: m0 response mismatch ready=%0b rdata=0x%08h resp=%0b",
                 label, m0_hready, m0_hrdata, m0_hresp);
          $fatal(1);
        end
      end else begin
        if (m1_hready !== 1'b1 || m1_hrdata !== expected_rdata || m1_hresp !== expected_resp) begin
          $error("%s: m1 response mismatch ready=%0b rdata=0x%08h resp=%0b",
                 label, m1_hready, m1_hrdata, m1_hresp);
          $fatal(1);
        end
      end
      expect_non_owner_stalled(master_idx);
      if (expected_resp == AHB_HRESP_ERROR) begin
        if (expected_rdata == '0) begin
          default_error_count++;
        end
      end
      pass_count++;
    end
  endtask

  task automatic run_transfer(
    input int master_idx,
    input int slave_idx,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [DATA_WIDTH-1:0] rdata,
    input logic resp,
    input int unsigned stall_cycles,
    input string label
  );
    logic [DATA_WIDTH-1:0] expected_rdata;
    logic expected_resp;
    begin
      init_slaves();
      expected_rdata = (slave_idx == AHB_SLAVE_DEFAULT) ? '0 : rdata;
      expected_resp = (slave_idx == AHB_SLAVE_DEFAULT) ? AHB_HRESP_ERROR : resp;
      if (slave_idx >= 0 && slave_idx < EXT_SLAVE_COUNT) begin
        slave_hrdata[slave_idx] = rdata;
        slave_hresp[slave_idx] = resp;
      end

      check_addr_phase(master_idx, slave_idx, addr, write, wdata, {label, " addr"});
      drive_idle(master_idx);

      if (slave_idx >= 0 && slave_idx < EXT_SLAVE_COUNT && stall_cycles != 0) begin
        slave_hready[slave_idx] = 1'b0;
      end
      check_wait_phase(master_idx, write, wdata, {label, " wait-entry"});

      repeat (stall_cycles) begin
        stall_count++;
        check_wait_phase(master_idx, write, wdata, {label, " wait-stall"});
      end

      if (slave_idx >= 0 && slave_idx < EXT_SLAVE_COUNT) begin
        slave_hready[slave_idx] = 1'b1;
      end
      check_resp_phase(master_idx, expected_rdata, expected_resp, {label, " resp"});
      @(posedge hclk);
      #1ns;
      pass_count++;
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (m0_route_count < 4 || m1_route_count < 4 || both_req_count < 4 ||
          default_error_count == 0 || stall_count == 0 || write_data_hold_count == 0) begin
        $error("coverage miss: m0=%0d m1=%0d both=%0d default=%0d stall=%0d wdata=%0d",
               m0_route_count, m1_route_count, both_req_count, default_error_count,
               stall_count, write_data_hold_count);
        $fatal(1);
      end
      $display("tb_ahb_fabric_2m coverage: pass_count=%0d m0_route_count=%0d m1_route_count=%0d both_req_count=%0d default_error_count=%0d stall_count=%0d write_data_hold_count=%0d",
               pass_count, m0_route_count, m1_route_count, both_req_count,
               default_error_count, stall_count, write_data_hold_count);
    end
  endtask

  initial begin
    pass_count = 0;
    m0_route_count = 0;
    m1_route_count = 0;
    default_error_count = 0;
    stall_count = 0;
    both_req_count = 0;
    write_data_hold_count = 0;

    apply_reset();

    drive_req(0, OTP_BASE + 32'h10, 1'b0, 32'h0000_0000);
    drive_idle(1);
    run_transfer(0, AHB_SLAVE_OTP, OTP_BASE + 32'h10, 1'b0, 32'h0000_0000,
                 32'h1111_0000, AHB_HRESP_OKAY, 0, "m0 otp");

    drive_idle(0);
    drive_req(1, DSRAM_BASE + 32'h10, 1'b1, 32'h1234_5678);
    run_transfer(1, AHB_SLAVE_DSRAM, DSRAM_BASE + 32'h10, 1'b1, 32'h1234_5678,
                 32'h2222_0000, AHB_HRESP_OKAY, 2, "m1 dsram stall");

    drive_req(0, 32'h8000_0000, 1'b0, 32'h0000_0000);
    drive_idle(1);
    run_transfer(0, AHB_SLAVE_DEFAULT, 32'h8000_0000, 1'b0, 32'h0000_0000,
                 32'h0000_0000, AHB_HRESP_ERROR, 0, "m0 default");

    for (int idx = 0; idx < 8; idx++) begin
      drive_req(0, ISRAM_BASE + 32'(idx * 4), 1'b0, 32'h0000_0000);
      drive_req(1, DMA_BASE + 32'(idx * 4), 1'b1, 32'hCAFE_0000 + 32'(idx));
      both_req_count++;
      if ((idx % 2) == 0) begin
        run_transfer(1, AHB_SLAVE_DMA, DMA_BASE + 32'(idx * 4), 1'b1,
                     32'hCAFE_0000 + 32'(idx), 32'h4400_0000 + 32'(idx),
                     AHB_HRESP_OKAY, 0, "rr m1 dma");
      end else begin
        run_transfer(0, AHB_SLAVE_ISRAM, ISRAM_BASE + 32'(idx * 4), 1'b0,
                     32'h0000_0000, 32'h3300_0000 + 32'(idx), AHB_HRESP_OKAY,
                     0, "rr m0 isram");
      end
    end

    check_coverage_summary();
    $display("tb_ahb_fabric_2m PASS");
    $finish;
  end
endmodule
