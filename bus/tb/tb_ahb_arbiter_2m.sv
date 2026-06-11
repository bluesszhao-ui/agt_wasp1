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
  int unsigned stall_hold_count;
  int unsigned response_error_count;
  int unsigned response_ready_low_count;

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
        $error("reset: expected no grant and IDLE transfer");
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic sample_and_check(
    input logic expected_valid,
    input logic expected_idx,
    input logic [ADDR_WIDTH-1:0] expected_addr,
    input logic expected_write,
    input logic [DATA_WIDTH-1:0] expected_wdata,
    input string label
  );
    begin
      @(posedge hclk);
      #1ns;
      if (grant_valid !== expected_valid) begin
        $error("%s: expected grant_valid=%0b got %0b", label, expected_valid, grant_valid);
        $fatal(1);
      end
      if (grant_valid) begin
        if (grant_idx !== expected_idx) begin
          $error("%s: expected grant_idx=%0b got %0b", label, expected_idx, grant_idx);
          $fatal(1);
        end
        if (haddr !== expected_addr || hwrite !== expected_write || hwdata !== expected_wdata) begin
          $error("%s: output mismatch addr=0x%08h write=%0b wdata=0x%08h", label, haddr, hwrite, hwdata);
          $fatal(1);
        end
        if (htrans !== AHB_HTRANS_NONSEQ || hsize !== AHB_HSIZE_WORD || hburst !== AHB_HBURST_SINGLE) begin
          $error("%s: transfer control mismatch", label);
          $fatal(1);
        end
        if (expected_idx == 1'b0) begin
          m0_grant_count++;
        end else begin
          m1_grant_count++;
        end
      end
      pass_count++;
    end
  endtask

  task automatic check_response_route(input logic selected_idx, input string label);
    begin
      hrdata = selected_idx ? 32'hD1D1_0001 : 32'hC0C0_0000;
      hresp = selected_idx ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;
      hready = 1'b1;
      #1ns;
      if (selected_idx == 1'b0) begin
        if (m0_hrdata !== hrdata || m0_hresp !== hresp || m0_hready !== hready) begin
          $error("%s: m0 response route mismatch", label);
          $fatal(1);
        end
        if (m1_hready !== (m1_htrans == AHB_HTRANS_IDLE)) begin
          $error("%s: m1 non-granted ready mismatch", label);
          $fatal(1);
        end
      end else begin
        if (m1_hrdata !== hrdata || m1_hresp !== hresp || m1_hready !== hready) begin
          $error("%s: m1 response route mismatch", label);
          $fatal(1);
        end
        if (m0_hready !== (m0_htrans == AHB_HTRANS_IDLE)) begin
          $error("%s: m0 non-granted ready mismatch", label);
          $fatal(1);
        end
      end
      if (hresp == AHB_HRESP_ERROR) begin
        response_error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic check_stall_hold;
    logic held_idx;
    logic [ADDR_WIDTH-1:0] held_addr;
    begin
      hready = 1'b1;
      drive_master_req(0, 32'h1000_0100, 1'b0, 32'h0000_0000);
      drive_master_req(1, 32'h2000_0200, 1'b1, 32'hDEAD_BEEF);
      sample_and_check(1'b1, 1'b0, 32'h1000_0100, 1'b0, 32'h0000_0000, "stall setup grant m0");
      held_idx = grant_idx;
      held_addr = haddr;

      hready = 1'b0;
      repeat (3) begin
        @(posedge hclk);
        #1ns;
        if (grant_idx !== held_idx || haddr !== held_addr || grant_valid !== 1'b1) begin
          $error("stall hold: grant changed while hready low");
          $fatal(1);
        end
        if (m0_hready !== 1'b0) begin
          $error("stall hold: selected master did not see hready low");
          $fatal(1);
        end
        response_ready_low_count++;
        stall_hold_count++;
        pass_count++;
      end

      hready = 1'b1;
      sample_and_check(1'b1, 1'b1, 32'h2000_0200, 1'b1, 32'hDEAD_BEEF, "stall release grant m1");
    end
  endtask

  task automatic check_round_robin;
    logic expected_idx;
    begin
      hready = 1'b1;
      drive_master_req(0, 32'h0000_1000, 1'b0, 32'h0000_0000);
      drive_master_req(1, 32'h4000_0000, 1'b1, 32'h1111_0000);
      expected_idx = 1'b0;
      for (int idx = 0; idx < 12; idx++) begin
        both_req_count++;
        if (expected_idx == 1'b0) begin
          sample_and_check(1'b1, 1'b0, 32'h0000_1000, 1'b0, 32'h0000_0000, "round-robin m0");
        end else begin
          sample_and_check(1'b1, 1'b1, 32'h4000_0000, 1'b1, 32'h1111_0000, "round-robin m1");
        end
        check_response_route(expected_idx, "round-robin response");
        expected_idx = ~expected_idx;
      end
    end
  endtask

  task automatic check_random_arbitration(input int unsigned count);
    logic model_last_grant;
    logic req0;
    logic req1;
    logic expected_valid;
    logic expected_idx;
    logic [ADDR_WIDTH-1:0] addr0;
    logic [ADDR_WIDTH-1:0] addr1;
    logic [DATA_WIDTH-1:0] wdata0;
    logic [DATA_WIDTH-1:0] wdata1;
    begin
      apply_reset();
      model_last_grant = 1'b1;
      hready = 1'b1;

      for (int unsigned idx = 0; idx < count; idx++) begin
        req0 = 1'($urandom_range(0, 1));
        req1 = 1'($urandom_range(0, 1));
        addr0 = 32'h0000_0000 | (32'($urandom()) & 32'h0000_FFFC);
        addr1 = 32'h2000_0000 | (32'($urandom()) & 32'h0000_FFFC);
        wdata0 = $urandom();
        wdata1 = $urandom();

        if (req0) begin
          drive_master_req(0, addr0, 1'b0, wdata0);
        end else begin
          drive_master_idle(0);
        end

        if (req1) begin
          drive_master_req(1, addr1, 1'b1, wdata1);
        end else begin
          drive_master_idle(1);
        end

        expected_valid = req0 || req1;
        expected_idx = 1'b0;
        if (req0 && !req1) begin
          expected_idx = 1'b0;
        end else if (!req0 && req1) begin
          expected_idx = 1'b1;
        end else if (req0 && req1) begin
          expected_idx = (model_last_grant == 1'b0) ? 1'b1 : 1'b0;
          both_req_count++;
        end

        if (!expected_valid) begin
          sample_and_check(1'b0, 1'b0, '0, 1'b0, '0, "random no request");
        end else if (expected_idx == 1'b0) begin
          sample_and_check(1'b1, 1'b0, addr0, 1'b0, wdata0, "random m0 grant");
          model_last_grant = 1'b0;
        end else begin
          sample_and_check(1'b1, 1'b1, addr1, 1'b1, wdata1, "random m1 grant");
          model_last_grant = 1'b1;
        end
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (m0_grant_count < 4 || m1_grant_count < 4) begin
        $error("coverage miss: grants m0=%0d m1=%0d", m0_grant_count, m1_grant_count);
        $fatal(1);
      end
      if (both_req_count < 8) begin
        $error("coverage miss: both request count too low: %0d", both_req_count);
        $fatal(1);
      end
      if (stall_hold_count < 3 || response_ready_low_count < 3) begin
        $error("coverage miss: stall coverage too low");
        $fatal(1);
      end
      if (response_error_count == 0) begin
        $error("coverage miss: response error path not covered");
        $fatal(1);
      end
      $display("tb_ahb_arbiter_2m coverage: pass_count=%0d m0_grant_count=%0d m1_grant_count=%0d both_req_count=%0d stall_hold_count=%0d ready_low_count=%0d error_count=%0d",
               pass_count, m0_grant_count, m1_grant_count, both_req_count,
               stall_hold_count, response_ready_low_count, response_error_count);
    end
  endtask

  initial begin
    pass_count = 0;
    m0_grant_count = 0;
    m1_grant_count = 0;
    both_req_count = 0;
    stall_hold_count = 0;
    response_error_count = 0;
    response_ready_low_count = 0;

    apply_reset();

    drive_master_req(0, 32'h0000_0040, 1'b0, 32'h0000_0000);
    drive_master_idle(1);
    sample_and_check(1'b1, 1'b0, 32'h0000_0040, 1'b0, 32'h0000_0000, "m0 only");
    check_response_route(1'b0, "m0 only response");

    drive_master_idle(0);
    drive_master_req(1, 32'h2000_0040, 1'b1, 32'h1234_5678);
    sample_and_check(1'b1, 1'b1, 32'h2000_0040, 1'b1, 32'h1234_5678, "m1 only");
    check_response_route(1'b1, "m1 only response");

    check_round_robin();
    check_stall_hold();
    check_random_arbitration(64);

    drive_master_idle(0);
    drive_master_idle(1);
    sample_and_check(1'b0, 1'b0, '0, 1'b0, '0, "both idle");
    check_coverage_summary();

    $display("tb_ahb_arbiter_2m PASS");
    $finish;
  end
endmodule
