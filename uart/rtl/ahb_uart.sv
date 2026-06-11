`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module ahb_uart #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter int FIFO_DEPTH = 8,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::UART_BASE,
  parameter int REGION_BYTES = wasp1_pkg::PERIPH_SIZE
) (
  input  logic                  hclk_i,
  input  logic                  hresetn_i,
  input  logic                  hsel_i,
  input  logic [ADDR_WIDTH-1:0] haddr_i,
  input  logic [1:0]            htrans_i,
  input  logic                  hwrite_i,
  input  logic [2:0]            hsize_i,
  input  logic [DATA_WIDTH-1:0] hwdata_i,
  output logic [DATA_WIDTH-1:0] hrdata_o,
  output logic                  hready_o,
  output logic                  hresp_o,
  input  logic                  uart_rx_i,
  output logic                  uart_tx_o,
  output logic                  uart_irq_o
);
  import wasp1_pkg::*;

  logic                  req_valid_q;
  logic                  req_write_q;
  logic                  req_err_q;
  logic [ADDR_WIDTH-1:0] req_offset_q;
  logic [2:0]            req_size_q;

  logic [ADDR_WIDTH-1:0] addr_offset;
  logic                  addr_in_range;
  logic                  addr_phase_valid;
  logic                  addr_misaligned;
  logic                  addr_unsupported;
  logic                  addr_phase_err;
  logic [DATA_WIDTH-1:0] read_data_next;

  logic                  enable_q;
  logic                  tx_en_q;
  logic                  rx_en_q;
  logic                  tx_irq_en_q;
  logic                  rx_irq_en_q;
  logic                  ovr_irq_en_q;
  logic [15:0]           baud_div_q;
  logic [2:0]            irq_status_q;
  logic                  rx_overrun_q;

  logic                  baud_tick;
  logic                  tx_fifo_push;
  logic                  tx_fifo_ready;
  logic [7:0]            tx_fifo_wdata;
  logic                  tx_fifo_valid;
  logic                  tx_fifo_pop;
  logic [7:0]            tx_fifo_rdata;
  logic                  tx_busy;
  logic                  tx_ready;

  logic                  rx_data_valid;
  logic [7:0]            rx_data;
  logic                  rx_frame_error;
  logic                  rx_busy;
  logic                  rx_fifo_push;
  logic                  rx_fifo_ready;
  logic                  rx_fifo_valid;
  logic                  rx_fifo_pop;
  logic [7:0]            rx_fifo_rdata;

  assign hready_o = 1'b1;
  assign uart_irq_o = (irq_status_q[UART_IRQ_TX_EMPTY_BIT] && tx_irq_en_q) ||
                      (irq_status_q[UART_IRQ_RX_AVAIL_BIT] && rx_irq_en_q) ||
                      (irq_status_q[UART_IRQ_RX_OVERRUN_BIT] && ovr_irq_en_q);

  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(REGION_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];
  assign addr_misaligned = |haddr_i[1:0];
  assign addr_unsupported = hsize_i != AHB_HSIZE_WORD;
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || addr_misaligned || addr_unsupported);

  assign tx_fifo_wdata = hwdata_i[7:0];
  assign tx_fifo_push = req_valid_q && req_write_q && !req_err_q &&
                        (req_offset_q == UART_DATA_OFFSET) && tx_fifo_ready;
  assign tx_fifo_pop = tx_fifo_valid && tx_ready;

  assign rx_fifo_push = rx_data_valid && rx_fifo_ready;
  assign rx_fifo_pop = req_valid_q && !req_write_q && !req_err_q &&
                       (req_offset_q == UART_DATA_OFFSET) && rx_fifo_valid;

  uart_baud u_uart_baud (
    .clk_i(hclk_i),
    .rst_ni(hresetn_i),
    .enable_i(enable_q && (tx_en_q || rx_en_q)),
    .divisor_i(baud_div_q),
    .tick_o(baud_tick)
  );

  simple_fifo #(
    .WIDTH(8),
    .DEPTH(FIFO_DEPTH)
  ) u_tx_fifo (
    .clk_i(hclk_i),
    .rst_ni(hresetn_i),
    .push_valid_i(tx_fifo_push),
    .push_ready_o(tx_fifo_ready),
    .push_data_i(tx_fifo_wdata),
    .pop_valid_o(tx_fifo_valid),
    .pop_ready_i(tx_fifo_pop),
    .pop_data_o(tx_fifo_rdata)
  );

  simple_fifo #(
    .WIDTH(8),
    .DEPTH(FIFO_DEPTH)
  ) u_rx_fifo (
    .clk_i(hclk_i),
    .rst_ni(hresetn_i),
    .push_valid_i(rx_fifo_push),
    .push_ready_o(rx_fifo_ready),
    .push_data_i(rx_data),
    .pop_valid_o(rx_fifo_valid),
    .pop_ready_i(rx_fifo_pop),
    .pop_data_o(rx_fifo_rdata)
  );

  uart_tx u_uart_tx (
    .clk_i(hclk_i),
    .rst_ni(hresetn_i),
    .enable_i(enable_q && tx_en_q),
    .baud_tick_i(baud_tick),
    .data_valid_i(tx_fifo_valid),
    .data_ready_o(tx_ready),
    .data_i(tx_fifo_rdata),
    .tx_o(uart_tx_o),
    .busy_o(tx_busy)
  );

  uart_rx u_uart_rx (
    .clk_i(hclk_i),
    .rst_ni(hresetn_i),
    .enable_i(enable_q && rx_en_q),
    .baud_tick_i(baud_tick),
    .rx_i(uart_rx_i),
    .data_valid_o(rx_data_valid),
    .data_o(rx_data),
    .frame_error_o(rx_frame_error),
    .busy_o(rx_busy)
  );

  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    begin
      unique case (reg_offset)
        UART_DATA_OFFSET,
        UART_STATUS_OFFSET,
        UART_CTRL_OFFSET,
        UART_BAUD_OFFSET,
        UART_IRQ_STATUS_OFFSET: is_known_reg = 1'b1;
        default: is_known_reg = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] make_ctrl;
    logic [31:0] ctrl;
    begin
      ctrl = '0;
      ctrl[UART_CTRL_ENABLE_BIT] = enable_q;
      ctrl[UART_CTRL_TX_EN_BIT] = tx_en_q;
      ctrl[UART_CTRL_RX_EN_BIT] = rx_en_q;
      ctrl[UART_CTRL_TX_IRQ_EN_BIT] = tx_irq_en_q;
      ctrl[UART_CTRL_RX_IRQ_EN_BIT] = rx_irq_en_q;
      ctrl[UART_CTRL_OVR_IRQ_EN_BIT] = ovr_irq_en_q;
      make_ctrl = ctrl;
    end
  endfunction

  function automatic logic [31:0] make_status;
    logic [31:0] status;
    begin
      status = '0;
      status[UART_STATUS_TX_EMPTY_BIT] = !tx_fifo_valid && !tx_busy;
      status[UART_STATUS_TX_FULL_BIT] = !tx_fifo_ready;
      status[UART_STATUS_RX_EMPTY_BIT] = !rx_fifo_valid;
      status[UART_STATUS_RX_FULL_BIT] = !rx_fifo_ready;
      status[UART_STATUS_TX_BUSY_BIT] = tx_busy;
      status[UART_STATUS_RX_OVERRUN_BIT] = rx_overrun_q;
      make_status = status;
    end
  endfunction

  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      unique case (req_offset_q)
        UART_DATA_OFFSET:       read_data_next = {24'h0, rx_fifo_rdata};
        UART_STATUS_OFFSET:     read_data_next = make_status();
        UART_CTRL_OFFSET:       read_data_next = make_ctrl();
        UART_BAUD_OFFSET:       read_data_next = {16'h0, baud_div_q};
        UART_IRQ_STATUS_OFFSET: read_data_next = {29'h0, irq_status_q};
        default:                read_data_next = '0;
      endcase
    end
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      req_valid_q  <= 1'b0;
      req_write_q  <= 1'b0;
      req_err_q    <= 1'b0;
      req_offset_q <= '0;
      req_size_q   <= AHB_HSIZE_WORD;
      enable_q     <= 1'b0;
      tx_en_q      <= 1'b0;
      rx_en_q      <= 1'b0;
      tx_irq_en_q  <= 1'b0;
      rx_irq_en_q  <= 1'b0;
      ovr_irq_en_q <= 1'b0;
      baud_div_q   <= 16'd4;
      irq_status_q <= '0;
      rx_overrun_q <= 1'b0;
      hrdata_o     <= '0;
      hresp_o      <= AHB_HRESP_OKAY;
    end else begin
      hrdata_o <= read_data_next;
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      if (tx_irq_en_q && !tx_fifo_valid && !tx_busy) begin
        irq_status_q[UART_IRQ_TX_EMPTY_BIT] <= 1'b1;
      end
      if (rx_irq_en_q && (rx_fifo_valid || rx_data_valid)) begin
        irq_status_q[UART_IRQ_RX_AVAIL_BIT] <= 1'b1;
      end
      if (rx_data_valid && !rx_fifo_ready) begin
        rx_overrun_q <= 1'b1;
        if (ovr_irq_en_q) begin
          irq_status_q[UART_IRQ_RX_OVERRUN_BIT] <= 1'b1;
        end
      end
      if (rx_frame_error) begin
        rx_overrun_q <= 1'b1;
        if (ovr_irq_en_q) begin
          irq_status_q[UART_IRQ_RX_OVERRUN_BIT] <= 1'b1;
        end
      end

      if (req_valid_q && !req_err_q) begin
        if (!is_known_reg(req_offset_q[31:0])) begin
          hresp_o <= AHB_HRESP_ERROR;
        end else if (req_write_q) begin
          unique case (req_offset_q)
            UART_DATA_OFFSET: begin
              if (!tx_fifo_ready) begin
                hresp_o <= AHB_HRESP_ERROR;
              end
            end
            UART_CTRL_OFFSET: begin
              enable_q     <= hwdata_i[UART_CTRL_ENABLE_BIT];
              tx_en_q      <= hwdata_i[UART_CTRL_TX_EN_BIT];
              rx_en_q      <= hwdata_i[UART_CTRL_RX_EN_BIT];
              tx_irq_en_q  <= hwdata_i[UART_CTRL_TX_IRQ_EN_BIT];
              rx_irq_en_q  <= hwdata_i[UART_CTRL_RX_IRQ_EN_BIT];
              ovr_irq_en_q <= hwdata_i[UART_CTRL_OVR_IRQ_EN_BIT];
            end
            UART_BAUD_OFFSET: begin
              baud_div_q <= hwdata_i[15:0];
            end
            UART_IRQ_STATUS_OFFSET: begin
              irq_status_q <= irq_status_q & ~hwdata_i[2:0];
              if (hwdata_i[UART_IRQ_RX_OVERRUN_BIT]) begin
                rx_overrun_q <= 1'b0;
              end
            end
            default: begin
              hresp_o <= AHB_HRESP_ERROR;
            end
          endcase
        end
      end

      req_valid_q  <= addr_phase_valid;
      req_write_q  <= hwrite_i;
      req_err_q    <= addr_phase_err;
      req_offset_q <= addr_offset;
      req_size_q   <= hsize_i;
    end
  end

  logic unused_req_size;
  assign unused_req_size = ^req_size_q ^ rx_busy;
endmodule
