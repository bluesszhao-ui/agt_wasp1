`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

module ahb_otp #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::OTP_BASE,
  parameter int MEM_BYTES = wasp1_pkg::OTP_SIZE,
  parameter int REG_WINDOW_BYTES = wasp1_pkg::OTP_REG_WINDOW_SIZE
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
  localparam int DATA_BYTES = MEM_BYTES - REG_WINDOW_BYTES;
  localparam int DATA_WORDS = DATA_BYTES / STRB_WIDTH_LOCAL;
  localparam int WORD_INDEX_WIDTH = (DATA_WORDS <= 1) ? 1 : $clog2(DATA_WORDS);

  logic                  req_valid_q;
  logic                  req_write_q;
  logic                  req_data_q;
  logic                  req_reg_q;
  logic                  req_err_q;
  logic [ADDR_WIDTH-1:0] req_offset_q;
  logic [2:0]            req_size_q;

  logic [ADDR_WIDTH-1:0] addr_offset;
  logic                  addr_in_range;
  logic                  addr_phase_valid;
  logic                  addr_data_region;
  logic                  addr_reg_region;
  logic                  addr_misaligned;
  logic                  addr_unsupported;
  logic                  addr_phase_err;
  logic [31:0]           req_reg_offset;
  logic [WORD_INDEX_WIDTH-1:0] req_word_idx;
  logic [WORD_INDEX_WIDTH-1:0] req_word_idx_raw;
  logic [DATA_WIDTH-1:0] otp_read_word;
  logic [DATA_WIDTH-1:0] otp_prog_word;
  logic                  otp_program_start;
  logic                  otp_program_legal;
  logic                  otp_program_fire;

  logic [31:0]           addr_reg_q;
  logic [31:0]           wdata_reg_q;
  logic [DATA_WIDTH-1:0] read_data_next;
  logic                  prog_addr_valid;
  logic [WORD_INDEX_WIDTH-1:0] prog_word_idx;
  logic                  key_unlocked_q;
  logic                  locked_q;
  logic                  busy_q;
  logic                  done_q;
  logic                  error_q;

  assign hready_o = 1'b1;
  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(MEM_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];
  assign addr_data_region = addr_in_range && (addr_offset < ADDR_WIDTH'(DATA_BYTES));
  assign addr_reg_region = addr_in_range && (addr_offset >= ADDR_WIDTH'(DATA_BYTES));

  always_comb begin
    unique case (hsize_i)
      AHB_HSIZE_BYTE: addr_misaligned = 1'b0;
      AHB_HSIZE_HALF: addr_misaligned = haddr_i[0];
      AHB_HSIZE_WORD: addr_misaligned = |haddr_i[1:0];
      default: addr_misaligned = 1'b1;
    endcase
  end

  assign addr_unsupported = addr_reg_region && (hsize_i != AHB_HSIZE_WORD);
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || addr_misaligned || addr_unsupported);
  assign req_reg_offset = req_offset_q - ADDR_WIDTH'(DATA_BYTES);
  assign req_word_idx_raw = req_offset_q[$clog2(STRB_WIDTH_LOCAL) +: WORD_INDEX_WIDTH];
  assign req_word_idx = (req_err_q || !req_data_q) ? '0 : req_word_idx_raw;
  assign prog_addr_valid = (addr_reg_q < DATA_WORDS);
  assign prog_word_idx = prog_addr_valid ? addr_reg_q[WORD_INDEX_WIDTH-1:0] : '0;

  // The executable OTP data bits sit behind a macro wrapper. The surrounding
  // logic keeps the AHB register contract, unlock/lock policy, and illegal
  // 0->1 program rejection visible in normal RTL and verification.
  wasp1_otp_macro #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DATA_WORDS),
    .ADDR_WIDTH(WORD_INDEX_WIDTH)
  ) u_otp_macro (
    .clk_i(hclk_i),
    .read_addr_i(req_word_idx),
    .read_data_o(otp_read_word),
    .prog_addr_i(prog_word_idx),
    .prog_i(otp_program_fire),
    .prog_data_i(wdata_reg_q),
    .prog_read_data_o(otp_prog_word)
  );

  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    begin
      unique case (reg_offset)
        OTP_CTRL_OFFSET,
        OTP_STATUS_OFFSET,
        OTP_ADDR_OFFSET,
        OTP_WDATA_OFFSET,
        OTP_RDATA_OFFSET,
        OTP_KEY_OFFSET,
        OTP_LOCK_OFFSET: is_known_reg = 1'b1;
        default: is_known_reg = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] make_status;
    logic [31:0] status;
    begin
      status = '0;
      status[OTP_STATUS_BUSY_BIT] = busy_q;
      status[OTP_STATUS_DONE_BIT] = done_q;
      status[OTP_STATUS_ERROR_BIT] = error_q;
      status[OTP_STATUS_LOCK_BIT] = locked_q;
      make_status = status;
    end
  endfunction

  assign otp_program_start = req_valid_q && !req_err_q && req_write_q &&
                             req_reg_q && (req_reg_offset == OTP_CTRL_OFFSET) &&
                             hwdata_i[OTP_CTRL_PROG_EN_BIT] &&
                             hwdata_i[OTP_CTRL_START_BIT];
  assign otp_program_legal = !locked_q && key_unlocked_q && prog_addr_valid &&
                             !(|(wdata_reg_q & ~otp_prog_word));
  assign otp_program_fire = otp_program_start && otp_program_legal;

  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      if (req_data_q) begin
        read_data_next = otp_read_word;
      end else if (req_reg_q) begin
        unique case (req_reg_offset)
          OTP_CTRL_OFFSET:   read_data_next = '0;
          OTP_STATUS_OFFSET: read_data_next = make_status();
          OTP_ADDR_OFFSET:   read_data_next = addr_reg_q;
          OTP_WDATA_OFFSET:  read_data_next = wdata_reg_q;
          OTP_RDATA_OFFSET:  read_data_next = prog_addr_valid ? otp_prog_word : '0;
          OTP_KEY_OFFSET:    read_data_next = {31'b0, key_unlocked_q};
          OTP_LOCK_OFFSET:   read_data_next = {31'b0, locked_q};
          default:           read_data_next = '0;
        endcase
      end
    end
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      req_valid_q   <= 1'b0;
      req_write_q   <= 1'b0;
      req_data_q    <= 1'b0;
      req_reg_q     <= 1'b0;
      req_err_q     <= 1'b0;
      req_offset_q  <= '0;
      req_size_q    <= AHB_HSIZE_WORD;
      addr_reg_q    <= '0;
      wdata_reg_q   <= '0;
      key_unlocked_q <= 1'b0;
      locked_q      <= 1'b0;
      busy_q        <= 1'b0;
      done_q        <= 1'b0;
      error_q       <= 1'b0;
      hrdata_o      <= '0;
      hresp_o       <= AHB_HRESP_OKAY;
    end else begin
      busy_q <= 1'b0;
      hrdata_o <= read_data_next;
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      if (req_valid_q && !req_err_q) begin
        if (req_write_q) begin
          if (req_data_q) begin
            hresp_o <= AHB_HRESP_ERROR;
          end else if (req_reg_q) begin
            if (!is_known_reg(req_reg_offset)) begin
              hresp_o <= AHB_HRESP_ERROR;
            end else begin
              unique case (req_reg_offset)
                OTP_CTRL_OFFSET: begin
                  if (hwdata_i[OTP_CTRL_CLEAR_BIT]) begin
                    done_q <= 1'b0;
                    error_q <= 1'b0;
                  end
                  if (hwdata_i[OTP_CTRL_PROG_EN_BIT] && hwdata_i[OTP_CTRL_START_BIT]) begin
                    busy_q <= 1'b1;
                    done_q <= 1'b0;
                    error_q <= 1'b0;
                    if (!otp_program_legal) begin
                      error_q <= 1'b1;
                    end else begin
                      done_q <= 1'b1;
                    end
                  end
                end
                OTP_ADDR_OFFSET: begin
                  addr_reg_q <= hwdata_i;
                end
                OTP_WDATA_OFFSET: begin
                  wdata_reg_q <= hwdata_i;
                end
                OTP_KEY_OFFSET: begin
                  key_unlocked_q <= (hwdata_i == OTP_KEY_VALUE);
                end
                OTP_LOCK_OFFSET: begin
                  if (hwdata_i[0]) begin
                    locked_q <= 1'b1;
                    key_unlocked_q <= 1'b0;
                  end
                end
                default: begin
                  hresp_o <= AHB_HRESP_ERROR;
                end
              endcase
            end
          end
        end else if (req_reg_q && !is_known_reg(req_reg_offset)) begin
          hresp_o <= AHB_HRESP_ERROR;
        end
      end

      req_valid_q  <= addr_phase_valid;
      req_write_q  <= hwrite_i;
      req_data_q   <= addr_data_region;
      req_reg_q    <= addr_reg_region;
      req_err_q    <= addr_phase_err;
      req_offset_q <= addr_offset;
      req_size_q   <= hsize_i;
    end
  end

  logic unused_req_size;
  assign unused_req_size = ^req_size_q;
endmodule
