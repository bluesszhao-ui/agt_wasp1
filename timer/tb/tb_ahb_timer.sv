`timescale 1ns/1ps

module tb_ahb_timer;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = TIMER_BASE;
  localparam int REGION_BYTES = PERIPH_SIZE;

  logic                  hclk;
  logic                  hresetn;
  logic                  hsel;
  logic [ADDR_WIDTH-1:0] haddr;
  logic [1:0]            htrans;
  logic                  hwrite;
  logic [2:0]            hsize;
  logic [DATA_WIDTH-1:0] hwdata;
  logic [DATA_WIDTH-1:0] hrdata;
  logic                  hready;
  logic                  hresp;
  logic                  timer_irq;

  int unsigned pass_count;
  int unsigned reg_count;
  int unsigned count_count;
  int unsigned irq_count;
  int unsigned error_count;
  int unsigned random_count;

  ahb_timer #(
    .BASE_ADDR(BASE_ADDR),
    .REGION_BYTES(REGION_BYTES)
  ) u_ahb_timer (
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
    .timer_irq_o(timer_irq)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

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

  task automatic apply_reset;
    begin
      hresetn = 1'b0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1 || hresp !== AHB_HRESP_OKAY ||
          hrdata !== '0 || timer_irq !== 1'b0) begin
        $error("reset: unexpected hready=%0b hresp=%0b hrdata=0x%08h irq=%0b",
               hready, hresp, hrdata, timer_irq);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

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
        $error("%s: address phase expected hready=1", label);
        $fatal(1);
      end

      @(negedge hclk);
      drive_idle();
      hwdata = data;

      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: write response mismatch expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

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
        $error("%s: read response mismatch expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_OKAY && hrdata !== expected_data) begin
        $error("%s: read data mismatch expected=0x%08h got=0x%08h",
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

  task automatic set_mtime(input logic [63:0] value);
    begin
      write_reg(TIMER_MTIME_LO_OFFSET, value[31:0], "mtime lo write");
      write_reg(TIMER_MTIME_HI_OFFSET, value[63:32], "mtime hi write");
    end
  endtask

  task automatic set_cmp(input logic [63:0] value);
    begin
      write_reg(TIMER_CMP_LO_OFFSET, value[31:0], "cmp lo write");
      write_reg(TIMER_CMP_HI_OFFSET, value[63:32], "cmp hi write");
    end
  endtask

  task automatic expect_irq(input logic expected, input string label);
    begin
      #1ns;
      if (timer_irq !== expected) begin
        $error("%s: irq mismatch expected=%0b got=%0b", label, expected, timer_irq);
        $fatal(1);
      end
      irq_count++;
      pass_count++;
    end
  endtask

  task automatic wait_cycles(input int unsigned cycles);
    begin
      repeat (cycles) @(posedge hclk);
      #1ns;
    end
  endtask

  task automatic check_basic_count_and_irq;
    begin
      set_mtime(64'd0);
      set_cmp(64'd5);
      write_reg(TIMER_CTRL_OFFSET,
                (32'h1 << TIMER_CTRL_ENABLE_BIT) |
                (32'h1 << TIMER_CTRL_IRQ_EN_BIT),
                "enable timer irq");
      read_reg(TIMER_CTRL_OFFSET, 32'h0000_0003, "ctrl readback");
      expect_irq(1'b0, "irq before compare");
      wait_cycles(6);
      expect_irq(1'b1, "irq after compare");
      read_reg(TIMER_STATUS_OFFSET, 32'h0000_0001, "pending status");
      set_cmp(64'd100);
      wait_cycles(1);
      expect_irq(1'b0, "irq clears after cmp future");
      read_reg(TIMER_STATUS_OFFSET, 32'h0000_0000, "pending clear status");
      count_count++;
    end
  endtask

  task automatic check_irq_mask;
    begin
      set_mtime(64'd10);
      set_cmp(64'd5);
      write_reg(TIMER_CTRL_OFFSET, 32'h0000_0001, "enable no irq mask");
      wait_cycles(1);
      expect_irq(1'b0, "irq masked");
      read_reg(TIMER_STATUS_OFFSET, 32'h0000_0001, "pending while masked");
      write_reg(TIMER_CTRL_OFFSET, 32'h0000_0003, "enable irq mask");
      expect_irq(1'b1, "irq unmasked");
      count_count++;
    end
  endtask

  task automatic check_disabled_stops_count;
    logic [31:0] lo_value;
    begin
      write_reg(TIMER_CTRL_OFFSET, 32'h0000_0000, "disable timer");
      set_mtime(64'd42);
      wait_cycles(4);
      @(negedge hclk);
      hsel = 1'b1;
      haddr = BASE_ADDR + TIMER_MTIME_LO_OFFSET;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b0;
      hsize = AHB_HSIZE_WORD;
      hwdata = '0;
      @(posedge hclk);
      @(negedge hclk);
      drive_idle();
      @(posedge hclk);
      #1ns;
      lo_value = hrdata;
      if (hresp !== AHB_HRESP_OKAY || lo_value !== 32'd42) begin
        $error("disabled count: expected mtime_lo=42 got=0x%08h hresp=%0b",
               lo_value, hresp);
        $fatal(1);
      end
      count_count++;
      pass_count++;
    end
  endtask

  task automatic check_random_cmp(input int unsigned count);
    logic [31:0] base_count;
    logic [31:0] delta;
    begin
      write_reg(TIMER_CTRL_OFFSET, 32'h0000_0000, "disable before random");
      for (int unsigned idx = 0; idx < count; idx++) begin
        base_count = $urandom_range(0, 100);
        delta = $urandom_range(2, 8);
        set_mtime({32'h0, base_count});
        set_cmp({32'h0, base_count + delta});
        write_reg(TIMER_CTRL_OFFSET, 32'h0000_0003, "random enable");
        wait_cycles(delta + 1);
        expect_irq(1'b1, "random irq");
        write_reg(TIMER_CTRL_OFFSET, 32'h0000_0000, "random disable");
        random_count++;
      end
    end
  endtask

  task automatic check_error_paths;
    begin
      ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "misaligned read");
      ahb_write(BASE_ADDR + TIMER_CTRL_OFFSET, AHB_HSIZE_HALF, 32'h0000_0001,
                AHB_HRESP_ERROR, "unsupported half write");
      ahb_read(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "unknown register read");
      ahb_write(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, 32'h0000_0001,
                AHB_HRESP_ERROR, "unknown register write");
      ahb_read(BASE_ADDR + REGION_BYTES, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "out of range read");
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (reg_count < 40 || count_count < 3 || irq_count < 8) begin
        $error("coverage miss: reg=%0d count=%0d irq=%0d",
               reg_count, count_count, irq_count);
        $fatal(1);
      end
      if (error_count < 5 || random_count < 4) begin
        $error("coverage miss: error=%0d random=%0d", error_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_timer coverage: pass_count=%0d reg_count=%0d count_count=%0d irq_count=%0d error_count=%0d random_count=%0d",
               pass_count, reg_count, count_count, irq_count, error_count,
               random_count);
    end
  endtask

  initial begin
    void'($urandom(32'h5750_7001));
    pass_count = 0;
    reg_count = 0;
    count_count = 0;
    irq_count = 0;
    error_count = 0;
    random_count = 0;

    apply_reset();
    read_reg(TIMER_CTRL_OFFSET, 32'h0000_0000, "initial ctrl");
    read_reg(TIMER_STATUS_OFFSET, 32'h0000_0000, "initial status");
    read_reg(TIMER_CMP_LO_OFFSET, 32'hFFFF_FFFF, "initial cmp lo");
    read_reg(TIMER_CMP_HI_OFFSET, 32'hFFFF_FFFF, "initial cmp hi");

    check_disabled_stops_count();
    check_basic_count_and_irq();
    check_irq_mask();
    check_error_paths();
    check_random_cmp(4);
    check_coverage_summary();

    $display("tb_ahb_timer PASS");
    $finish;
  end
endmodule
