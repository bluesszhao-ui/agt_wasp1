`timescale 1ns/1ps

module tb_ahb_gpio;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = GPIO_BASE;
  localparam int REGION_BYTES = PERIPH_SIZE;
  localparam int GPIO_WIDTH = 32;

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
  logic [GPIO_WIDTH-1:0] gpio_in;
  logic [GPIO_WIDTH-1:0] gpio_out;
  logic [GPIO_WIDTH-1:0] gpio_oe;
  logic                  gpio_irq;

  int unsigned pass_count;
  int unsigned reg_count;
  int unsigned data_count;
  int unsigned irq_count;
  int unsigned error_count;
  int unsigned random_count;

  ahb_gpio #(
    .BASE_ADDR(BASE_ADDR),
    .REGION_BYTES(REGION_BYTES),
    .GPIO_WIDTH(GPIO_WIDTH)
  ) u_ahb_gpio (
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
    .gpio_in_i(gpio_in),
    .gpio_out_o(gpio_out),
    .gpio_oe_o(gpio_oe),
    .gpio_irq_o(gpio_irq)
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

  task automatic wait_cycles(input int unsigned cycles);
    begin
      repeat (cycles) @(posedge hclk);
      #1ns;
    end
  endtask

  task automatic apply_reset;
    begin
      gpio_in = '0;
      hresetn = 1'b0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1 || hresp !== AHB_HRESP_OKAY || hrdata !== '0 ||
          gpio_out !== '0 || gpio_oe !== '0 || gpio_irq !== 1'b0) begin
        $error("reset: unexpected hready=%0b hresp=%0b hrdata=0x%08h out=0x%08h oe=0x%08h irq=%0b",
               hready, hresp, hrdata, gpio_out, gpio_oe, gpio_irq);
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

  task automatic expect_irq(input logic expected, input string label);
    begin
      #1ns;
      if (gpio_irq !== expected) begin
        $error("%s: irq mismatch expected=%0b got=%0b", label, expected, gpio_irq);
        $fatal(1);
      end
      irq_count++;
      pass_count++;
    end
  endtask

  task automatic drive_gpio_in(input logic [31:0] value);
    begin
      gpio_in = value;
      wait_cycles(3);
    end
  endtask

  task automatic check_output_controls;
    begin
      write_reg(GPIO_DATA_OUT_OFFSET, 32'h0000_00A5, "data out write");
      read_reg(GPIO_DATA_OUT_OFFSET, 32'h0000_00A5, "data out readback");
      write_reg(GPIO_DIR_OFFSET, 32'h0000_00FF, "dir write");
      read_reg(GPIO_DIR_OFFSET, 32'h0000_00FF, "dir readback");
      if (gpio_out !== 32'h0000_00A5 || gpio_oe !== 32'h0000_00FF) begin
        $error("gpio outputs mismatch out=0x%08h oe=0x%08h", gpio_out, gpio_oe);
        $fatal(1);
      end
      write_reg(GPIO_SET_OFFSET, 32'h0000_0F00, "set write");
      read_reg(GPIO_DATA_OUT_OFFSET, 32'h0000_0FA5, "set readback");
      write_reg(GPIO_CLR_OFFSET, 32'h0000_00A0, "clear write");
      read_reg(GPIO_DATA_OUT_OFFSET, 32'h0000_0F05, "clear readback");
      write_reg(GPIO_TOGGLE_OFFSET, 32'h0000_00FF, "toggle write");
      read_reg(GPIO_DATA_OUT_OFFSET, 32'h0000_0FFA, "toggle readback");
      data_count++;
    end
  endtask

  task automatic check_input_sync;
    begin
      drive_gpio_in(32'hA5A5_5A5A);
      read_reg(GPIO_DATA_IN_OFFSET, 32'hA5A5_5A5A, "input sync read");
      drive_gpio_in(32'h0000_0000);
      read_reg(GPIO_DATA_IN_OFFSET, 32'h0000_0000, "input low read");
      data_count++;
    end
  endtask

  task automatic check_level_irq;
    begin
      write_reg(GPIO_IRQ_TYPE_OFFSET, 32'h0000_0000, "level irq type");
      write_reg(GPIO_IRQ_POL_OFFSET, 32'h0000_0001, "level high polarity");
      write_reg(GPIO_IRQ_EN_OFFSET, 32'h0000_0001, "level irq enable");
      drive_gpio_in(32'h0000_0001);
      expect_irq(1'b1, "level high irq");
      read_reg(GPIO_IRQ_STATUS_OFFSET, 32'h0000_0001, "level status");
      write_reg(GPIO_IRQ_STATUS_OFFSET, 32'h0000_0001, "level status clear while high");
      wait_cycles(1);
      expect_irq(1'b1, "level reasserts while high");
      drive_gpio_in(32'h0000_0000);
      write_reg(GPIO_IRQ_STATUS_OFFSET, 32'h0000_0001, "level status clear low");
      expect_irq(1'b0, "level clears low");
    end
  endtask

  task automatic check_edge_irq;
    begin
      write_reg(GPIO_IRQ_EN_OFFSET, 32'h0000_0000, "disable irq before edge config");
      write_reg(GPIO_IRQ_STATUS_OFFSET, 32'hFFFF_FFFF, "clear all irq status");
      drive_gpio_in(32'h0000_0000);
      write_reg(GPIO_IRQ_TYPE_OFFSET, 32'h0000_0006, "edge irq type bits1_2");
      write_reg(GPIO_IRQ_POL_OFFSET, 32'h0000_0002, "rise bit1 fall bit2");
      write_reg(GPIO_IRQ_EN_OFFSET, 32'h0000_0006, "edge irq enable");
      drive_gpio_in(32'h0000_0002);
      expect_irq(1'b1, "rising edge irq");
      read_reg(GPIO_IRQ_STATUS_OFFSET, 32'h0000_0002, "rising edge status");
      write_reg(GPIO_IRQ_STATUS_OFFSET, 32'h0000_0002, "clear rising edge");
      expect_irq(1'b0, "rising edge clear");
      drive_gpio_in(32'h0000_0006);
      expect_irq(1'b0, "fall setup no irq");
      drive_gpio_in(32'h0000_0002);
      expect_irq(1'b1, "falling edge irq");
      read_reg(GPIO_IRQ_STATUS_OFFSET, 32'h0000_0004, "falling edge status");
      write_reg(GPIO_IRQ_EN_OFFSET, 32'h0000_0000, "mask edge irq");
      expect_irq(1'b0, "edge irq masked");
      irq_count++;
    end
  endtask

  task automatic check_error_paths;
    begin
      ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "misaligned read");
      ahb_write(BASE_ADDR + GPIO_DATA_OUT_OFFSET, AHB_HSIZE_BYTE, 32'h1,
                AHB_HRESP_ERROR, "unsupported byte write");
      ahb_read(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "unknown register read");
      ahb_write(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, 32'h1,
                AHB_HRESP_ERROR, "unknown register write");
      ahb_read(BASE_ADDR + REGION_BYTES, AHB_HSIZE_WORD, '0,
               AHB_HRESP_ERROR, "out of range read");
    end
  endtask

  task automatic check_random_outputs(input int unsigned count);
    logic [31:0] value;
    logic [31:0] mask;
    logic [31:0] expected;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        value = $urandom();
        mask = $urandom();
        write_reg(GPIO_DATA_OUT_OFFSET, value, "random out write");
        write_reg(GPIO_TOGGLE_OFFSET, mask, "random toggle");
        expected = value ^ mask;
        read_reg(GPIO_DATA_OUT_OFFSET, expected, "random out readback");
        random_count++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (reg_count < 40 || data_count < 2 || irq_count < 8) begin
        $error("coverage miss: reg=%0d data=%0d irq=%0d",
               reg_count, data_count, irq_count);
        $fatal(1);
      end
      if (error_count < 5 || random_count < 8) begin
        $error("coverage miss: error=%0d random=%0d", error_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_gpio coverage: pass_count=%0d reg_count=%0d data_count=%0d irq_count=%0d error_count=%0d random_count=%0d",
               pass_count, reg_count, data_count, irq_count, error_count,
               random_count);
    end
  endtask

  initial begin
    void'($urandom(32'h5750_6100));
    pass_count = 0;
    reg_count = 0;
    data_count = 0;
    irq_count = 0;
    error_count = 0;
    random_count = 0;

    apply_reset();
    read_reg(GPIO_DATA_OUT_OFFSET, 32'h0000_0000, "initial out");
    read_reg(GPIO_DIR_OFFSET, 32'h0000_0000, "initial dir");
    read_reg(GPIO_IRQ_EN_OFFSET, 32'h0000_0000, "initial irq en");
    read_reg(GPIO_IRQ_STATUS_OFFSET, 32'h0000_0000, "initial irq status");

    check_output_controls();
    check_input_sync();
    check_level_irq();
    check_edge_irq();
    check_error_paths();
    check_random_outputs(8);
    check_coverage_summary();

    $display("tb_ahb_gpio PASS");
    $finish;
  end
endmodule
