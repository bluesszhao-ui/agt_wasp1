`timescale 1ns/1ps

// RISC-V Debug v0.13-style JTAG Debug Transport Module for wasp1.
//
// The TAP state machine runs in the external JTAG TCK domain, while the DMI
// ready/valid channel runs in the system debug clock domain. A single-entry
// toggle handshake crosses one DMI request and one DMI response between the two
// domains. Request and response payload registers remain stable until the
// opposite domain observes the associated toggle.
module debug_jtag_dtm #(
  // JTAG instruction register length. Five bits match the RISC-V JTAG DTM IRs.
  parameter int IR_WIDTH = 5,
  // DMI address width reported in DTMCS.abits and used by the DMI scan chain.
  parameter int DMI_ADDR_WIDTH = debug_dmi_pkg::DMI_ADDR_WIDTH,
  // JTAG IDCODE shifted by the IDCODE data register.
  parameter logic [31:0] IDCODE_VALUE = 32'h1000_01CF
) (
  // System debug clock for the ready/valid DMI interface.
  input  logic clk_i,
  // Active-low reset for the system debug clock domain.
  input  logic rst_ni,

  // JTAG test clock. All TAP state and scan registers use this clock.
  input  logic tck_i,
  // Active-low asynchronous JTAG reset. TMS reset also returns the TAP to reset.
  input  logic trst_ni,
  // JTAG test mode select, sampled on the rising edge of tck_i.
  input  logic tms_i,
  // JTAG serial data input, sampled while shifting IR or DR.
  input  logic tdi_i,
  // JTAG serial data output, updated on the falling edge of tck_i.
  output logic tdo_o,

  // Debug Module Interface master port driven by the DTM in the clk_i domain.
  debug_dmi_if.dtm dmi,

  // One-tck pulse when DTMCS.dmihardreset is written as one.
  output logic dtm_hardreset_o
);
  import debug_dmi_pkg::*;

  // Standard RISC-V Debug JTAG DTM instruction encodings.
  localparam logic [IR_WIDTH-1:0] IR_IDCODE = {{(IR_WIDTH-1){1'b0}}, 1'b1};
  localparam logic [IR_WIDTH-1:0] IR_DTMCS  = {{(IR_WIDTH-5){1'b0}}, 5'b10000};
  localparam logic [IR_WIDTH-1:0] IR_DMI    = {{(IR_WIDTH-5){1'b0}}, 5'b10001};
  localparam logic [IR_WIDTH-1:0] IR_BYPASS = {IR_WIDTH{1'b1}};

  // DMI scan chain is {address, data, op}. The op/status bits shift first.
  localparam int DMI_DR_WIDTH = DMI_ADDR_WIDTH + 34;
  localparam int DR_WIDTH = (DMI_DR_WIDTH > 32) ? DMI_DR_WIDTH : 32;
  localparam logic [5:0] DMI_ABITS = 6'(DMI_ADDR_WIDTH);

  // TAP controller states from IEEE 1149.1.
  typedef enum logic [3:0] {
    TAP_TEST_LOGIC_RESET = 4'd0,
    TAP_RUN_TEST_IDLE    = 4'd1,
    TAP_SELECT_DR_SCAN   = 4'd2,
    TAP_CAPTURE_DR       = 4'd3,
    TAP_SHIFT_DR         = 4'd4,
    TAP_EXIT1_DR         = 4'd5,
    TAP_PAUSE_DR         = 4'd6,
    TAP_EXIT2_DR         = 4'd7,
    TAP_UPDATE_DR        = 4'd8,
    TAP_SELECT_IR_SCAN   = 4'd9,
    TAP_CAPTURE_IR       = 4'd10,
    TAP_SHIFT_IR         = 4'd11,
    TAP_EXIT1_IR         = 4'd12,
    TAP_PAUSE_IR         = 4'd13,
    TAP_EXIT2_IR         = 4'd14,
    TAP_UPDATE_IR        = 4'd15
  } tap_state_e;

  // Current and next TAP FSM state in the TCK domain.
  tap_state_e tap_state_q;
  tap_state_e tap_state_d;

  // Active decoded instruction and shift register for IR scans.
  logic [IR_WIDTH-1:0] ir_q;
  logic [IR_WIDTH-1:0] ir_shift_q;

  // Shared DR shift register. Shorter DRs use the low bits.
  logic [DR_WIDTH-1:0] dr_shift_q;

  // TCK-domain sticky DTM status and last response returned through DMI scans.
  logic                         dmi_busy_tck_q;
  logic                         dmi_busy_sticky_q;
  logic                         dmi_error_sticky_q;
  logic [DMI_ADDR_WIDTH-1:0]    last_rsp_addr_tck_q;
  logic [31:0]                  last_rsp_data_tck_q;
  logic [1:0]                   last_rsp_resp_tck_q;

  // Stable request payload crossing from TCK to clk_i.
  logic [DMI_ADDR_WIDTH-1:0]    req_addr_tck_q;
  logic [31:0]                  req_data_tck_q;
  logic [1:0]                   req_op_tck_q;
  logic                         req_toggle_tck_q;

  // Stable response payload crossing from clk_i to TCK.
  logic [DMI_ADDR_WIDTH-1:0]    rsp_addr_clk_q;
  logic [31:0]                  rsp_data_clk_q;
  logic [1:0]                   rsp_resp_clk_q;
  logic                         rsp_toggle_clk_q;

  // Toggle synchronizers from clk_i response domain into TCK.
  logic rsp_toggle_tck_meta_q;
  logic rsp_toggle_tck_sync_q;
  logic rsp_toggle_tck_seen_q;
  logic rsp_toggle_seen_now;

  // Toggle synchronizers from TCK request domain into clk_i.
  logic req_toggle_clk_meta_q;
  logic req_toggle_clk_sync_q;
  logic req_toggle_clk_seen_q;
  logic req_toggle_seen_now;

  // clk_i-domain DMI transaction state.
  logic                         dmi_req_valid_q;
  logic                         dmi_rsp_wait_q;
  logic [DMI_ADDR_WIDTH-1:0]    dmi_addr_q;
  logic [31:0]                  dmi_data_q;
  logic [1:0]                   dmi_op_q;

  // Decoded write bits from a DTMCS update scan.
  logic dtmcs_write_dmireset;
  logic dtmcs_write_dmihardreset;

  // Active instruction treats unsupported IR values as BYPASS.
  logic [IR_WIDTH-1:0] active_ir;

  // Current DTMCS value. dmistat reports sticky busy before sticky failed.
  logic [31:0] dtmcs_value;

  assign active_ir =
      ((ir_q == IR_IDCODE) || (ir_q == IR_DTMCS) || (ir_q == IR_DMI) || (ir_q == IR_BYPASS))
        ? ir_q
        : IR_BYPASS;

  assign dtmcs_value = {
    14'b0,                         // Reserved upper bits read as zero.
    1'b0,                          // dmihardreset is write-one only.
    1'b0,                          // dmireset is write-one only.
    1'b0,                          // Reserved.
    3'd1,                          // idle: one Run-Test/Idle cycle is enough.
    (dmi_busy_sticky_q ? DMI_RESP_BUSY :
      (dmi_error_sticky_q ? DMI_RESP_FAILED : DMI_RESP_SUCCESS)),
    DMI_ABITS,                      // abits: number of DMI address bits.
    4'd1                           // version: RISC-V Debug v0.13 JTAG DTM.
  };

  assign dtmcs_write_dmireset     = dr_shift_q[16];
  assign dtmcs_write_dmihardreset = dr_shift_q[17];

  // Ready/valid DMI master signals driven in the system debug clock domain.
  assign dmi.req_valid = dmi_req_valid_q;
  assign dmi.req_op    = dmi_op_q;
  assign dmi.req_addr  = dmi_addr_q;
  assign dmi.req_data  = dmi_data_q;
  assign dmi.rsp_ready = dmi_rsp_wait_q;

  // Next-state logic for the standard TAP controller.
  always_comb begin
    unique case (tap_state_q)
      TAP_TEST_LOGIC_RESET: tap_state_d = tms_i ? TAP_TEST_LOGIC_RESET : TAP_RUN_TEST_IDLE;
      TAP_RUN_TEST_IDLE:    tap_state_d = tms_i ? TAP_SELECT_DR_SCAN   : TAP_RUN_TEST_IDLE;
      TAP_SELECT_DR_SCAN:   tap_state_d = tms_i ? TAP_SELECT_IR_SCAN   : TAP_CAPTURE_DR;
      TAP_CAPTURE_DR:       tap_state_d = tms_i ? TAP_EXIT1_DR         : TAP_SHIFT_DR;
      TAP_SHIFT_DR:         tap_state_d = tms_i ? TAP_EXIT1_DR         : TAP_SHIFT_DR;
      TAP_EXIT1_DR:         tap_state_d = tms_i ? TAP_UPDATE_DR        : TAP_PAUSE_DR;
      TAP_PAUSE_DR:         tap_state_d = tms_i ? TAP_EXIT2_DR         : TAP_PAUSE_DR;
      TAP_EXIT2_DR:         tap_state_d = tms_i ? TAP_UPDATE_DR        : TAP_SHIFT_DR;
      TAP_UPDATE_DR:        tap_state_d = tms_i ? TAP_SELECT_DR_SCAN   : TAP_RUN_TEST_IDLE;
      TAP_SELECT_IR_SCAN:   tap_state_d = tms_i ? TAP_TEST_LOGIC_RESET : TAP_CAPTURE_IR;
      TAP_CAPTURE_IR:       tap_state_d = tms_i ? TAP_EXIT1_IR         : TAP_SHIFT_IR;
      TAP_SHIFT_IR:         tap_state_d = tms_i ? TAP_EXIT1_IR         : TAP_SHIFT_IR;
      TAP_EXIT1_IR:         tap_state_d = tms_i ? TAP_UPDATE_IR        : TAP_PAUSE_IR;
      TAP_PAUSE_IR:         tap_state_d = tms_i ? TAP_EXIT2_IR         : TAP_PAUSE_IR;
      TAP_EXIT2_IR:         tap_state_d = tms_i ? TAP_UPDATE_IR        : TAP_SHIFT_IR;
      TAP_UPDATE_IR:        tap_state_d = tms_i ? TAP_SELECT_DR_SCAN   : TAP_RUN_TEST_IDLE;
      default:              tap_state_d = TAP_TEST_LOGIC_RESET;
    endcase
  end

  assign rsp_toggle_seen_now = (rsp_toggle_tck_sync_q != rsp_toggle_tck_seen_q);

  // TCK-domain TAP state, scan registers, DTMCS side effects, and request launch.
  always_ff @(posedge tck_i or negedge trst_ni or negedge rst_ni) begin
    if (!trst_ni || !rst_ni) begin
      tap_state_q           <= TAP_TEST_LOGIC_RESET;
      ir_q                  <= IR_IDCODE;
      ir_shift_q            <= '0;
      dr_shift_q            <= '0;
      dmi_busy_tck_q        <= 1'b0;
      dmi_busy_sticky_q     <= 1'b0;
      dmi_error_sticky_q    <= 1'b0;
      last_rsp_addr_tck_q   <= '0;
      last_rsp_data_tck_q   <= '0;
      last_rsp_resp_tck_q   <= DMI_RESP_SUCCESS;
      req_addr_tck_q        <= '0;
      req_data_tck_q        <= '0;
      req_op_tck_q          <= DMI_OP_NOP;
      req_toggle_tck_q      <= 1'b0;
      rsp_toggle_tck_meta_q <= 1'b0;
      rsp_toggle_tck_sync_q <= 1'b0;
      rsp_toggle_tck_seen_q <= 1'b0;
      dtm_hardreset_o       <= 1'b0;
    end else begin
      tap_state_q           <= tap_state_d;
      rsp_toggle_tck_meta_q <= rsp_toggle_clk_q;
      rsp_toggle_tck_sync_q <= rsp_toggle_tck_meta_q;
      dtm_hardreset_o       <= 1'b0;

      // Latch completed DMI responses before scan capture uses the response.
      if (rsp_toggle_seen_now) begin
        rsp_toggle_tck_seen_q <= rsp_toggle_tck_sync_q;
        dmi_busy_tck_q        <= 1'b0;
        last_rsp_addr_tck_q   <= rsp_addr_clk_q;
        last_rsp_data_tck_q   <= rsp_data_clk_q;
        last_rsp_resp_tck_q   <= rsp_resp_clk_q;
        if (rsp_resp_clk_q == DMI_RESP_FAILED) begin
          dmi_error_sticky_q <= 1'b1;
        end
      end

      unique case (tap_state_q)
        TAP_TEST_LOGIC_RESET: begin
          ir_q                <= IR_IDCODE;
          dmi_busy_sticky_q   <= 1'b0;
          dmi_error_sticky_q  <= 1'b0;
          last_rsp_resp_tck_q <= DMI_RESP_SUCCESS;
        end

        TAP_CAPTURE_IR: begin
          // IEEE 1149.1 requires IR capture bit[0]=1 and bit[1]=0.
          ir_shift_q <= {{(IR_WIDTH-2){1'b0}}, 2'b01};
        end

        TAP_SHIFT_IR: begin
          ir_shift_q <= {tdi_i, ir_shift_q[IR_WIDTH-1:1]};
        end

        TAP_UPDATE_IR: begin
          ir_q <= ir_shift_q;
        end

        TAP_CAPTURE_DR: begin
          unique case (active_ir)
            IR_IDCODE: dr_shift_q <= {{(DR_WIDTH-32){1'b0}}, IDCODE_VALUE};
            IR_DTMCS:  dr_shift_q <= {{(DR_WIDTH-32){1'b0}}, dtmcs_value};
            IR_DMI: begin
              dr_shift_q <= {{(DR_WIDTH-DMI_DR_WIDTH){1'b0}},
                             last_rsp_addr_tck_q,
                             last_rsp_data_tck_q,
                             (dmi_busy_tck_q ? DMI_RESP_BUSY : last_rsp_resp_tck_q)};
            end
            default:   dr_shift_q <= {{(DR_WIDTH-1){1'b0}}, 1'b0};
          endcase
        end

        TAP_SHIFT_DR: begin
          unique case (active_ir)
            IR_IDCODE,
            IR_DTMCS: begin
              dr_shift_q[31:0] <= {tdi_i, dr_shift_q[31:1]};
              if (DR_WIDTH > 32) begin
                dr_shift_q[DR_WIDTH-1:32] <= '0;
              end
            end
            IR_DMI: begin
              dr_shift_q[DMI_DR_WIDTH-1:0] <= {tdi_i, dr_shift_q[DMI_DR_WIDTH-1:1]};
            end
            default: begin
              dr_shift_q[0] <= tdi_i;
              if (DR_WIDTH > 1) begin
                dr_shift_q[DR_WIDTH-1:1] <= '0;
              end
            end
          endcase
        end

        TAP_UPDATE_DR: begin
          if (active_ir == IR_DTMCS) begin
            if (dtmcs_write_dmireset || dtmcs_write_dmihardreset) begin
              dmi_busy_sticky_q   <= 1'b0;
              dmi_error_sticky_q  <= 1'b0;
              last_rsp_resp_tck_q <= DMI_RESP_SUCCESS;
            end
            if (dtmcs_write_dmihardreset) begin
              dtm_hardreset_o <= 1'b1;
            end
          end else if (active_ir == IR_DMI) begin
            if (dr_shift_q[1:0] != DMI_OP_NOP) begin
              if (dmi_busy_tck_q) begin
                dmi_busy_sticky_q   <= 1'b1;
                last_rsp_resp_tck_q <= DMI_RESP_BUSY;
              end else begin
                req_op_tck_q     <= dr_shift_q[1:0];
                req_data_tck_q   <= dr_shift_q[33:2];
                req_addr_tck_q   <= dr_shift_q[DMI_DR_WIDTH-1:34];
                req_toggle_tck_q <= ~req_toggle_tck_q;
                dmi_busy_tck_q   <= 1'b1;
              end
            end
          end
        end

        default: begin
          // States without side effects are intentionally empty.
        end
      endcase
    end
  end

  // TDO changes on the falling edge so a debugger can sample it on TCK rising.
  always_ff @(negedge tck_i or negedge trst_ni or negedge rst_ni) begin
    if (!trst_ni || !rst_ni) begin
      tdo_o <= 1'b0;
    end else begin
      unique case (tap_state_q)
        TAP_SHIFT_IR: tdo_o <= ir_shift_q[0];
        TAP_SHIFT_DR: tdo_o <= dr_shift_q[0];
        default:      tdo_o <= 1'b0;
      endcase
    end
  end

  assign req_toggle_seen_now = (req_toggle_clk_sync_q != req_toggle_clk_seen_q);

  // System-clock-domain DMI request/response sequencer.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      req_toggle_clk_meta_q <= 1'b0;
      req_toggle_clk_sync_q <= 1'b0;
      req_toggle_clk_seen_q <= 1'b0;
      dmi_req_valid_q       <= 1'b0;
      dmi_rsp_wait_q        <= 1'b0;
      dmi_addr_q            <= '0;
      dmi_data_q            <= '0;
      dmi_op_q              <= DMI_OP_NOP;
      rsp_addr_clk_q        <= '0;
      rsp_data_clk_q        <= '0;
      rsp_resp_clk_q        <= DMI_RESP_SUCCESS;
      rsp_toggle_clk_q      <= 1'b0;
    end else begin
      req_toggle_clk_meta_q <= req_toggle_tck_q;
      req_toggle_clk_sync_q <= req_toggle_clk_meta_q;

      // Capture the stable request payload once the request toggle crosses.
      if (req_toggle_seen_now && !dmi_req_valid_q && !dmi_rsp_wait_q) begin
        req_toggle_clk_seen_q <= req_toggle_clk_sync_q;
        dmi_addr_q            <= req_addr_tck_q;
        dmi_data_q            <= req_data_tck_q;
        dmi_op_q              <= req_op_tck_q;
        dmi_req_valid_q       <= 1'b1;
      end

      // Hold the request until the Debug Module accepts it.
      if (dmi_req_valid_q && dmi.req_ready) begin
        dmi_req_valid_q <= 1'b0;
        dmi_rsp_wait_q  <= 1'b1;
      end

      // Capture the response and toggle completion back into the TCK domain.
      if (dmi_rsp_wait_q && dmi.rsp_valid) begin
        dmi_rsp_wait_q   <= 1'b0;
        rsp_addr_clk_q   <= dmi_addr_q;
        rsp_data_clk_q   <= dmi.rsp_data;
        rsp_resp_clk_q   <= dmi.rsp_resp;
        rsp_toggle_clk_q <= ~rsp_toggle_clk_q;
      end
    end
  end
endmodule
