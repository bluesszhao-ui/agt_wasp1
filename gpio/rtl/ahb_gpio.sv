`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module ahb_gpio #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter int GPIO_WIDTH = 32,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::GPIO_BASE,
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
  input  logic [GPIO_WIDTH-1:0] gpio_in_i,
  output logic [GPIO_WIDTH-1:0] gpio_out_o,
  output logic [GPIO_WIDTH-1:0] gpio_oe_o,
  output logic                  gpio_irq_o
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

  logic [GPIO_WIDTH-1:0] in_meta_q;
  logic [GPIO_WIDTH-1:0] in_sync_q;
  logic [GPIO_WIDTH-1:0] in_prev_q;
  logic [GPIO_WIDTH-1:0] out_q;
  logic [GPIO_WIDTH-1:0] dir_q;
  logic [GPIO_WIDTH-1:0] irq_en_q;
  logic [GPIO_WIDTH-1:0] irq_type_q;
  logic [GPIO_WIDTH-1:0] irq_pol_q;
  logic [GPIO_WIDTH-1:0] irq_status_q;
  logic [GPIO_WIDTH-1:0] edge_rise;
  logic [GPIO_WIDTH-1:0] edge_fall;
  logic [GPIO_WIDTH-1:0] level_high;
  logic [GPIO_WIDTH-1:0] level_low;
  logic [GPIO_WIDTH-1:0] irq_event;
  logic [GPIO_WIDTH-1:0] write_masked_data;

  assign hready_o = 1'b1;
  assign gpio_out_o = out_q;
  assign gpio_oe_o = dir_q;
  assign gpio_irq_o = |(irq_status_q & irq_en_q);

  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(REGION_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];
  assign addr_misaligned = |haddr_i[1:0];
  assign addr_unsupported = hsize_i != AHB_HSIZE_WORD;
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || addr_misaligned || addr_unsupported);

  assign edge_rise = in_sync_q & ~in_prev_q;
  assign edge_fall = ~in_sync_q & in_prev_q;
  assign level_high = in_sync_q;
  assign level_low = ~in_sync_q;
  assign irq_event = irq_en_q &
                     (((irq_type_q & irq_pol_q) & edge_rise) |
                      ((irq_type_q & ~irq_pol_q) & edge_fall) |
                      ((~irq_type_q & irq_pol_q) & level_high) |
                      ((~irq_type_q & ~irq_pol_q) & level_low));
  assign write_masked_data = hwdata_i[GPIO_WIDTH-1:0];

  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    begin
      unique case (reg_offset)
        GPIO_DATA_IN_OFFSET,
        GPIO_DATA_OUT_OFFSET,
        GPIO_DIR_OFFSET,
        GPIO_SET_OFFSET,
        GPIO_CLR_OFFSET,
        GPIO_TOGGLE_OFFSET,
        GPIO_IRQ_EN_OFFSET,
        GPIO_IRQ_TYPE_OFFSET,
        GPIO_IRQ_POL_OFFSET,
        GPIO_IRQ_STATUS_OFFSET: is_known_reg = 1'b1;
        default: is_known_reg = 1'b0;
      endcase
    end
  endfunction

  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      unique case (req_offset_q)
        GPIO_DATA_IN_OFFSET:    read_data_next[GPIO_WIDTH-1:0] = in_sync_q;
        GPIO_DATA_OUT_OFFSET:   read_data_next[GPIO_WIDTH-1:0] = out_q;
        GPIO_DIR_OFFSET:        read_data_next[GPIO_WIDTH-1:0] = dir_q;
        GPIO_SET_OFFSET:        read_data_next = '0;
        GPIO_CLR_OFFSET:        read_data_next = '0;
        GPIO_TOGGLE_OFFSET:     read_data_next = '0;
        GPIO_IRQ_EN_OFFSET:     read_data_next[GPIO_WIDTH-1:0] = irq_en_q;
        GPIO_IRQ_TYPE_OFFSET:   read_data_next[GPIO_WIDTH-1:0] = irq_type_q;
        GPIO_IRQ_POL_OFFSET:    read_data_next[GPIO_WIDTH-1:0] = irq_pol_q;
        GPIO_IRQ_STATUS_OFFSET: read_data_next[GPIO_WIDTH-1:0] = irq_status_q;
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
      in_meta_q    <= '0;
      in_sync_q    <= '0;
      in_prev_q    <= '0;
      out_q        <= '0;
      dir_q        <= '0;
      irq_en_q     <= '0;
      irq_type_q   <= '0;
      irq_pol_q    <= '0;
      irq_status_q <= '0;
      hrdata_o     <= '0;
      hresp_o      <= AHB_HRESP_OKAY;
    end else begin
      in_meta_q <= gpio_in_i;
      in_sync_q <= in_meta_q;
      in_prev_q <= in_sync_q;

      irq_status_q <= irq_status_q | irq_event;
      hrdata_o <= read_data_next;
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      if (req_valid_q && !req_err_q) begin
        if (!is_known_reg(req_offset_q[31:0])) begin
          hresp_o <= AHB_HRESP_ERROR;
        end else if (req_write_q) begin
          unique case (req_offset_q)
            GPIO_DATA_OUT_OFFSET: begin
              out_q <= write_masked_data;
            end
            GPIO_DIR_OFFSET: begin
              dir_q <= write_masked_data;
            end
            GPIO_SET_OFFSET: begin
              out_q <= out_q | write_masked_data;
            end
            GPIO_CLR_OFFSET: begin
              out_q <= out_q & ~write_masked_data;
            end
            GPIO_TOGGLE_OFFSET: begin
              out_q <= out_q ^ write_masked_data;
            end
            GPIO_IRQ_EN_OFFSET: begin
              irq_en_q <= write_masked_data;
            end
            GPIO_IRQ_TYPE_OFFSET: begin
              irq_type_q <= write_masked_data;
            end
            GPIO_IRQ_POL_OFFSET: begin
              irq_pol_q <= write_masked_data;
            end
            GPIO_IRQ_STATUS_OFFSET: begin
              irq_status_q <= (irq_status_q | irq_event) & ~write_masked_data;
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
  assign unused_req_size = ^req_size_q;
endmodule
