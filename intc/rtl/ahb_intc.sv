`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module ahb_intc #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter int IRQ_COUNT = wasp1_pkg::IRQ_SRC_COUNT,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::INTC_BASE,
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
  input  logic [IRQ_COUNT-1:0]  irq_src_i,
  output logic                  meip_o,
  output logic [$clog2(IRQ_COUNT)-1:0] claim_id_o
);
  import wasp1_pkg::*;

  localparam int ID_WIDTH = (IRQ_COUNT <= 1) ? 1 : $clog2(IRQ_COUNT);

  logic                  req_valid_q;
  logic                  req_write_q;
  logic                  req_err_q;
  logic [ADDR_WIDTH-1:0] req_offset_q;

  logic [ADDR_WIDTH-1:0] addr_offset;
  logic                  addr_in_range;
  logic                  addr_phase_valid;
  logic                  addr_phase_err;
  logic [DATA_WIDTH-1:0] read_data_next;

  logic [IRQ_COUNT-1:0] src_meta_q;
  logic [IRQ_COUNT-1:0] src_sync_q;
  logic [IRQ_COUNT-1:0] pending_q;
  logic [IRQ_COUNT-1:0] enable_q;
  logic [INTC_PRIORITY_BITS-1:0] priority_q [IRQ_COUNT];
  logic [INTC_PRIORITY_BITS-1:0] threshold_q;
  logic [ID_WIDTH-1:0] best_id;
  logic [INTC_PRIORITY_BITS-1:0] best_prio;
  logic [31:0] priority_index;
  logic priority_access;
  logic priority_index_valid;
  logic [31:0] complete_id;

  assign hready_o = 1'b1;
  assign claim_id_o = best_id;
  assign meip_o = (best_id != '0);

  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(REGION_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || |haddr_i[1:0] || (hsize_i != AHB_HSIZE_WORD));
  assign priority_access = req_offset_q >= INTC_PRIORITY_BASE_OFFSET;
  assign priority_index = (req_offset_q - ADDR_WIDTH'(INTC_PRIORITY_BASE_OFFSET)) >> 2;
  assign priority_index_valid = priority_access &&
                                (((req_offset_q - ADDR_WIDTH'(INTC_PRIORITY_BASE_OFFSET)) % INTC_PRIORITY_STRIDE) == 0) &&
                                (priority_index < IRQ_COUNT);
  assign complete_id = 32'(hwdata_i[ID_WIDTH-1:0]);

  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    logic [31:0] idx;
    begin
      idx = (reg_offset - INTC_PRIORITY_BASE_OFFSET) >> 2;
      unique case (reg_offset)
        INTC_PENDING_OFFSET,
        INTC_ENABLE_OFFSET,
        INTC_CLAIM_OFFSET,
        INTC_THRESHOLD_OFFSET: is_known_reg = 1'b1;
        default: begin
          is_known_reg = (reg_offset >= INTC_PRIORITY_BASE_OFFSET) &&
                         (((reg_offset - INTC_PRIORITY_BASE_OFFSET) % INTC_PRIORITY_STRIDE) == 0) &&
                         (idx < IRQ_COUNT);
        end
      endcase
    end
  endfunction

  always_comb begin
    best_id = '0;
    best_prio = '0;
    for (int idx = 1; idx < IRQ_COUNT; idx++) begin
      if (pending_q[idx] && enable_q[idx] && (priority_q[idx] > threshold_q) &&
          (priority_q[idx] > best_prio)) begin
        best_id = ID_WIDTH'(idx);
        best_prio = priority_q[idx];
      end
    end
  end

  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      unique case (req_offset_q)
        INTC_PENDING_OFFSET: read_data_next[IRQ_COUNT-1:0] = pending_q;
        INTC_ENABLE_OFFSET: read_data_next[IRQ_COUNT-1:0] = enable_q;
        INTC_CLAIM_OFFSET: read_data_next[ID_WIDTH-1:0] = best_id;
        INTC_THRESHOLD_OFFSET: read_data_next[INTC_PRIORITY_BITS-1:0] = threshold_q;
        default: begin
          if (priority_index_valid) begin
            read_data_next[INTC_PRIORITY_BITS-1:0] = priority_q[priority_index[ID_WIDTH-1:0]];
          end
        end
      endcase
    end
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      req_valid_q <= 1'b0;
      req_write_q <= 1'b0;
      req_err_q <= 1'b0;
      req_offset_q <= '0;
      src_meta_q <= '0;
      src_sync_q <= '0;
      pending_q <= '0;
      enable_q <= '0;
      threshold_q <= '0;
      for (int idx = 0; idx < IRQ_COUNT; idx++) begin
        if (idx == 0) begin
          priority_q[idx] <= '0;
        end else begin
          priority_q[idx] <= INTC_PRIORITY_BITS'(1);
        end
      end
      hrdata_o <= '0;
      hresp_o <= AHB_HRESP_OKAY;
    end else begin
      src_meta_q <= irq_src_i;
      src_sync_q <= src_meta_q;
      pending_q <= pending_q | (src_sync_q & ~IRQ_COUNT'(1));
      hrdata_o <= read_data_next;
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      if (req_valid_q && !req_err_q) begin
        if (!is_known_reg(req_offset_q[31:0])) begin
          hresp_o <= AHB_HRESP_ERROR;
        end else if (req_write_q) begin
          unique case (req_offset_q)
            INTC_PENDING_OFFSET: begin
              pending_q <= (pending_q | (src_sync_q & ~IRQ_COUNT'(1))) &
                           ~hwdata_i[IRQ_COUNT-1:0];
            end
            INTC_ENABLE_OFFSET: begin
              enable_q <= hwdata_i[IRQ_COUNT-1:0] & ~IRQ_COUNT'(1);
            end
            INTC_CLAIM_OFFSET: begin
              if ((complete_id != 32'h0) && (complete_id < IRQ_COUNT)) begin
                pending_q[hwdata_i[ID_WIDTH-1:0]] <= 1'b0;
              end
            end
            INTC_THRESHOLD_OFFSET: begin
              threshold_q <= hwdata_i[INTC_PRIORITY_BITS-1:0];
            end
            default: begin
              if (priority_index_valid) begin
                if (priority_index[ID_WIDTH-1:0] != '0) begin
                  priority_q[priority_index[ID_WIDTH-1:0]] <= hwdata_i[INTC_PRIORITY_BITS-1:0];
                end
              end else begin
                hresp_o <= AHB_HRESP_ERROR;
              end
            end
          endcase
        end
      end

      req_valid_q <= addr_phase_valid;
      req_write_q <= hwrite_i;
      req_err_q <= addr_phase_err;
      req_offset_q <= addr_offset;
    end
  end
endmodule
