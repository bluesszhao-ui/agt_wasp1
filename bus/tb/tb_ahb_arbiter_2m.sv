`timescale 1ns/1ps

module tb_ahb_arbiter_2m;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;

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

  logic [ADDR_WIDTH-1:0] haddr;
  logic [1:0]            htrans;
  logic                  hwrite;
  logic [2:0]            hsize;
  logic [2:0]            hburst;
  logic [3:0]            hprot;
  logic                  hmastlock;
  logic [DATA_WIDTH-1:0] hwdata;
  logic [DATA_WIDTH-1:0] hrdata;
  logic                  hready;
  logic                  hresp;
  logic                  grant_valid;
  logic                  grant_idx;

  int unsigned pass_count;
  int unsigned m0_grant_count;
  int unsigned m1_grant_count;
  int unsigned both_req_count;
  int unsigned wait_hold_count;
  int unsigned response_error_count;
  int unsigned response_ready_low_count;
  int unsigned write_data_hold_count;

  ahb_arbiter_2m u_ahb_arbiter_2m (
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
    .haddr_o(haddr),
    .htrans_o(htrans),
    .hwrite_o(hwrite),
    .hsize_o(hsize),
    .hburst_o(hburst),
    .hprot_o(hprot),
    .hmastlock_o(hmastlock),
    .hwdata_o(hwdata),
    .hrdata_i(hrdata),
    .hready_i(hready),
    .hresp_i(hresp),
    .grant_valid_o(grant_valid),
    .grant_idx_o(grant_idx)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

  task automatic drive_master_idle(input int master_idx);
    begin
      if (master_idx == 0) begin
        m0_htrans = AHB_HTRANS_IDLE;
      end else begin
        m1_htrans = AHB_HTRANS_IDLE;
      end
    end
  endtask

  task automatic drive_master_req(
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
      hready = 1'b1;
      hresp = AHB_HRESP_OKAY;
      hrdata = '0;
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
      if (grant_valid !== 1'b0 || htrans !== AHB_HTRANS_IDLE) begin
        $error("reset: expected idle arbiter outputs");
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic expect_non_owner_stalled(input int owner_idx);
    begin
      if ((owner_idx == 0) && (m1_htrans[1] && (m1_hready !== 1'b0))) begin
        $error("non-owner m1 should be stalled while m0 owns the transfer");
        $fatal(1);
      end
      if ((owner_idx == 1) && (m0_htrans[1] && (m0_hready !== 1'b0))) begin
        $error("non-owner m0 should be stalled while m1 owns the transfer");
        $fatal(1);
      end
    end
  endtask

  task automatic check_addr_phase(
    input int master_idx,
    input logic [ADDR_WIDTH-1:0] expected_addr,
    input logic expected_write,
    input logic [DATA_WIDTH-1:0] expected_wdata,
    input string label
  );
    begin
      @(posedge hclk);
      #1ns;
      if (grant_valid !== 1'b1 || grant_idx !== 1'(master_idx)) begin
        $error("%s: address grant mismatch valid=%0b idx=%0b", label, grant_valid, grant_idx);
        $fatal(1);
      end
      if (haddr !== expected_addr || hwrite !== expected_write ||
          htrans !== AHB_HTRANS_NONSEQ || hsize !== AHB_HSIZE_WORD ||
          hburst !== AHB_HBURST_SINGLE) begin
        $error("%s: shared address/control mismatch", label);
        $fatal(1);
      end
      if ((master_idx == 0 && m0_hready !== 1'b1) ||
          (master_idx == 1 && m1_hready !== 1'b1)) begin
        $error("%s: owner did not see address-ready pulse", label);
        $fatal(1);
      end
      if (expected_write && (hwdata !== expected_wdata)) begin
        $error("%s: write data not visible in address phase", label);
        $fatal(1);
      end
      expect_non_owner_stalled(master_idx);
      if (master_idx == 0) begin
        m0_grant_count++;
      end else begin
        m1_grant_count++;
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
      if (grant_valid !== 1'b0 || htrans !== AHB_HTRANS_IDLE) begin
        $error("%s: expected no new address while waiting for response", label);
        $fatal(1);
      end
      if ((master_idx == 0 && m0_hready !== 1'b0) ||
          (master_idx == 1 && m1_hready !== 1'b0)) begin
        $error("%s: owner should be stalled during wait phase", label);
        $fatal(1);
      end
      if (expected_write && (hwdata !== expected_wdata)) begin
        $error("%s: write data was not held through wait phase", label);
        $fatal(1);
      end
      expect_non_owner_stalled(master_idx);
      wait_hold_count++;
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
      if (grant_valid !== 1'b0 || htrans !== AHB_HTRANS_IDLE) begin
        $error("%s: response phase should not emit a new address", label);
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
        response_error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic run_single_transfer(
    input int master_idx,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [DATA_WIDTH-1:0] rdata,
    input logic resp,
    input int unsigned stall_cycles,
    input string label
  );
    begin
      hready = 1'b1;
      hresp = AHB_HRESP_OKAY;
      hrdata = '0;
      check_addr_phase(master_idx, addr, write, wdata, {label, " addr"});
      drive_master_idle(master_idx);

      check_wait_phase(master_idx, write, wdata, {label, " wait-entry"});
      hready = 1'b0;
      repeat (stall_cycles) begin
        check_wait_phase(master_idx, write, wdata, {label, " wait-stall"});
        response_ready_low_count++;
      end

      hrdata = rdata;
      hresp = resp;
      hready = 1'b1;
      check_resp_phase(master_idx, rdata, resp, {label, " resp"});
      @(posedge hclk);
      #1ns;
      pass_count++;
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (m0_grant_count < 4 || m1_grant_count < 4) begin
        $error("coverage miss: grants m0=%0d m1=%0d", m0_grant_count, m1_grant_count);
        $fatal(1);
      end
      if (both_req_count < 4 || wait_hold_count < 8 || response_ready_low_count < 2 ||
          response_error_count == 0 || write_data_hold_count == 0) begin
        $error("coverage miss: both=%0d wait=%0d ready_low=%0d err=%0d wdata=%0d",
               both_req_count, wait_hold_count, response_ready_low_count,
               response_error_count, write_data_hold_count);
        $fatal(1);
      end
      $display("tb_ahb_arbiter_2m coverage: pass_count=%0d m0_grant_count=%0d m1_grant_count=%0d both_req_count=%0d wait_hold_count=%0d ready_low_count=%0d error_count=%0d write_data_hold_count=%0d",
               pass_count, m0_grant_count, m1_grant_count, both_req_count,
               wait_hold_count, response_ready_low_count, response_error_count,
               write_data_hold_count);
    end
  endtask

  initial begin
    pass_count = 0;
    m0_grant_count = 0;
    m1_grant_count = 0;
    both_req_count = 0;
    wait_hold_count = 0;
    response_error_count = 0;
    response_ready_low_count = 0;
    write_data_hold_count = 0;

    apply_reset();

    drive_master_req(0, 32'h0000_0040, 1'b0, 32'h0000_0000);
    drive_master_idle(1);
    run_single_transfer(0, 32'h0000_0040, 1'b0, 32'h0000_0000,
                        32'hC0C0_0000, AHB_HRESP_OKAY, 0, "m0 read");

    drive_master_idle(0);
    drive_master_req(1, 32'h2000_0080, 1'b1, 32'hDEAD_BEEF);
    run_single_transfer(1, 32'h2000_0080, 1'b1, 32'hDEAD_BEEF,
                        32'hD1D1_0001, AHB_HRESP_ERROR, 2, "m1 write error");

    for (int idx = 0; idx < 8; idx++) begin
      drive_master_req(0, 32'h1000_0000 + 32'(idx * 4), 1'b0, 32'h0000_0000);
      drive_master_req(1, 32'h2000_0000 + 32'(idx * 4), 1'b1, 32'hCAFE_0000 + 32'(idx));
      both_req_count++;
      if ((idx % 2) == 0) begin
        run_single_transfer(0, 32'h1000_0000 + 32'(idx * 4), 1'b0, 32'h0000_0000,
                            32'hA000_0000 + 32'(idx), AHB_HRESP_OKAY, 0, "rr m0");
      end else begin
        run_single_transfer(1, 32'h2000_0000 + 32'(idx * 4), 1'b1, 32'hCAFE_0000 + 32'(idx),
                            32'hB000_0000 + 32'(idx), AHB_HRESP_OKAY, 0, "rr m1");
      end
    end

    check_coverage_summary();
    $display("tb_ahb_arbiter_2m PASS");
    $finish;
  end
endmodule
