`timescale 1ns/1ps

// Self-checking AHB watchdog testbench.
//
// The bench drives single-beat AHB-Lite transfers and checks reset behavior,
// register access, timeout, kick, bad-key, clear, error response, and
// deterministic-random timeout cases.
module tb_ahb_wdg;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = WDG_BASE;
  localparam int REGION_BYTES = PERIPH_SIZE;

  logic                  hclk;          // 100 MHz verification clock.
  logic                  hresetn;       // Active-low reset driven by the bench.
  logic                  hsel;          // AHB select for the DUT.
  logic [ADDR_WIDTH-1:0] haddr;         // AHB byte address.
  logic [1:0]            htrans;        // AHB transfer type.
  logic                  hwrite;        // AHB write indicator.
  logic [2:0]            hsize;         // AHB transfer size.
  logic [DATA_WIDTH-1:0] hwdata;        // AHB write data.
  logic [DATA_WIDTH-1:0] hrdata;        // AHB read data.
  logic                  hready;        // DUT ready response.
  logic                  hresp;         // DUT response.
  logic                  wdg_irq;       // Watchdog interrupt output.
  logic                  wdg_reset_req; // Watchdog reset-request output.

  int unsigned pass_count;
  int unsigned reg_count;
  int unsigned timeout_count;
  int unsigned kick_count;
  int unsigned error_count;
  int unsigned random_count;

  ahb_wdg #(
    .BASE_ADDR(BASE_ADDR),
    .REGION_BYTES(REGION_BYTES)
  ) u_ahb_wdg (
    .hclk_i(hclk),
    .hresetn_i(hresetn),
    .hsel_i(hsel),
    .haddr_i(haddr),
    .htrans_i(htrans),
    .hwrite_i(hwrite),
    .hsize_i(hsize),
    .hwdata_i(hwdata),
    .hrdata_o(hrdata),
    .hready_o(hready),
    .hresp_o(hresp),
    .wdg_irq_o(wdg_irq),
    .wdg_reset_req_o(wdg_reset_req)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

  // Drive an idle AHB address phase.
  task automatic drive_idle;
    begin
      hsel = 1'b0;
      haddr = '0;
      htrans = AHB_HTRANS_IDLE;
      hwrite = 1'b0;
      hsize = AHB_HSIZE_WORD;
      hwdata = '0;
    end
  endtask

  // Apply reset and check externally visible reset values.
  task automatic apply_reset;
    begin
      hresetn = 1'b0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1 || hresp !== AHB_HRESP_OKAY ||
          hrdata !== '0 || wdg_irq !== 1'b0 || wdg_reset_req !== 1'b0) begin
        $error("reset: hready=%0b hresp=%0b hrdata=0x%08h irq=%0b reset_req=%0b",
               hready, hresp, hrdata, wdg_irq, wdg_reset_req);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Perform one AHB write and check the following data-phase response.
  task automatic ahb_write(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0] size,
    input logic [DATA_WIDTH-1:0] data,
    input logic expected_resp,
    input string label
  );
    begin
      @(negedge hclk);
      hsel = 1'b1;
      haddr = addr;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b1;
      hsize = size;
      hwdata = data;

      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1) begin
        $error("%s: write address phase expected hready=1", label);
        $fatal(1);
      end

      @(negedge hclk);
      drive_idle();
      hwdata = data;

      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: write response expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  // Perform one AHB read and compare both response and read data.
  task automatic ahb_read(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0] size,
    input logic [DATA_WIDTH-1:0] expected_data,
    input logic expected_resp,
    input string label
  );
    begin
      @(negedge hclk);
      hsel = 1'b1;
      haddr = addr;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b0;
      hsize = size;
      hwdata = '0;

      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1) begin
        $error("%s: read address phase expected hready=1", label);
        $fatal(1);
      end

      @(negedge hclk);
      drive_idle();

      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: read response expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_OKAY && hrdata !== expected_data) begin
        $error("%s: read data expected=0x%08h got=0x%08h",
               label, expected_data, hrdata);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic write_reg(
    input logic [31:0] offset,
    input logic [31:0] data,
    input string label
  );
    begin
      ahb_write(BASE_ADDR + offset, AHB_HSIZE_WORD, data, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic read_reg(
    input logic [31:0] offset,
    input logic [31:0] expected,
    input string label
  );
    begin
      ahb_read(BASE_ADDR + offset, AHB_HSIZE_WORD, expected, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    begin
      repeat (cycles) @(posedge hclk);
      #1ns;
    end
  endtask

  task automatic expect_outputs(
    input logic expected_irq,
    input logic expected_reset_req,
    input string label
  );
    begin
      #1ns;
      if (wdg_irq !== expected_irq || wdg_reset_req !== expected_reset_req) begin
        $error("%s: expected irq=%0b reset_req=%0b got irq=%0b reset_req=%0b",
               label, expected_irq, expected_reset_req, wdg_irq, wdg_reset_req);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic clear_wdg(input logic keep_enable);
    logic [31:0] ctrl_value;
    begin
      ctrl_value = 32'h1 << WDG_CTRL_CLEAR_BIT;
      if (keep_enable) begin
        ctrl_value[WDG_CTRL_ENABLE_BIT] = 1'b1;
        ctrl_value[WDG_CTRL_IRQ_EN_BIT] = 1'b1;
        ctrl_value[WDG_CTRL_RESET_EN_BIT] = 1'b1;
      end
      write_reg(WDG_CTRL_OFFSET, ctrl_value, "clear watchdog");
    end
  endtask

  task automatic check_reset_registers;
    begin
      read_reg(WDG_CTRL_OFFSET, 32'h0000_0000, "reset ctrl");
      read_reg(WDG_STATUS_OFFSET, 32'h0000_0000, "reset status");
      read_reg(WDG_TIMEOUT_OFFSET, 32'h0000_FFFF, "reset timeout");
      read_reg(WDG_COUNT_OFFSET, 32'h0000_0000, "reset count");
    end
  endtask

  task automatic check_timeout_irq_reset;
    begin
      write_reg(WDG_TIMEOUT_OFFSET, 32'd4, "timeout=4");
      write_reg(WDG_CTRL_OFFSET,
                (32'h1 << WDG_CTRL_ENABLE_BIT) |
                (32'h1 << WDG_CTRL_IRQ_EN_BIT) |
                (32'h1 << WDG_CTRL_RESET_EN_BIT),
                "enable irq reset");
      read_reg(WDG_CTRL_OFFSET, 32'h0000_0007, "ctrl readback");
      read_reg(WDG_STATUS_OFFSET, 32'h0000_0008, "running status");
      wait_cycles(4);
      expect_outputs(1'b1, 1'b1, "expired outputs");
      read_reg(WDG_STATUS_OFFSET, 32'h0000_0003, "expired status");
      timeout_count++;
    end
  endtask

  task automatic check_kick_clears_and_restarts;
    begin
      write_reg(WDG_KICK_OFFSET, WDG_KICK_VALUE, "valid kick");
      expect_outputs(1'b0, 1'b0, "kick clears outputs");
      read_reg(WDG_COUNT_OFFSET, 32'h0000_0001, "kick count restarts");
      wait_cycles(2);
      write_reg(WDG_KICK_OFFSET, WDG_KICK_VALUE, "valid kick before expiry");
      wait_cycles(2);
      expect_outputs(1'b0, 1'b0, "kick prevented expiry");
      kick_count++;
    end
  endtask

  task automatic check_bad_key_and_clear;
    begin
      clear_wdg(1'b0);
      write_reg(WDG_TIMEOUT_OFFSET, 32'd20, "bad key timeout guard");
      write_reg(WDG_CTRL_OFFSET,
                (32'h1 << WDG_CTRL_ENABLE_BIT) |
                (32'h1 << WDG_CTRL_IRQ_EN_BIT) |
                (32'h1 << WDG_CTRL_RESET_EN_BIT),
                "enable before bad key");
      write_reg(WDG_KICK_OFFSET, 32'hBAD0_0001, "bad kick key");
      read_reg(WDG_STATUS_OFFSET, 32'h0000_000C, "keyerr running status");
      clear_wdg(1'b0);
      read_reg(WDG_STATUS_OFFSET, 32'h0000_0000, "status after clear");
      expect_outputs(1'b0, 1'b0, "clear outputs");
      kick_count++;
    end
  endtask

  task automatic check_irq_mask;
    begin
      write_reg(WDG_TIMEOUT_OFFSET, 32'd3, "timeout=3 irq masked");
      write_reg(WDG_CTRL_OFFSET,
                (32'h1 << WDG_CTRL_ENABLE_BIT) |
                (32'h1 << WDG_CTRL_RESET_EN_BIT),
                "enable reset only");
      wait_cycles(3);
      expect_outputs(1'b0, 1'b1, "irq masked reset asserted");
      read_reg(WDG_STATUS_OFFSET, 32'h0000_0003, "masked expired status");
      clear_wdg(1'b0);
      timeout_count++;
    end
  endtask

  task automatic check_error_paths;
    begin
      ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "misaligned read");
      ahb_write(BASE_ADDR + WDG_CTRL_OFFSET, AHB_HSIZE_HALF, 32'h0000_0001,
                AHB_HRESP_ERROR, "unsupported half write");
      ahb_read(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "unknown register read");
      ahb_write(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, 32'h0000_0001,
                AHB_HRESP_ERROR, "unknown register write");
      ahb_read(BASE_ADDR + REGION_BYTES, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "out of range read");
    end
  endtask

  task automatic check_random_timeouts(input int unsigned count);
    logic [31:0] timeout_value;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        clear_wdg(1'b0);
        timeout_value = $urandom_range(2, 8);
        write_reg(WDG_TIMEOUT_OFFSET, timeout_value, "random timeout");
        write_reg(WDG_CTRL_OFFSET,
                  (32'h1 << WDG_CTRL_ENABLE_BIT) |
                  (32'h1 << WDG_CTRL_IRQ_EN_BIT),
                  "random enable");
        wait_cycles(timeout_value);
        expect_outputs(1'b1, 1'b0, "random irq only expiry");
        random_count++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (reg_count < 35 || timeout_count < 2 || kick_count < 2) begin
        $error("coverage miss: reg=%0d timeout=%0d kick=%0d",
               reg_count, timeout_count, kick_count);
        $fatal(1);
      end
      if (error_count < 5 || random_count < 4) begin
        $error("coverage miss: error=%0d random=%0d", error_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_wdg coverage: pass_count=%0d reg_count=%0d timeout_count=%0d kick_count=%0d error_count=%0d random_count=%0d",
               pass_count, reg_count, timeout_count, kick_count, error_count,
               random_count);
    end
  endtask

  initial begin
    void'($urandom(32'h5750_7101));
    pass_count = 0;
    reg_count = 0;
    timeout_count = 0;
    kick_count = 0;
    error_count = 0;
    random_count = 0;

    apply_reset();
    check_reset_registers();
    check_timeout_irq_reset();
    check_kick_clears_and_restarts();
    check_bad_key_and_clear();
    check_irq_mask();
    check_error_paths();
    check_random_timeouts(4);
    check_coverage_summary();

    $display("tb_ahb_wdg PASS");
    $finish;
  end
endmodule
