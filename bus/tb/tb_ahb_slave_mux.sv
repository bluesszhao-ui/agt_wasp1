`timescale 1ns/1ps

module tb_ahb_slave_mux;
  import wasp1_pkg::*;

  logic [AHB_SLAVE_COUNT-1:0] hsel;
  logic [AHB_SLAVE_COUNT-1:0][DATA_WIDTH-1:0] slave_hrdata;
  logic [AHB_SLAVE_COUNT-1:0] slave_hready;
  logic [AHB_SLAVE_COUNT-1:0] slave_hresp;
  logic [DATA_WIDTH-1:0] hrdata;
  logic hready;
  logic hresp;
  logic select_err;

  int unsigned pass_count;
  int unsigned no_select_count;
  int unsigned multi_select_count;
  int unsigned slave_hit_count [AHB_SLAVE_COUNT];
  int unsigned ready_low_count;
  int unsigned error_resp_count;

  ahb_slave_mux u_ahb_slave_mux (
    .hsel_i(hsel),
    .slave_hrdata_i(slave_hrdata),
    .slave_hready_i(slave_hready),
    .slave_hresp_i(slave_hresp),
    .hrdata_o(hrdata),
    .hready_o(hready),
    .hresp_o(hresp),
    .select_err_o(select_err)
  );

  task automatic init_slave_responses;
    begin
      for (int idx = 0; idx < AHB_SLAVE_COUNT; idx++) begin
        slave_hrdata[idx] = 32'hA500_0000 + DATA_WIDTH'(idx);
        slave_hready[idx] = 1'b1;
        slave_hresp[idx] = AHB_HRESP_OKAY;
      end
    end
  endtask

  task automatic check_mux(
    input logic [AHB_SLAVE_COUNT-1:0] sel,
    input logic [DATA_WIDTH-1:0] expected_rdata,
    input logic expected_ready,
    input logic expected_resp,
    input logic expected_select_err,
    input string label
  );
    begin
      hsel = sel;
      #1ns;
      if (hrdata !== expected_rdata) begin
        $error("%s: expected hrdata=0x%08h got 0x%08h", label, expected_rdata, hrdata);
        $fatal(1);
      end
      if (hready !== expected_ready) begin
        $error("%s: expected hready=%0b got %0b", label, expected_ready, hready);
        $fatal(1);
      end
      if (hresp !== expected_resp) begin
        $error("%s: expected hresp=%0b got %0b", label, expected_resp, hresp);
        $fatal(1);
      end
      if (select_err !== expected_select_err) begin
        $error("%s: expected select_err=%0b got %0b", label, expected_select_err, select_err);
        $fatal(1);
      end

      if (sel == '0) begin
        no_select_count++;
      end else if (!$onehot(sel)) begin
        multi_select_count++;
      end else begin
        for (int idx = 0; idx < AHB_SLAVE_COUNT; idx++) begin
          if (sel[idx]) begin
            slave_hit_count[idx]++;
          end
        end
      end

      if (!expected_ready) begin
        ready_low_count++;
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_resp_count++;
      end
      pass_count++;
    end
  endtask

  task automatic check_single_select(input int idx, input string label);
    logic [AHB_SLAVE_COUNT-1:0] sel;
    begin
      sel = '0;
      sel[idx] = 1'b1;
      check_mux(sel, slave_hrdata[idx], slave_hready[idx], slave_hresp[idx], 1'b0, label);
    end
  endtask

  task automatic check_random_onehot(input int unsigned count);
    int idx;
    begin
      for (int unsigned case_idx = 0; case_idx < count; case_idx++) begin
        idx = int'($urandom_range(0, AHB_SLAVE_COUNT - 1));
        slave_hrdata[idx] = $urandom();
        slave_hready[idx] = 1'($urandom_range(0, 1));
        slave_hresp[idx] = 1'($urandom_range(0, 1));
        check_single_select(idx, "deterministic random onehot");
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (no_select_count == 0) begin
        $error("coverage miss: no select case not covered");
        $fatal(1);
      end
      if (multi_select_count < 2) begin
        $error("coverage miss: multi-select count too low: %0d", multi_select_count);
        $fatal(1);
      end
      foreach (slave_hit_count[idx]) begin
        if (slave_hit_count[idx] == 0) begin
          $error("coverage miss: slave index %0d not selected", idx);
          $fatal(1);
        end
      end
      if (ready_low_count == 0) begin
        $error("coverage miss: ready low response not covered");
        $fatal(1);
      end
      if (error_resp_count == 0) begin
        $error("coverage miss: error response not covered");
        $fatal(1);
      end
      $display("tb_ahb_slave_mux coverage: pass_count=%0d no_select_count=%0d multi_select_count=%0d ready_low_count=%0d error_resp_count=%0d",
               pass_count, no_select_count, multi_select_count, ready_low_count, error_resp_count);
      foreach (slave_hit_count[idx]) begin
        $display("tb_ahb_slave_mux coverage: slave[%0d] hits=%0d", idx, slave_hit_count[idx]);
      end
    end
  endtask

  initial begin
    void'($urandom(32'h5750_0003));
    pass_count = 0;
    no_select_count = 0;
    multi_select_count = 0;
    ready_low_count = 0;
    error_resp_count = 0;
    foreach (slave_hit_count[idx]) begin
      slave_hit_count[idx] = 0;
    end

    init_slave_responses();
    hsel = '0;

    check_mux('0, '0, 1'b1, AHB_HRESP_OKAY, 1'b0, "no select");

    for (int idx = 0; idx < AHB_SLAVE_COUNT; idx++) begin
      check_single_select(idx, "directed single select");
    end

    slave_hready[AHB_SLAVE_UART] = 1'b0;
    check_single_select(AHB_SLAVE_UART, "selected slave stalled");

    slave_hready[AHB_SLAVE_UART] = 1'b1;
    slave_hresp[AHB_SLAVE_DEFAULT] = AHB_HRESP_ERROR;
    check_single_select(AHB_SLAVE_DEFAULT, "selected slave error response");

    check_mux((1 << AHB_SLAVE_OTP) | (1 << AHB_SLAVE_DSRAM),
              '0, 1'b1, AHB_HRESP_ERROR, 1'b1, "two selects error");
    check_mux({AHB_SLAVE_COUNT{1'b1}},
              '0, 1'b1, AHB_HRESP_ERROR, 1'b1, "all selects error");

    check_random_onehot(128);
    check_coverage_summary();

    $display("tb_ahb_slave_mux PASS");
    $finish;
  end
endmodule
