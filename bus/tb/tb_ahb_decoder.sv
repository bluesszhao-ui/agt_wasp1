module tb_ahb_decoder;
  import wasp1_pkg::*;

  logic [ADDR_WIDTH-1:0] haddr;
  logic                  active;
  logic [AHB_SLAVE_COUNT-1:0] hsel;
  logic                  default_sel;

  ahb_decoder u_ahb_decoder (
    .haddr_i(haddr),
    .active_i(active),
    .hsel_o(hsel),
    .default_sel_o(default_sel)
  );

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
      if (default_sel !== expected[AHB_SLAVE_DEFAULT]) begin
        $error("%s: default_sel mismatch", label);
        $fatal(1);
      end
    end
  endtask

  initial begin
    haddr = '0;
    active = 1'b0;
    #1;
    if (hsel !== '0 || default_sel !== 1'b0) begin
      $error("inactive decode should select no slave");
      $fatal(1);
    end

    check_decode(OTP_BASE, AHB_SLAVE_OTP, "otp base");
    check_decode(OTP_BASE + OTP_SIZE - 1, AHB_SLAVE_OTP, "otp end");
    check_decode(ISRAM_BASE, AHB_SLAVE_ISRAM, "isram base");
    check_decode(ISRAM_BASE + ISRAM_SIZE - 1, AHB_SLAVE_ISRAM, "isram end");
    check_decode(DSRAM_BASE, AHB_SLAVE_DSRAM, "dsram base");
    check_decode(DSRAM_BASE + DSRAM_SIZE - 1, AHB_SLAVE_DSRAM, "dsram end");
    check_decode(DMA_BASE, AHB_SLAVE_DMA, "dma regs");
    check_decode(WDG_BASE, AHB_SLAVE_WDG, "wdg regs");
    check_decode(TIMER_BASE, AHB_SLAVE_TIMER, "timer regs");
    check_decode(INTC_BASE, AHB_SLAVE_INTC, "intc regs");
    check_decode(UART_BASE, AHB_SLAVE_UART, "uart regs");
    check_decode(I2C_BASE, AHB_SLAVE_I2C, "i2c regs");
    check_decode(GPIO_BASE, AHB_SLAVE_GPIO, "gpio regs");
    check_decode(GPIO_BASE + PERIPH_SIZE - 1, AHB_SLAVE_GPIO, "gpio end");
    check_decode(32'h8000_0000, AHB_SLAVE_DEFAULT, "unmapped high");
    check_decode(OTP_BASE + OTP_SIZE, AHB_SLAVE_DEFAULT, "otp boundary");

    active = 1'b0;
    haddr = UART_BASE;
    #1;
    if (hsel !== '0 || default_sel !== 1'b0) begin
      $error("inactive decode with valid address should select no slave");
      $fatal(1);
    end

    $display("tb_ahb_decoder PASS");
    $finish;
  end
endmodule
