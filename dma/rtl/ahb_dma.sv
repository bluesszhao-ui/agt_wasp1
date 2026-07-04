`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module ahb_dma #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::DMA_BASE,
  parameter int REGION_BYTES = wasp1_pkg::PERIPH_SIZE
) (
  input  logic                  hclk_i,
  input  logic                  hresetn_i,

  input  logic                  s_hsel_i,
  input  logic [ADDR_WIDTH-1:0] s_haddr_i,
  input  logic [1:0]            s_htrans_i,
  input  logic                  s_hwrite_i,
  input  logic [2:0]            s_hsize_i,
  input  logic [DATA_WIDTH-1:0] s_hwdata_i,
  output logic [DATA_WIDTH-1:0] s_hrdata_o,
  output logic                  s_hready_o,
  output logic                  s_hresp_o,

  output logic [ADDR_WIDTH-1:0] m_haddr_o,
  output logic [1:0]            m_htrans_o,
  output logic                  m_hwrite_o,
  output logic [2:0]            m_hsize_o,
  output logic [2:0]            m_hburst_o,
  output logic [3:0]            m_hprot_o,
  output logic                  m_hmastlock_o,
  output logic [DATA_WIDTH-1:0] m_hwdata_o,
  input  logic [DATA_WIDTH-1:0] m_hrdata_i,
  input  logic                  m_hready_i,
  input  logic                  m_hresp_i,

  output logic                  dma_irq_o
);
  import wasp1_pkg::*;

  typedef enum logic [2:0] {
    DMA_IDLE,
    DMA_READ_ADDR,
    DMA_READ_WAIT,
    DMA_WRITE_ADDR,
    DMA_WRITE_RESP,
    DMA_FINISH
  } dma_state_e;

  logic                  req_valid_q;
  logic                  req_write_q;
  logic                  req_err_q;
  logic [ADDR_WIDTH-1:0] req_offset_q;

  logic [ADDR_WIDTH-1:0] addr_offset;
  logic                  addr_in_range;
  logic                  addr_phase_valid;
  logic                  addr_phase_err;
  logic [DATA_WIDTH-1:0] read_data_next;

  logic [31:0] src_q;
  logic [31:0] dst_q;
  logic [31:0] len_q;
  logic        irq_en_q;
  logic        done_q;
  logic        error_q;
  dma_state_e  state_q;
  logic [31:0] cur_src_q;
  logic [31:0] cur_dst_q;
  logic [31:0] remaining_q;
  logic [31:0] data_q;

  assign s_hready_o = 1'b1;
  assign dma_irq_o = irq_en_q && (done_q || error_q);

  assign addr_offset = s_haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (s_haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(REGION_BYTES));
  assign addr_phase_valid = s_hsel_i && s_htrans_i[1];
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || |s_haddr_i[1:0] || (s_hsize_i != AHB_HSIZE_WORD));

  assign m_hsize_o = AHB_HSIZE_WORD;
  assign m_hburst_o = AHB_HBURST_SINGLE;
  assign m_hprot_o = 4'h5;
  assign m_hmastlock_o = 1'b0;

  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    begin
      unique case (reg_offset)
        DMA_SRC_OFFSET,
        DMA_DST_OFFSET,
        DMA_LEN_OFFSET,
        DMA_CTRL_OFFSET,
        DMA_STATUS_OFFSET: is_known_reg = 1'b1;
        default: is_known_reg = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] make_status;
    logic [31:0] status;
    begin
      status = '0;
      status[DMA_STATUS_BUSY_BIT] = (state_q != DMA_IDLE);
      status[DMA_STATUS_DONE_BIT] = done_q;
      status[DMA_STATUS_ERROR_BIT] = error_q;
      make_status = status;
    end
  endfunction

  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      unique case (req_offset_q)
        DMA_SRC_OFFSET:    read_data_next = src_q;
        DMA_DST_OFFSET:    read_data_next = dst_q;
        DMA_LEN_OFFSET:    read_data_next = len_q;
        DMA_CTRL_OFFSET:   read_data_next = {30'h0, irq_en_q, 1'b0};
        DMA_STATUS_OFFSET: read_data_next = make_status();
        default:           read_data_next = '0;
      endcase
    end
  end

  always_comb begin
    m_haddr_o = '0;
    m_htrans_o = AHB_HTRANS_IDLE;
    m_hwrite_o = 1'b0;
    m_hwdata_o = data_q;
    unique case (state_q)
      DMA_READ_ADDR: begin
        m_haddr_o = cur_src_q;
        m_htrans_o = AHB_HTRANS_NONSEQ;
        m_hwrite_o = 1'b0;
      end
      DMA_WRITE_ADDR: begin
        m_haddr_o = cur_dst_q;
        m_htrans_o = AHB_HTRANS_NONSEQ;
        m_hwrite_o = 1'b1;
      end
      default: begin end
    endcase
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      req_valid_q <= 1'b0;
      req_write_q <= 1'b0;
      req_err_q <= 1'b0;
      req_offset_q <= '0;
      src_q <= '0;
      dst_q <= '0;
      len_q <= '0;
      irq_en_q <= 1'b0;
      done_q <= 1'b0;
      error_q <= 1'b0;
      state_q <= DMA_IDLE;
      cur_src_q <= '0;
      cur_dst_q <= '0;
      remaining_q <= '0;
      data_q <= '0;
      s_hrdata_o <= '0;
      s_hresp_o <= AHB_HRESP_OKAY;
    end else begin
      s_hrdata_o <= read_data_next;
      s_hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      if (req_valid_q && !req_err_q) begin
        if (!is_known_reg(req_offset_q[31:0])) begin
          s_hresp_o <= AHB_HRESP_ERROR;
        end else if (req_write_q) begin
          unique case (req_offset_q)
            DMA_SRC_OFFSET: src_q <= s_hwdata_i;
            DMA_DST_OFFSET: dst_q <= s_hwdata_i;
            DMA_LEN_OFFSET: len_q <= s_hwdata_i;
            DMA_CTRL_OFFSET: begin
              irq_en_q <= s_hwdata_i[DMA_CTRL_IRQ_EN_BIT];
              if (s_hwdata_i[DMA_CTRL_CLEAR_BIT]) begin
                done_q <= 1'b0;
                error_q <= 1'b0;
              end
              if (s_hwdata_i[DMA_CTRL_START_BIT]) begin
                if ((state_q != DMA_IDLE) || (len_q == 32'd0) || |src_q[1:0] || |dst_q[1:0]) begin
                  error_q <= 1'b1;
                  done_q <= 1'b0;
                end else begin
                  cur_src_q <= src_q;
                  cur_dst_q <= dst_q;
                  remaining_q <= len_q;
                  done_q <= 1'b0;
                  error_q <= 1'b0;
                  state_q <= DMA_READ_ADDR;
                end
              end
            end
            default: s_hresp_o <= AHB_HRESP_ERROR;
          endcase
        end
      end

      unique case (state_q)
        DMA_IDLE: begin end
        DMA_READ_ADDR: begin
          if (m_hready_i) begin
            state_q <= DMA_READ_WAIT;
          end
        end
        DMA_READ_WAIT: begin
          if (m_hready_i) begin
            if (m_hresp_i) begin
              error_q <= 1'b1;
              state_q <= DMA_FINISH;
            end else begin
              data_q <= m_hrdata_i;
              state_q <= DMA_WRITE_ADDR;
            end
          end
        end
        DMA_WRITE_ADDR: begin
          if (m_hready_i) begin
            state_q <= DMA_WRITE_RESP;
          end
        end
        DMA_WRITE_RESP: begin
          if (m_hready_i) begin
            if (m_hresp_i) begin
              error_q <= 1'b1;
              state_q <= DMA_FINISH;
            end else if (remaining_q == 32'd1) begin
              done_q <= 1'b1;
              state_q <= DMA_FINISH;
            end else begin
              remaining_q <= remaining_q - 1'b1;
              cur_src_q <= cur_src_q + 32'd4;
              cur_dst_q <= cur_dst_q + 32'd4;
              state_q <= DMA_READ_ADDR;
            end
          end
        end
        DMA_FINISH: begin
          state_q <= DMA_IDLE;
        end
        default: state_q <= DMA_IDLE;
      endcase

      req_valid_q <= addr_phase_valid;
      req_write_q <= s_hwrite_i;
      req_err_q <= addr_phase_err;
      req_offset_q <= addr_offset;
    end
  end
endmodule
