module ahb_decoder #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int SLAVE_COUNT = wasp1_pkg::AHB_SLAVE_COUNT,
  parameter logic [31:0] OTP_BASE_P = wasp1_pkg::OTP_BASE,
  parameter logic [31:0] OTP_SIZE_P = wasp1_pkg::OTP_SIZE,
  parameter logic [31:0] ISRAM_BASE_P = wasp1_pkg::ISRAM_BASE,
  parameter logic [31:0] ISRAM_SIZE_P = wasp1_pkg::ISRAM_SIZE,
  parameter logic [31:0] DSRAM_BASE_P = wasp1_pkg::DSRAM_BASE,
  parameter logic [31:0] DSRAM_SIZE_P = wasp1_pkg::DSRAM_SIZE,
  parameter logic [31:0] PERIPH_SIZE_P = wasp1_pkg::PERIPH_SIZE
) (
  input  logic [ADDR_WIDTH-1:0] haddr_i,
  input  logic                  active_i,
  output logic [SLAVE_COUNT-1:0] hsel_o,
  output logic                  default_sel_o
);
  import wasp1_pkg::*;

  function automatic logic addr_in_range(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [31:0]           base,
    input logic [31:0]           size
  );
    logic [ADDR_WIDTH-1:0] addr_mask;
    logic [ADDR_WIDTH-1:0] base_ext;
    logic [ADDR_WIDTH-1:0] size_ext;
    begin
      base_ext = ADDR_WIDTH'(base);
      size_ext = ADDR_WIDTH'(size);
      addr_mask = ~(size_ext - ADDR_WIDTH'(1));
      addr_in_range = ((addr & addr_mask) == (base_ext & addr_mask));
    end
  endfunction

  always_comb begin
    hsel_o = '0;

    if (active_i) begin
      if (addr_in_range(haddr_i, OTP_BASE_P, OTP_SIZE_P)) begin
        hsel_o[AHB_SLAVE_OTP] = 1'b1;
      end else if (addr_in_range(haddr_i, ISRAM_BASE_P, ISRAM_SIZE_P)) begin
        hsel_o[AHB_SLAVE_ISRAM] = 1'b1;
      end else if (addr_in_range(haddr_i, DSRAM_BASE_P, DSRAM_SIZE_P)) begin
        hsel_o[AHB_SLAVE_DSRAM] = 1'b1;
      end else if (addr_in_range(haddr_i, DMA_BASE, PERIPH_SIZE_P)) begin
        hsel_o[AHB_SLAVE_DMA] = 1'b1;
      end else if (addr_in_range(haddr_i, WDG_BASE, PERIPH_SIZE_P)) begin
        hsel_o[AHB_SLAVE_WDG] = 1'b1;
      end else if (addr_in_range(haddr_i, TIMER_BASE, PERIPH_SIZE_P)) begin
        hsel_o[AHB_SLAVE_TIMER] = 1'b1;
      end else if (addr_in_range(haddr_i, INTC_BASE, PERIPH_SIZE_P)) begin
        hsel_o[AHB_SLAVE_INTC] = 1'b1;
      end else if (addr_in_range(haddr_i, UART_BASE, PERIPH_SIZE_P)) begin
        hsel_o[AHB_SLAVE_UART] = 1'b1;
      end else if (addr_in_range(haddr_i, I2C_BASE, PERIPH_SIZE_P)) begin
        hsel_o[AHB_SLAVE_I2C] = 1'b1;
      end else if (addr_in_range(haddr_i, GPIO_BASE, PERIPH_SIZE_P)) begin
        hsel_o[AHB_SLAVE_GPIO] = 1'b1;
      end else begin
        hsel_o[AHB_SLAVE_DEFAULT] = 1'b1;
      end
    end
  end

  assign default_sel_o = hsel_o[AHB_SLAVE_DEFAULT];
endmodule
