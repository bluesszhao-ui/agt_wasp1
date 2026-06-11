`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module ahb_timer #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::TIMER_BASE,
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
  output logic                  timer_irq_o
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
  logic                  irq_en_q;
  logic [63:0]           mtime_q;
  logic [63:0]           mtimecmp_q;
  logic                  pending;

  assign hready_o = 1'b1;
  assign timer_irq_o = pending && irq_en_q;
  assign pending = (mtime_q >= mtimecmp_q);

  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(REGION_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];
  assign addr_misaligned = |haddr_i[1:0];
  assign addr_unsupported = hsize_i != AHB_HSIZE_WORD;
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || addr_misaligned || addr_unsupported);

  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    begin
      unique case (reg_offset)
        TIMER_CTRL_OFFSET,
        TIMER_STATUS_OFFSET,
        TIMER_MTIME_LO_OFFSET,
        TIMER_MTIME_HI_OFFSET,
        TIMER_CMP_LO_OFFSET,
        TIMER_CMP_HI_OFFSET: is_known_reg = 1'b1;
        default: is_known_reg = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] make_ctrl;
    logic [31:0] ctrl;
    begin
      ctrl = '0;
      ctrl[TIMER_CTRL_ENABLE_BIT] = enable_q;
      ctrl[TIMER_CTRL_IRQ_EN_BIT] = irq_en_q;
      make_ctrl = ctrl;
    end
  endfunction

  function automatic logic [31:0] make_status;
    logic [31:0] status;
    begin
      status = '0;
      status[TIMER_STATUS_PENDING_BIT] = pending;
      make_status = status;
    end
  endfunction

  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      unique case (req_offset_q)
        TIMER_CTRL_OFFSET:     read_data_next = make_ctrl();
        TIMER_STATUS_OFFSET:   read_data_next = make_status();
        TIMER_MTIME_LO_OFFSET: read_data_next = mtime_q[31:0];
        TIMER_MTIME_HI_OFFSET: read_data_next = mtime_q[63:32];
        TIMER_CMP_LO_OFFSET:   read_data_next = mtimecmp_q[31:0];
        TIMER_CMP_HI_OFFSET:   read_data_next = mtimecmp_q[63:32];
        default:               read_data_next = '0;
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
      irq_en_q     <= 1'b0;
      mtime_q      <= '0;
      mtimecmp_q   <= '1;
      hrdata_o     <= '0;
      hresp_o      <= AHB_HRESP_OKAY;
    end else begin
      if (enable_q) begin
        mtime_q <= mtime_q + 64'd1;
      end

      hrdata_o <= read_data_next;
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      if (req_valid_q && !req_err_q) begin
        if (!is_known_reg(req_offset_q[31:0])) begin
          hresp_o <= AHB_HRESP_ERROR;
        end else if (req_write_q) begin
          unique case (req_offset_q)
            TIMER_CTRL_OFFSET: begin
              enable_q <= hwdata_i[TIMER_CTRL_ENABLE_BIT];
              irq_en_q <= hwdata_i[TIMER_CTRL_IRQ_EN_BIT];
            end
            TIMER_MTIME_LO_OFFSET: begin
              mtime_q[31:0] <= hwdata_i;
            end
            TIMER_MTIME_HI_OFFSET: begin
              mtime_q[63:32] <= hwdata_i;
            end
            TIMER_CMP_LO_OFFSET: begin
              mtimecmp_q[31:0] <= hwdata_i;
            end
            TIMER_CMP_HI_OFFSET: begin
              mtimecmp_q[63:32] <= hwdata_i;
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
