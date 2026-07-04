`timescale 1ns/1ps

// Two-master AHB-Lite arbiter for the wasp1 shared SoC bus.
//
// The implementation is intentionally non-pipelined: one selected single-beat
// transfer completes its address, slave wait, and response phases before the
// next master can be granted. This conservative timing avoids mixing the
// address-phase owner with the later data/response owner when the core and DMA
// contend for the fabric.
module ahb_arbiter_2m #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH
) (
  input  logic                  hclk_i,          // AHB fabric clock.
  input  logic                  hresetn_i,       // Active-low asynchronous reset.

  input  logic [ADDR_WIDTH-1:0] m0_haddr_i,      // Master 0 byte address.
  input  logic [1:0]            m0_htrans_i,     // Master 0 transfer type; bit[1] means active.
  input  logic                  m0_hwrite_i,     // Master 0 write indicator.
  input  logic [2:0]            m0_hsize_i,      // Master 0 transfer size.
  input  logic [2:0]            m0_hburst_i,     // Master 0 burst type; SINGLE is expected.
  input  logic [3:0]            m0_hprot_i,      // Master 0 protection attributes.
  input  logic                  m0_hmastlock_i,  // Master 0 lock request; passed through.
  input  logic [DATA_WIDTH-1:0] m0_hwdata_i,     // Master 0 write data for the data phase.
  output logic [DATA_WIDTH-1:0] m0_hrdata_o,     // Master 0 routed read data.
  output logic                  m0_hready_o,     // Master 0 ready/response-valid indication.
  output logic                  m0_hresp_o,      // Master 0 routed response; high means ERROR.

  input  logic [ADDR_WIDTH-1:0] m1_haddr_i,      // Master 1 byte address.
  input  logic [1:0]            m1_htrans_i,     // Master 1 transfer type; bit[1] means active.
  input  logic                  m1_hwrite_i,     // Master 1 write indicator.
  input  logic [2:0]            m1_hsize_i,      // Master 1 transfer size.
  input  logic [2:0]            m1_hburst_i,     // Master 1 burst type; SINGLE is expected.
  input  logic [3:0]            m1_hprot_i,      // Master 1 protection attributes.
  input  logic                  m1_hmastlock_i,  // Master 1 lock request; passed through.
  input  logic [DATA_WIDTH-1:0] m1_hwdata_i,     // Master 1 write data for the data phase.
  output logic [DATA_WIDTH-1:0] m1_hrdata_o,     // Master 1 routed read data.
  output logic                  m1_hready_o,     // Master 1 ready/response-valid indication.
  output logic                  m1_hresp_o,      // Master 1 routed response; high means ERROR.

  output logic [ADDR_WIDTH-1:0] haddr_o,         // Shared AHB byte address.
  output logic [1:0]            htrans_o,        // Shared AHB transfer type.
  output logic                  hwrite_o,        // Shared AHB write indicator.
  output logic [2:0]            hsize_o,         // Shared AHB transfer size.
  output logic [2:0]            hburst_o,        // Shared AHB burst type.
  output logic [3:0]            hprot_o,         // Shared AHB protection attributes.
  output logic                  hmastlock_o,     // Shared AHB lock request.
  output logic [DATA_WIDTH-1:0] hwdata_o,        // Shared AHB write data.
  input  logic [DATA_WIDTH-1:0] hrdata_i,        // Shared slave read data.
  input  logic                  hready_i,        // Shared slave response ready.
  input  logic                  hresp_i,         // Shared slave response; high means ERROR.

  output logic                  grant_valid_o,   // High during the emitted address phase.
  output logic                  grant_idx_o      // Granted master index during address phase.
);
  import wasp1_pkg::*;

  typedef enum logic [1:0] {
    ARB_IDLE,  // No outstanding transfer; choose the next requester.
    ARB_ADDR,  // Drive the selected master's address/control for one cycle.
    ARB_WAIT,  // Hold write data while the registered slave produces response.
    ARB_RESP   // Route the stable slave response back to the selected master.
  } arb_state_e;

  arb_state_e state_q;       // Current arbiter transaction phase.
  logic       owner_q;       // Master index for the outstanding transaction.
  logic       last_grant_q;  // Last address-phase winner, used for round-robin tie break.

  logic       m0_req;        // Master 0 currently requests a transfer.
  logic       m1_req;        // Master 1 currently requests a transfer.
  logic       choose_valid;  // At least one master requests while arbiter is idle.
  logic       choose_idx;    // Next master selected from current requests.
  logic       owner_is_m0;   // Outstanding transaction belongs to master 0.
  logic       owner_is_m1;   // Outstanding transaction belongs to master 1.

  assign m0_req = m0_htrans_i[1];
  assign m1_req = m1_htrans_i[1];
  assign owner_is_m0 = (owner_q == 1'b0);
  assign owner_is_m1 = (owner_q == 1'b1);

  // Round-robin choice is made only when the arbiter is idle. Once a master is
  // selected, owner_q remains fixed until that transfer reaches ARB_RESP.
  always_comb begin
    choose_valid = m0_req || m1_req;
    choose_idx = owner_q;

    unique case ({m1_req, m0_req})
      2'b01: choose_idx = 1'b0;
      2'b10: choose_idx = 1'b1;
      2'b11: choose_idx = (last_grant_q == 1'b0) ? 1'b1 : 1'b0;
      default: choose_idx = owner_q;
    endcase
  end

  // The state machine serializes transfers so the response owner is always the
  // same master that drove the address phase.
  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      state_q      <= ARB_IDLE;
      owner_q      <= 1'b0;
      last_grant_q <= 1'b1;
    end else begin
      unique case (state_q)
        ARB_IDLE: begin
          if (choose_valid) begin
            owner_q <= choose_idx;
            last_grant_q <= choose_idx;
            state_q <= ARB_ADDR;
          end
        end

        ARB_ADDR: begin
          state_q <= ARB_WAIT;
        end

        ARB_WAIT: begin
          if (hready_i) begin
            state_q <= ARB_RESP;
          end
        end

        ARB_RESP: begin
          if (hready_i) begin
            state_q <= ARB_IDLE;
          end
        end

        default: begin
          state_q <= ARB_IDLE;
        end
      endcase
    end
  end

  // Address/control are emitted only in ARB_ADDR. Write data is held through
  // ARB_WAIT because registered slaves consume HWDATA one cycle after the
  // accepted address phase.
  always_comb begin
    haddr_o     = '0;
    htrans_o    = AHB_HTRANS_IDLE;
    hwrite_o    = 1'b0;
    hsize_o     = AHB_HSIZE_WORD;
    hburst_o    = AHB_HBURST_SINGLE;
    hprot_o     = 4'h0;
    hmastlock_o = 1'b0;
    hwdata_o    = '0;

    if (state_q inside {ARB_ADDR, ARB_WAIT}) begin
      if (owner_is_m0) begin
        haddr_o     = m0_haddr_i;
        hwrite_o    = m0_hwrite_i;
        hsize_o     = m0_hsize_i;
        hburst_o    = m0_hburst_i;
        hprot_o     = m0_hprot_i;
        hmastlock_o = m0_hmastlock_i;
        hwdata_o    = m0_hwdata_i;
      end else begin
        haddr_o     = m1_haddr_i;
        hwrite_o    = m1_hwrite_i;
        hsize_o     = m1_hsize_i;
        hburst_o    = m1_hburst_i;
        hprot_o     = m1_hprot_i;
        hmastlock_o = m1_hmastlock_i;
        hwdata_o    = m1_hwdata_i;
      end
    end

    if (state_q == ARB_ADDR) begin
      htrans_o = AHB_HTRANS_NONSEQ;
    end
  end

  // Requesting masters that are not the current owner see HREADY low. The
  // owner sees one ready pulse for address acceptance and one response-valid
  // pulse when the selected slave response is stable.
  always_comb begin
    m0_hrdata_o = '0;
    m0_hready_o = !m0_req;
    m0_hresp_o  = AHB_HRESP_OKAY;
    m1_hrdata_o = '0;
    m1_hready_o = !m1_req;
    m1_hresp_o  = AHB_HRESP_OKAY;

    if ((state_q == ARB_ADDR) && owner_is_m0) begin
      m0_hready_o = 1'b1;
    end else if ((state_q == ARB_ADDR) && owner_is_m1) begin
      m1_hready_o = 1'b1;
    end else if ((state_q == ARB_WAIT) && owner_is_m0) begin
      m0_hready_o = 1'b0;
    end else if ((state_q == ARB_WAIT) && owner_is_m1) begin
      m1_hready_o = 1'b0;
    end else if ((state_q == ARB_RESP) && owner_is_m0) begin
      m0_hrdata_o = hrdata_i;
      m0_hready_o = hready_i;
      m0_hresp_o  = hresp_i;
    end else if ((state_q == ARB_RESP) && owner_is_m1) begin
      m1_hrdata_o = hrdata_i;
      m1_hready_o = hready_i;
      m1_hresp_o  = hresp_i;
    end
  end

  assign grant_valid_o = (state_q == ARB_ADDR);
  assign grant_idx_o = owner_q;
endmodule
