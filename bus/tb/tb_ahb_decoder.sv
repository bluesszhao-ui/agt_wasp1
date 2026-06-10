module tb_ahb_decoder;
  import wasp1_pkg::*;

  logic [ADDR_WIDTH-1:0] haddr;
  logic                  active;
  logic [AHB_SLAVE_COUNT-1:0] hsel;
  logic                  default_sel;

  int unsigned pass_count;
  int unsigned default_count;
  int unsigned inactive_count;
  int unsigned slave_hit_count [AHB_SLAVE_COUNT];

  ahb_decoder u_ahb_decoder (
    .haddr_i(haddr),
    .active_i(active),
    .hsel_o(hsel),
    .default_sel_o(default_sel)
  );

  function automatic logic [ADDR_WIDTH-1:0] region_mid(
    input logic [ADDR_WIDTH-1:0] base,
    input logic [ADDR_WIDTH-1:0] size
  );
    region_mid = base + (size >> 1);
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] region_end(
    input logic [ADDR_WIDTH-1:0] base,
    input logic [ADDR_WIDTH-1:0] size
  );
    region_end = base + size - 1;
  endfunction

  function automatic bit addr_in_range(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [ADDR_WIDTH-1:0] base,
    input logic [ADDR_WIDTH-1:0] size
  );
    addr_in_range = (addr >= base) && (addr < (base + size));
  endfunction

  function automatic int expected_decode(input logic [ADDR_WIDTH-1:0] addr);
    if (addr_in_range(addr, OTP_BASE, OTP_SIZE)) begin
      expected_decode = AHB_SLAVE_OTP;
    end else if (addr_in_range(addr, ISRAM_BASE, ISRAM_SIZE)) begin
      expected_decode = AHB_SLAVE_ISRAM;
    end else if (addr_in_range(addr, DSRAM_BASE, DSRAM_SIZE)) begin
      expected_decode = AHB_SLAVE_DSRAM;
    end else if (addr_in_range(addr, DMA_BASE, PERIPH_SIZE)) begin
      expected_decode = AHB_SLAVE_DMA;
    end else if (addr_in_range(addr, WDG_BASE, PERIPH_SIZE)) begin
      expected_decode = AHB_SLAVE_WDG;
    end else if (addr_in_range(addr, TIMER_BASE, PERIPH_SIZE)) begin
      expected_decode = AHB_SLAVE_TIMER;
    end else if (addr_in_range(addr, INTC_BASE, PERIPH_SIZE)) begin
      expected_decode = AHB_SLAVE_INTC;
    end else if (addr_in_range(addr, UART_BASE, PERIPH_SIZE)) begin
      expected_decode = AHB_SLAVE_UART;
    end else if (addr_in_range(addr, I2C_BASE, PERIPH_SIZE)) begin
      expected_decode = AHB_SLAVE_I2C;
    end else if (addr_in_range(addr, GPIO_BASE, PERIPH_SIZE)) begin
      expected_decode = AHB_SLAVE_GPIO;
    end else begin
      expected_decode = AHB_SLAVE_DEFAULT;
    end
  endfunction

  task automatic check_inactive(input logic [ADDR_WIDTH-1:0] addr, input string label);
    begin
      haddr = addr;
      active = 1'b0;
      #1;
      if (hsel !== '0 || default_sel !== 1'b0) begin
        $error("%s: inactive decode should select no slave", label);
        $fatal(1);
      end
      inactive_count++;
      pass_count++;
    end
  endtask

  task automatic check_decode(
    input logic [ADDR_WIDTH-1:0] addr,
    input int                    expected_idx,
    input string                 label
  );
    logic [AHB_SLAVE_COUNT-1:0] expected;
    begin
      haddr = addr;
      active = 1'b1;
      expected = '0;
      expected[expected_idx] = 1'b1;
      #1;
      if (hsel !== expected) begin
        $error("%s: addr=0x%08h expected hsel=0x%0h got hsel=0x%0h",
               label, addr, expected, hsel);
        $fatal(1);
      end
      if (!$onehot(hsel)) begin
        $error("%s: hsel is not one-hot, hsel=0x%0h", label, hsel);
        $fatal(1);
      end
      if (default_sel !== expected[AHB_SLAVE_DEFAULT]) begin
        $error("%s: default_sel mismatch", label);
        $fatal(1);
      end
      slave_hit_count[expected_idx]++;
      if (expected_idx == AHB_SLAVE_DEFAULT) begin
        default_count++;
      end
      pass_count++;
    end
  endtask

  task automatic check_region(
    input logic [ADDR_WIDTH-1:0] base,
    input logic [ADDR_WIDTH-1:0] size,
    input int                    expected_idx,
    input string                 label
  );
    begin
      check_decode(base, expected_idx, {label, " base"});
      check_decode(region_mid(base, size), expected_idx, {label, " mid"});
      check_decode(region_end(base, size), expected_idx, {label, " end"});
      if (base != '0) begin
        check_decode(base - 1, expected_decode(base - 1), {label, " before"});
      end
      check_decode(base + size, expected_decode(base + size), {label, " after"});
    end
  endtask

  task automatic check_random_addresses(input int unsigned count);
    logic [ADDR_WIDTH-1:0] rand_addr;
    int expected_idx;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        rand_addr = $urandom();
        expected_idx = expected_decode(rand_addr);
        check_decode(rand_addr, expected_idx, "deterministic random");
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      for (int idx = 0; idx < AHB_SLAVE_COUNT; idx++) begin
        if (slave_hit_count[idx] == 0) begin
          $error("coverage miss: slave index %0d was never selected", idx);
          $fatal(1);
        end
      end
      if (default_count < 8) begin
        $error("coverage miss: default path count too low: %0d", default_count);
        $fatal(1);
      end
      if (inactive_count < 2) begin
        $error("coverage miss: inactive path count too low: %0d", inactive_count);
        $fatal(1);
      end
      $display("tb_ahb_decoder coverage: pass_count=%0d default_count=%0d inactive_count=%0d",
               pass_count, default_count, inactive_count);
      for (int idx = 0; idx < AHB_SLAVE_COUNT; idx++) begin
        $display("tb_ahb_decoder coverage: slave[%0d] hits=%0d", idx, slave_hit_count[idx]);
      end
    end
  endtask

  initial begin
    void'($urandom(32'h5750_0001));
    pass_count = 0;
    default_count = 0;
    inactive_count = 0;
    foreach (slave_hit_count[idx]) begin
      slave_hit_count[idx] = 0;
    end

    haddr = '0;
    active = 1'b0;
    check_inactive('0, "inactive zero address");

    check_region(OTP_BASE, OTP_SIZE, AHB_SLAVE_OTP, "otp");
    check_region(ISRAM_BASE, ISRAM_SIZE, AHB_SLAVE_ISRAM, "isram");
    check_region(DSRAM_BASE, DSRAM_SIZE, AHB_SLAVE_DSRAM, "dsram");
    check_region(DMA_BASE, PERIPH_SIZE, AHB_SLAVE_DMA, "dma regs");
    check_region(WDG_BASE, PERIPH_SIZE, AHB_SLAVE_WDG, "wdg regs");
    check_region(TIMER_BASE, PERIPH_SIZE, AHB_SLAVE_TIMER, "timer regs");
    check_region(INTC_BASE, PERIPH_SIZE, AHB_SLAVE_INTC, "intc regs");
    check_region(UART_BASE, PERIPH_SIZE, AHB_SLAVE_UART, "uart regs");
    check_region(I2C_BASE, PERIPH_SIZE, AHB_SLAVE_I2C, "i2c regs");
    check_region(GPIO_BASE, PERIPH_SIZE, AHB_SLAVE_GPIO, "gpio regs");

    check_decode(32'h0002_0000, AHB_SLAVE_DEFAULT, "unmapped low");
    check_decode(32'h3000_0000, AHB_SLAVE_DEFAULT, "unmapped middle");
    check_decode(32'h8000_0000, AHB_SLAVE_DEFAULT, "unmapped high");
    check_decode(32'hFFFF_FFFC, AHB_SLAVE_DEFAULT, "unmapped top");

    check_random_addresses(128);
    check_inactive(UART_BASE, "inactive uart address");
    check_coverage_summary();

    $display("tb_ahb_decoder PASS");
    $finish;
  end
endmodule
