`timescale 1ns/1ps

module tb_ahb_uart;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = UART_BASE;
  localparam int REGION_BYTES = PERIPH_SIZE;
  localparam int FIFO_DEPTH = 4;
  localparam int BAUD_DIV = 2;
  localparam int CHAR_CYCLES = BAUD_DIV * 12;

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
  logic                  uart_rx;
  logic                  uart_tx;
  logic                  uart_irq;

  int unsigned pass_count;
  int unsigned reg_count;
  int unsigned tx_count;
  int unsigned rx_count;
  int unsigned irq_count;
  int unsigned error_count;
  int unsigned random_count;

  ahb_uart #(
    .BASE_ADDR(BASE_ADDR),
    .REGION_BYTES(REGION_BYTES),
    .FIFO_DEPTH(FIFO_DEPTH)
  ) u_ahb_uart (
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
    .uart_rx_i(uart_rx),
    .uart_tx_o(uart_tx),
    .uart_irq_o(uart_irq)
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
      uart_rx = 1'b1;
      hresetn = 1'b0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1 || hresp !== AHB_HRESP_OKAY ||
          hrdata !== '0 || uart_tx !== 1'b1 || uart_irq !== 1'b0) begin
        $error("reset: hready=%0b hresp=%0b hrdata=0x%08h tx=%0b irq=%0b",
               hready, hresp, hrdata, uart_tx, uart_irq);
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
    input logic [DATA_WIDTH-1:0] mask,
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
      if (expected_resp == AHB_HRESP_OKAY &&
          ((hrdata & mask) !== (expected_data & mask))) begin
        $error("%s: read data mismatch expected=0x%08h mask=0x%08h got=0x%08h",
               label, expected_data, mask, hrdata);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic write_reg(input logic [31:0] offset, input logic [31:0] data, input string label);
    begin
      ahb_write(BASE_ADDR + offset, AHB_HSIZE_WORD, data, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic read_reg(
    input logic [31:0] offset,
    input logic [31:0] expected,
    input logic [31:0] mask,
    input string label
  );
    begin
      ahb_read(BASE_ADDR + offset, AHB_HSIZE_WORD, expected, mask, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic expect_irq(input logic expected, input string label);
    begin
      #1ns;
      if (uart_irq !== expected) begin
        $error("%s: irq mismatch expected=%0b got=%0b", label, expected, uart_irq);
        $fatal(1);
      end
      irq_count++;
      pass_count++;
    end
  endtask

  task automatic enable_uart(input logic irq_en);
    logic [31:0] ctrl;
    begin
      ctrl = (32'h1 << UART_CTRL_ENABLE_BIT) |
             (32'h1 << UART_CTRL_TX_EN_BIT) |
             (32'h1 << UART_CTRL_RX_EN_BIT);
      if (irq_en) begin
        ctrl |= (32'h1 << UART_CTRL_TX_IRQ_EN_BIT) |
                (32'h1 << UART_CTRL_RX_IRQ_EN_BIT) |
                (32'h1 << UART_CTRL_OVR_IRQ_EN_BIT);
      end
      write_reg(UART_BAUD_OFFSET, BAUD_DIV[31:0], "baud write");
      write_reg(UART_CTRL_OFFSET, ctrl, "ctrl enable");
    end
  endtask

  task automatic loopback_tx_to_rx(input int unsigned cycles);
    begin
      for (int unsigned idx = 0; idx < cycles; idx++) begin
        uart_rx = uart_tx;
        @(posedge hclk);
        #1ns;
      end
      uart_rx = 1'b1;
    end
  endtask

  task automatic send_external_byte(input logic [7:0] data);
    begin
      uart_rx = 1'b0;
      wait_cycles(BAUD_DIV);
      for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
        uart_rx = data[bit_idx];
        wait_cycles(BAUD_DIV);
      end
      uart_rx = 1'b1;
      wait_cycles(BAUD_DIV * 2);
      rx_count++;
    end
  endtask

  task automatic check_loopback_byte(input logic [7:0] data);
    begin
      ahb_write(BASE_ADDR + UART_DATA_OFFSET, AHB_HSIZE_WORD, {24'h0, data},
                AHB_HRESP_OKAY, "tx data write");
      tx_count++;
      loopback_tx_to_rx(CHAR_CYCLES);
      ahb_read(BASE_ADDR + UART_DATA_OFFSET, AHB_HSIZE_WORD, {24'h0, data},
               32'h0000_00FF, AHB_HRESP_OKAY, "rx data read");
      rx_count++;
    end
  endtask

  task automatic enqueue_loopback_byte(input logic [7:0] data);
    begin
      ahb_write(BASE_ADDR + UART_DATA_OFFSET, AHB_HSIZE_WORD, {24'h0, data},
                AHB_HRESP_OKAY, "enqueue loopback tx");
      tx_count++;
      loopback_tx_to_rx(CHAR_CYCLES);
      rx_count++;
    end
  endtask

  task automatic check_tx_fifo_full;
    begin
      write_reg(UART_CTRL_OFFSET, 32'h0000_0001, "disable tx rx keep enabled");
      for (int idx = 0; idx < FIFO_DEPTH; idx++) begin
        ahb_write(BASE_ADDR + UART_DATA_OFFSET, AHB_HSIZE_WORD, 32'(idx),
                  AHB_HRESP_OKAY, "fill tx fifo");
      end
      ahb_write(BASE_ADDR + UART_DATA_OFFSET, AHB_HSIZE_WORD, 32'h55,
                AHB_HRESP_ERROR, "tx fifo full error");
      read_reg(UART_STATUS_OFFSET, 32'h0000_0002, 32'h0000_0002, "tx full status");
    end
  endtask

  task automatic check_irq_paths;
    begin
      enable_uart(1'b1);
      wait_cycles(2);
      expect_irq(1'b1, "tx empty irq");
      read_reg(UART_IRQ_STATUS_OFFSET, 32'h0000_0001, 32'h0000_0001, "tx empty irq status");
      write_reg(UART_IRQ_STATUS_OFFSET, 32'h0000_0001, "clear tx empty irq");

      enqueue_loopback_byte(8'h3C);
      expect_irq(1'b1, "rx avail irq");
      read_reg(UART_IRQ_STATUS_OFFSET, 32'h0000_0002, 32'h0000_0002, "rx avail irq status");
      ahb_read(BASE_ADDR + UART_DATA_OFFSET, AHB_HSIZE_WORD, 32'h0000_003C,
               32'h0000_00FF, AHB_HRESP_OKAY, "rx irq data read");
      write_reg(UART_IRQ_STATUS_OFFSET, 32'h0000_0002, "clear rx avail irq");

      for (int idx = 0; idx < FIFO_DEPTH + 1; idx++) begin
        enqueue_loopback_byte(8'(8'h80 + idx));
      end
      expect_irq(1'b1, "rx overrun irq");
      read_reg(UART_STATUS_OFFSET, 32'h0000_0020, 32'h0000_0020, "overrun status");
      read_reg(UART_IRQ_STATUS_OFFSET, 32'h0000_0004, 32'h0000_0004, "overrun irq status");
      write_reg(UART_IRQ_STATUS_OFFSET, 32'h0000_0004, "clear overrun irq");
    end
  endtask

  task automatic drain_rx_fifo(input int unsigned max_count);
    begin
      for (int unsigned idx = 0; idx < max_count; idx++) begin
        ahb_read(BASE_ADDR + UART_DATA_OFFSET, AHB_HSIZE_WORD, '0,
                 32'h0000_0000, AHB_HRESP_OKAY, "drain rx fifo");
      end
    end
  endtask

  task automatic check_error_paths;
    begin
      ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0, '1,
               AHB_HRESP_ERROR, "misaligned read");
      ahb_write(BASE_ADDR + UART_CTRL_OFFSET, AHB_HSIZE_BYTE, 32'h1,
                AHB_HRESP_ERROR, "unsupported byte write");
      ahb_read(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, '0, '1,
               AHB_HRESP_ERROR, "unknown register read");
      ahb_write(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, 32'h1,
                AHB_HRESP_ERROR, "unknown register write");
      ahb_read(BASE_ADDR + REGION_BYTES, AHB_HSIZE_WORD, '0, '1,
               AHB_HRESP_ERROR, "out of range read");
    end
  endtask

  task automatic check_random_loopback(input int unsigned count);
    logic [7:0] data;
    begin
      enable_uart(1'b0);
      for (int unsigned idx = 0; idx < count; idx++) begin
        data = 8'($urandom());
        check_loopback_byte(data);
        random_count++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (reg_count < 12 || tx_count < 4 || rx_count < 8 || irq_count < 3) begin
        $error("coverage miss: reg=%0d tx=%0d rx=%0d irq=%0d",
               reg_count, tx_count, rx_count, irq_count);
        $fatal(1);
      end
      if (error_count < 6 || random_count < 4) begin
        $error("coverage miss: error=%0d random=%0d", error_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_uart coverage: pass_count=%0d reg_count=%0d tx_count=%0d rx_count=%0d irq_count=%0d error_count=%0d random_count=%0d",
               pass_count, reg_count, tx_count, rx_count, irq_count,
               error_count, random_count);
    end
  endtask

  initial begin
    void'($urandom(32'h5750_4171));
    pass_count = 0;
    reg_count = 0;
    tx_count = 0;
    rx_count = 0;
    irq_count = 0;
    error_count = 0;
    random_count = 0;

    apply_reset();
    read_reg(UART_STATUS_OFFSET, 32'h0000_0005, 32'h0000_0005, "initial status");
    read_reg(UART_CTRL_OFFSET, 32'h0000_0000, 32'h0000_003F, "initial ctrl");
    read_reg(UART_IRQ_STATUS_OFFSET, 32'h0000_0000, 32'h0000_0007, "initial irq status");

    enable_uart(1'b0);
    check_loopback_byte(8'hA5);
    check_loopback_byte(8'h5A);
    check_random_loopback(4);
    drain_rx_fifo(FIFO_DEPTH);
    check_irq_paths();
    check_tx_fifo_full();
    check_error_paths();
    check_coverage_summary();

    $display("tb_ahb_uart PASS");
    $finish;
  end
endmodule
