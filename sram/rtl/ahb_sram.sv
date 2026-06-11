`timescale 1ns/1ps

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

  logic [DATA_WIDTH-1:0] mem_q [WORD_COUNT];

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
  logic [DATA_WIDTH-1:0] write_word;
  logic [STRB_WIDTH_LOCAL-1:0] write_mask;

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
  assign read_word = mem_q[req_word_idx];

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

  always_comb begin
    write_word = read_word;
    for (int byte_idx = 0; byte_idx < STRB_WIDTH_LOCAL; byte_idx++) begin
      if (write_mask[byte_idx]) begin
        write_word[(byte_idx * BYTE_WIDTH) +: BYTE_WIDTH] =
          hwdata_i[(byte_idx * BYTE_WIDTH) +: BYTE_WIDTH];
      end
    end
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
      if (req_valid_q && req_write_q && !req_err_q) begin
        mem_q[req_word_idx] <= write_word;
      end

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
