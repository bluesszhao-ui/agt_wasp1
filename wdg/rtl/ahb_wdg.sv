`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// AHB-Lite watchdog timer peripheral.
//
// The block exposes a small word-only register file. Software programs a
// timeout value, enables counting, and periodically writes the KICK key before
// the counter reaches the timeout. Expiry latches status, optionally asserts an
// interrupt, and optionally requests a system reset.
module ahb_wdg #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::WDG_BASE,
  parameter int REGION_BYTES = wasp1_pkg::PERIPH_SIZE
) (
  input  logic                  hclk_i,          // AHB clock for register and watchdog state.
  input  logic                  hresetn_i,       // Active-low asynchronous reset.
  input  logic                  hsel_i,          // AHB slave select for this watchdog window.
  input  logic [ADDR_WIDTH-1:0] haddr_i,         // AHB byte address during address phase.
  input  logic [1:0]            htrans_i,        // AHB transfer type; bit 1 marks valid transfer.
  input  logic                  hwrite_i,        // AHB write indicator sampled in address phase.
  input  logic [2:0]            hsize_i,         // AHB transfer size; only word access is legal.
  input  logic [DATA_WIDTH-1:0] hwdata_i,        // AHB write data during data phase.
  output logic [DATA_WIDTH-1:0] hrdata_o,        // AHB read data returned one cycle after address.
  output logic                  hready_o,        // Always-ready slave response.
  output logic                  hresp_o,         // AHB response; high means ERROR.
  output logic                  wdg_irq_o,       // Watchdog interrupt request when expired and enabled.
  output logic                  wdg_reset_req_o  // Watchdog reset request when expired and reset enabled.
);
  import wasp1_pkg::*;

  // Captured AHB request metadata for the data/response phase.
  logic                  req_valid_q;
  logic                  req_write_q;
  logic                  req_err_q;
  logic [ADDR_WIDTH-1:0] req_offset_q;
  logic [2:0]            req_size_q;

  // Combinational AHB address-phase decode and error detection.
  logic [ADDR_WIDTH-1:0] addr_offset;
  logic                  addr_in_range;
  logic                  addr_phase_valid;
  logic                  addr_misaligned;
  logic                  addr_unsupported;
  logic                  addr_phase_err;
  logic [DATA_WIDTH-1:0] read_data_next;

  // Software-visible watchdog configuration and state.
  logic                  enable_q;       // Counter advances when set and not expired.
  logic                  irq_en_q;       // Expired status is exported as interrupt when set.
  logic                  reset_en_q;     // Expired status is exported as reset request when set.
  logic [31:0]           timeout_q;      // Terminal count; zero is treated as immediate expiry.
  logic [31:0]           count_q;        // Current watchdog up-counter value.
  logic                  expired_q;      // Sticky timeout-expired status.
  logic                  reset_req_q;    // Sticky reset request status after an enabled expiry.
  logic                  keyerr_q;       // Sticky status for bad KICK writes.

  // Count comparison for the next enabled watchdog tick.
  logic [31:0]           count_plus_one;
  logic                  timeout_hit;

  assign hready_o = 1'b1;
  assign wdg_irq_o = expired_q && irq_en_q;
  assign wdg_reset_req_o = reset_req_q;

  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(REGION_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];
  assign addr_misaligned = |haddr_i[1:0];
  assign addr_unsupported = hsize_i != AHB_HSIZE_WORD;
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || addr_misaligned || addr_unsupported);

  assign count_plus_one = count_q + 32'd1;
  assign timeout_hit = (timeout_q == 32'd0) || (count_plus_one >= timeout_q);

  // Recognize only the documented word registers.
  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    begin
      unique case (reg_offset)
        WDG_CTRL_OFFSET,
        WDG_STATUS_OFFSET,
        WDG_TIMEOUT_OFFSET,
        WDG_COUNT_OFFSET,
        WDG_KICK_OFFSET: is_known_reg = 1'b1;
        default:         is_known_reg = 1'b0;
      endcase
    end
  endfunction

  // Pack CTRL readback from individual control flops.
  function automatic logic [31:0] make_ctrl;
    logic [31:0] ctrl;
    begin
      ctrl = '0;
      ctrl[WDG_CTRL_ENABLE_BIT] = enable_q;
      ctrl[WDG_CTRL_IRQ_EN_BIT] = irq_en_q;
      ctrl[WDG_CTRL_RESET_EN_BIT] = reset_en_q;
      make_ctrl = ctrl;
    end
  endfunction

  // Pack STATUS readback. RUNNING is derived rather than sticky.
  function automatic logic [31:0] make_status;
    logic [31:0] status;
    begin
      status = '0;
      status[WDG_STATUS_EXPIRED_BIT] = expired_q;
      status[WDG_STATUS_RESET_REQ_BIT] = reset_req_q;
      status[WDG_STATUS_KEYERR_BIT] = keyerr_q;
      status[WDG_STATUS_RUNNING_BIT] = enable_q && !expired_q;
      make_status = status;
    end
  endfunction

  // Read data is produced from the previous cycle's captured address phase.
  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      unique case (req_offset_q)
        WDG_CTRL_OFFSET:    read_data_next = make_ctrl();
        WDG_STATUS_OFFSET:  read_data_next = make_status();
        WDG_TIMEOUT_OFFSET: read_data_next = timeout_q;
        WDG_COUNT_OFFSET:   read_data_next = count_q;
        WDG_KICK_OFFSET:    read_data_next = '0;
        default:            read_data_next = '0;
      endcase
    end
  end

  // Register phase, watchdog count/update, and AHB response generation.
  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      req_valid_q  <= 1'b0;
      req_write_q  <= 1'b0;
      req_err_q    <= 1'b0;
      req_offset_q <= '0;
      req_size_q   <= AHB_HSIZE_WORD;
      enable_q     <= 1'b0;
      irq_en_q     <= 1'b0;
      reset_en_q   <= 1'b0;
      timeout_q    <= 32'h0000_FFFF;
      count_q      <= '0;
      expired_q    <= 1'b0;
      reset_req_q  <= 1'b0;
      keyerr_q     <= 1'b0;
      hrdata_o     <= '0;
      hresp_o      <= AHB_HRESP_OKAY;
    end else begin
      // Default response reflects the captured address phase error.
      hrdata_o <= read_data_next;
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      // Free-running watchdog tick. Software write handling below has priority
      // so a clear/kick on the data phase can prevent a same-cycle expiry.
      if (enable_q && !expired_q) begin
        if (timeout_hit) begin
          expired_q <= 1'b1;
          reset_req_q <= reset_en_q;
        end else begin
          count_q <= count_plus_one;
        end
      end

      if (req_valid_q && !req_err_q) begin
        if (!is_known_reg(req_offset_q[31:0])) begin
          hresp_o <= AHB_HRESP_ERROR;
        end else if (req_write_q) begin
          unique case (req_offset_q)
            WDG_CTRL_OFFSET: begin
              enable_q <= hwdata_i[WDG_CTRL_ENABLE_BIT];
              irq_en_q <= hwdata_i[WDG_CTRL_IRQ_EN_BIT];
              reset_en_q <= hwdata_i[WDG_CTRL_RESET_EN_BIT];
              if (hwdata_i[WDG_CTRL_CLEAR_BIT]) begin
                count_q <= '0;
                expired_q <= 1'b0;
                reset_req_q <= 1'b0;
                keyerr_q <= 1'b0;
              end
            end
            WDG_TIMEOUT_OFFSET: begin
              timeout_q <= hwdata_i;
            end
            WDG_KICK_OFFSET: begin
              if (hwdata_i == WDG_KICK_VALUE) begin
                count_q <= '0;
                expired_q <= 1'b0;
                reset_req_q <= 1'b0;
              end else begin
                keyerr_q <= 1'b1;
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

  // Keep the captured size visible to lint while all size legality is checked
  // in the address phase.
  logic unused_req_size;
  assign unused_req_size = ^req_size_q;
endmodule
