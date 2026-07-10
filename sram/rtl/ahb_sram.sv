`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module ahb_sram #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter logic [31:0] BASE_ADDR = 32'h0000_0000,
  parameter int MEM_BYTES = 65536
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
  output logic                  hresp_o
);
  import wasp1_pkg::*;

  localparam int BYTE_WIDTH = 8;
  localparam int STRB_WIDTH_LOCAL = DATA_WIDTH / BYTE_WIDTH;
  localparam int WORD_COUNT = MEM_BYTES / STRB_WIDTH_LOCAL;
  localparam int WORD_INDEX_WIDTH = (WORD_COUNT <= 1) ? 1 : $clog2(WORD_COUNT);

  logic                  req_valid_q;
  logic                  req_write_q;
  logic [ADDR_WIDTH-1:0] req_addr_q;
  logic [2:0]            req_size_q;
  logic                  req_err_q;

  logic [ADDR_WIDTH-1:0] addr_offset;
  logic                  addr_in_range;
  logic                  addr_misaligned;
  logic                  addr_phase_valid;
  logic                  addr_phase_err;
  logic [WORD_INDEX_WIDTH-1:0] req_word_idx;
  logic [WORD_INDEX_WIDTH-1:0] req_word_idx_raw;
  logic [1:0]            req_byte_off;
  logic [DATA_WIDTH-1:0] read_word;
  logic [STRB_WIDTH_LOCAL-1:0] write_mask;
  logic                  macro_write;

  assign hready_o = 1'b1;
  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(MEM_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];

  always_comb begin
    unique case (hsize_i)
      AHB_HSIZE_BYTE: addr_misaligned = 1'b0;
      AHB_HSIZE_HALF: addr_misaligned = haddr_i[0];
      AHB_HSIZE_WORD: addr_misaligned = |haddr_i[1:0];
      default: addr_misaligned = 1'b1;
    endcase
  end

  assign addr_phase_err = addr_phase_valid && (!addr_in_range || addr_misaligned);
  assign req_word_idx_raw = req_addr_q[$clog2(STRB_WIDTH_LOCAL) +: WORD_INDEX_WIDTH];
  assign req_word_idx = req_err_q ? '0 : req_word_idx_raw;
  assign req_byte_off = req_addr_q[1:0];
  assign macro_write = req_valid_q && req_write_q && !req_err_q;

  // The storage body is isolated behind a macro wrapper. Generic simulation and
  // FPGA builds use the behavioral body in `wasp1_sram_macro`; IC synthesis can
  // replace that module with a foundry SRAM compiler macro without changing the
  // AHB protocol wrapper.
  wasp1_sram_macro #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(WORD_COUNT),
    .ADDR_WIDTH(WORD_INDEX_WIDTH)
  ) u_sram_macro (
    .clk_i(hclk_i),
    .write_i(macro_write),
    .addr_i(req_word_idx),
    .wstrb_i(write_mask),
    .wdata_i(hwdata_i),
    .rdata_o(read_word)
  );

  always_comb begin
    write_mask = '0;
    unique case (req_size_q)
      AHB_HSIZE_BYTE: write_mask[req_byte_off] = 1'b1;
      AHB_HSIZE_HALF: begin
        write_mask[req_byte_off] = 1'b1;
        write_mask[req_byte_off + 1'b1] = 1'b1;
      end
      AHB_HSIZE_WORD: write_mask = '1;
      default: write_mask = '0;
    endcase
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      req_valid_q <= 1'b0;
      req_write_q <= 1'b0;
      req_addr_q  <= '0;
      req_size_q  <= AHB_HSIZE_WORD;
      req_err_q   <= 1'b0;
      hrdata_o    <= '0;
      hresp_o     <= AHB_HRESP_OKAY;
    end else begin
      if (req_valid_q && !req_write_q && !req_err_q) begin
        hrdata_o <= read_word;
      end else begin
        hrdata_o <= '0;
      end
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      req_valid_q <= addr_phase_valid;
      req_write_q <= hwrite_i;
      req_addr_q  <= addr_offset;
      req_size_q  <= hsize_i;
      req_err_q   <= addr_phase_err;
    end
  end
endmodule
