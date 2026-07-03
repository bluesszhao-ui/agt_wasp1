`timescale 1ns/1ps

// Core-side memory-to-AHB bridge.
//
// The tile exposes separate I-cache and D-cache downstream memory ports, while
// the SoC AHB fabric intentionally sees only one core master. This bridge
// arbitrates the two cache ports, issues one single-beat AHB-Lite transfer at a
// time, and returns the response to the selected cache. D-cache requests have
// priority over I-cache requests to reduce load/store completion latency.
module wasp1_core_ahb_bridge #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH
) (
  input  logic                  hclk_i,       // AHB and cache downstream clock.
  input  logic                  hresetn_i,    // Active-low asynchronous reset.
  mem_req_rsp_if.target         imem_if,      // I-cache downstream request port.
  mem_req_rsp_if.target         dmem_if,      // D-cache downstream request port.
  output logic [ADDR_WIDTH-1:0] haddr_o,      // AHB byte address.
  output logic [1:0]            htrans_o,     // AHB transfer type.
  output logic                  hwrite_o,     // AHB write indicator.
  output logic [2:0]            hsize_o,      // AHB transfer size.
  output logic [2:0]            hburst_o,     // AHB burst type; SINGLE only.
  output logic [3:0]            hprot_o,      // AHB protection attributes.
  output logic                  hmastlock_o,  // AHB locked transfer; unused.
  output logic [DATA_WIDTH-1:0] hwdata_o,     // AHB write data.
  input  logic [DATA_WIDTH-1:0] hrdata_i,     // AHB read data.
  input  logic                  hready_i,     // AHB ready from fabric.
  input  logic                  hresp_i       // AHB response; high means ERROR.
);
  import wasp1_pkg::*;

  typedef enum logic [2:0] {
    BR_IDLE,      // No cached request is outstanding.
    BR_ADDR,      // AHB address phase is being presented.
    BR_DATA_WAIT, // Registered SoC slaves are producing read data/response.
    BR_RESP,      // Stable AHB data/response phase is being sampled.
    BR_RSP_HOLD   // Cache response is held until consumed.
  } bridge_state_e;

  bridge_state_e         state_q;       // Current bridge transaction state.
  logic                  sel_dmem_q;    // One when the outstanding request targets D-cache.
  logic [ADDR_WIDTH-1:0] req_addr_q;    // Latched request byte address.
  logic                  req_write_q;   // Latched request direction.
  logic [1:0]            req_size_q;    // Latched lightweight request size.
  logic [DATA_WIDTH-1:0] req_wdata_q;   // Latched write data.
  logic [DATA_WIDTH-1:0] rsp_rdata_q;   // Latched AHB response read data.
  logic                  rsp_err_q;     // Latched AHB response error.

  logic                  dmem_grant;    // IDLE-cycle combinational D-cache selection.
  logic                  imem_grant;    // IDLE-cycle combinational I-cache selection.
  logic                  rsp_accept;    // Selected cache consumes the held response.

  assign dmem_grant = (state_q == BR_IDLE) && dmem_if.req_valid;
  assign imem_grant = (state_q == BR_IDLE) && !dmem_if.req_valid && imem_if.req_valid;

  assign dmem_if.req_ready = dmem_grant;
  assign imem_if.req_ready = imem_grant;

  assign dmem_if.rsp_valid = (state_q == BR_RSP_HOLD) && sel_dmem_q;
  assign imem_if.rsp_valid = (state_q == BR_RSP_HOLD) && !sel_dmem_q;
  assign dmem_if.rsp_rdata = rsp_rdata_q;
  assign imem_if.rsp_rdata = rsp_rdata_q;
  assign dmem_if.rsp_err = rsp_err_q;
  assign imem_if.rsp_err = rsp_err_q;

  assign rsp_accept = (sel_dmem_q && dmem_if.rsp_ready) ||
                      (!sel_dmem_q && imem_if.rsp_ready);

  assign hburst_o = AHB_HBURST_SINGLE;
  assign hmastlock_o = 1'b0;

  // Translate the lightweight byte/half/word code to AHB HSIZE.
  always_comb begin
    unique case (req_size_q)
      MEM_SIZE_BYTE: hsize_o = AHB_HSIZE_BYTE;
      MEM_SIZE_HALF: hsize_o = AHB_HSIZE_HALF;
      default:       hsize_o = AHB_HSIZE_WORD;
    endcase
  end

  // AHB address/control outputs are valid only while the bridge is in the
  // address phase. HPROT bit[2] marks instruction fetches when the selected
  // request came from the I-cache path.
  always_comb begin
    haddr_o = req_addr_q;
    htrans_o = AHB_HTRANS_IDLE;
    hwrite_o = req_write_q;
    hwdata_o = req_wdata_q;
    hprot_o = sel_dmem_q ? 4'h5 : 4'h4;

    if (state_q == BR_ADDR) begin
      htrans_o = AHB_HTRANS_NONSEQ;
    end
  end

  // The bridge accepts one cache request, waits for the AHB response, then
  // holds the cache response stable until that cache consumes it.
  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      state_q <= BR_IDLE;
      sel_dmem_q <= 1'b0;
      req_addr_q <= '0;
      req_write_q <= 1'b0;
      req_size_q <= MEM_SIZE_WORD;
      req_wdata_q <= '0;
      rsp_rdata_q <= '0;
      rsp_err_q <= 1'b0;
    end else begin
      unique case (state_q)
        BR_IDLE: begin
          if (dmem_grant || imem_grant) begin
            sel_dmem_q <= dmem_grant;
            req_addr_q <= dmem_grant ? dmem_if.req_addr : imem_if.req_addr;
            req_write_q <= dmem_grant ? dmem_if.req_write : imem_if.req_write;
            req_size_q <= dmem_grant ? dmem_if.req_size : imem_if.req_size;
            req_wdata_q <= dmem_grant ? dmem_if.req_wdata : imem_if.req_wdata;
            state_q <= BR_ADDR;
          end
        end

        BR_ADDR: begin
          if (hready_i) begin
            state_q <= BR_DATA_WAIT;
          end
        end

        BR_DATA_WAIT: begin
          if (hready_i) begin
            state_q <= BR_RESP;
          end
        end

        BR_RESP: begin
          if (hready_i) begin
            rsp_rdata_q <= hrdata_i;
            rsp_err_q <= hresp_i;
            state_q <= BR_RSP_HOLD;
          end
        end

        BR_RSP_HOLD: begin
          if (rsp_accept) begin
            state_q <= BR_IDLE;
          end
        end

        default: begin
          state_q <= BR_IDLE;
        end
      endcase
    end
  end
endmodule
