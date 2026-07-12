`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// RISC-V Debug Module register file and one-entry DMI response buffer.
module debug_dmi_regs (
  input  logic              clk_i,                 // Debug clock for all local sequential state.
  input  logic              rst_ni,                // Asynchronous active-low reset for the Debug Module.
  debug_dmi_if.dm            dmi,                   // DMI request/response channel from the external JTAG DTM wrapper.
  input  logic              hart_halted_i,         // Selected hart reports that it is halted in Debug Mode.
  input  logic              hart_running_i,        // Selected hart reports normal instruction execution.
  input  logic              hart_resumeack_i,      // Selected hart acknowledges the outstanding resume request.
  input  logic              hart_havereset_i,      // Selected hart reports that reset has occurred.
  input  logic              abstract_busy_i,       // Abstract command executor is processing a command.
  input  logic              command_error_valid_i, // Executor completed with a valid cmderr update.
  input  logic [2:0]        command_error_i,       // Executor error code written into abstractcs.cmderr.
  input  logic              data0_we_i,            // Executor writes a completed GPR result into data0.
  input  logic [31:0]       data0_wdata_i,         // Executor result data for data0.
  input  logic              data1_we_i,            // Executor writes postincremented memory address into data1.
  input  logic [31:0]       data1_wdata_i,         // Executor result data for data1.
  output logic              dmactive_o,            // Debug Module active state from dmcontrol.dmactive.
  output logic              ndmreset_o,            // Non-debug module reset request from dmcontrol.ndmreset.
  output logic              haltreq_o,             // Halt request for the implemented hart 0.
  output logic              resumereq_o,           // Resume request held until hart_resumeack_i is observed.
  output logic              ackhavereset_o,        // One-cycle pulse acknowledging the hart reset indication.
  output logic              command_valid_o,       // One-cycle pulse for an accepted abstract command write.
  output logic [31:0]       command_o,             // Most recently accepted abstract command word.
  output logic [31:0]       data0_o,               // Abstract data register 0 shared with the executor.
  output logic [31:0]       data1_o,               // Abstract data register 1, used as Access Memory address.
  output logic [debug_dmi_pkg::PROGBUF_WORD_COUNT-1:0][31:0]
                            progbuf_words_o        // Full Program Buffer image for the integrated executor path.
);
  import debug_dmi_pkg::*;

  localparam int PROGBUF_INDEX_WIDTH = $clog2(PROGBUF_WORD_COUNT);

  // Debug Module control state. Only hart 0 exists, but hartsel is retained so
  // debuggers can probe a non-existent hart and receive architectural status.
  logic        dmactive_q;
  logic        ndmreset_q;
  logic        haltreq_q;
  logic        resumereq_q;
  logic [19:0] hartsel_q;

  // Abstract command state visible through command, abstractcs, and data0.
  logic [31:0] command_q;
  logic [31:0] data0_q;
  logic [31:0] data1_q;
  logic [2:0]  cmderr_q;

  // A one-entry registered response makes DMI backpressure fully deterministic.
  logic        rsp_valid_q;
  logic [1:0]  rsp_resp_q;
  logic [31:0] rsp_data_q;

  // Combinational request decode and readback images.
  logic        req_known_addr;
  logic        req_supported;
  logic        selected_hart_exists;
  logic [31:0] dmcontrol_rdata;
  logic [31:0] dmstatus_rdata;
  logic [31:0] abstractcs_rdata;
  logic [31:0] read_data;
  logic        hart_halted_visible;
  logic        hart_resumeack_visible;
  logic        req_abstract_payload; // Request addresses data0/data1 or one Program Buffer word.

  // Program Buffer storage controls are derived from the accepted DMI request.
  logic        progbuf_clear;       // Reset/DM-deactivation clear request to the storage leaf.
  logic        progbuf_write_valid; // Accepted idle DMI write to one Program Buffer word.
  logic [PROGBUF_INDEX_WIDTH-1:0] progbuf_index; // Address-derived read/write word index.
  logic [31:0] progbuf_read_data;   // Selected Program Buffer readback word.

  // The output requests are suppressed whenever the Debug Module is inactive
  // or software selected a hart number other than the implemented hart 0.
  assign selected_hart_exists = (hartsel_q == 20'd0);
  assign dmactive_o = dmactive_q;
  assign ndmreset_o = dmactive_q && ndmreset_q;
  assign haltreq_o = dmactive_q && selected_hart_exists && haltreq_q;
  assign resumereq_o = dmactive_q && selected_hart_exists && resumereq_q;
  assign command_o = command_q;
  assign data0_o = data0_q;
  assign data1_o = data1_q;
  assign hart_halted_visible = hart_halted_i && !resumereq_q;
  assign hart_resumeack_visible = hart_resumeack_i && !resumereq_q;
  assign progbuf_index = dmi.req_addr[PROGBUF_INDEX_WIDTH-1:0];

  // Inactive DM state continuously clears storage. An accepted dmactive-clear
  // write also clears on that same edge rather than waiting for dmactive_q.
  assign progbuf_clear = !dmactive_q ||
      (dmi.req_valid && dmi.req_ready && req_supported &&
       (dmi.req_op == DMI_OP_WRITE) &&
       (dmi.req_addr == DMI_ADDR_DMCONTROL) && !dmi.req_data[0]);
  assign progbuf_write_valid = dmi.req_valid && dmi.req_ready && req_supported &&
      (dmi.req_op == DMI_OP_WRITE) && dmactive_q && !abstract_busy_i &&
      (dmi.req_addr >= DMI_ADDR_PROGBUF0) &&
      (dmi.req_addr <= DMI_ADDR_PROGBUF3);

  // The response slot can accept a request when empty or when its current
  // response is consumed on this edge, allowing bubble-free DMI transfers.
  assign dmi.req_ready = !rsp_valid_q || dmi.rsp_ready;
  assign dmi.rsp_valid = rsp_valid_q;
  assign dmi.rsp_resp = rsp_resp_q;
  assign dmi.rsp_data = rsp_data_q;

  // Defined read-only and read/write register addresses are all legal for both
  // DMI read and write operations. Writes to read-only registers are ignored.
  always_comb begin
    unique case (dmi.req_addr)
      DMI_ADDR_DATA0,
      DMI_ADDR_DATA1,
      DMI_ADDR_DMCONTROL,
      DMI_ADDR_DMSTATUS,
      DMI_ADDR_HARTINFO,
      DMI_ADDR_ABSTRACTCS,
      DMI_ADDR_COMMAND,
      DMI_ADDR_ABSTRACTAUTO,
      DMI_ADDR_PROGBUF0,
      DMI_ADDR_PROGBUF1,
      DMI_ADDR_PROGBUF2,
      DMI_ADDR_PROGBUF3: req_known_addr = 1'b1;
      default:          req_known_addr = 1'b0;
    endcase

    unique case (dmi.req_addr)
      DMI_ADDR_DATA0,
      DMI_ADDR_DATA1,
      DMI_ADDR_PROGBUF0,
      DMI_ADDR_PROGBUF1,
      DMI_ADDR_PROGBUF2,
      DMI_ADDR_PROGBUF3: req_abstract_payload = 1'b1;
      default:           req_abstract_payload = 1'b0;
    endcase

    req_supported = (dmi.req_op == DMI_OP_NOP) ||
                    (((dmi.req_op == DMI_OP_READ) ||
                      (dmi.req_op == DMI_OP_WRITE)) && req_known_addr);
  end

  // dmcontrol readback exposes implemented fields; unsupported hart-reset and
  // reset-halt controls are hardwired to zero.
  always_comb begin
    dmcontrol_rdata = '0;
    dmcontrol_rdata[31] = haltreq_q;
    dmcontrol_rdata[30] = resumereq_q;
    dmcontrol_rdata[25:16] = hartsel_q[9:0];
    dmcontrol_rdata[15:6] = hartsel_q[19:10];
    dmcontrol_rdata[1] = ndmreset_q;
    dmcontrol_rdata[0] = dmactive_q;
  end

  // Single-hart any/all fields are identical. A nonzero hartsel reports a
  // non-existent hart, which OpenOCD uses while enumerating available harts.
  always_comb begin
    dmstatus_rdata = '0;
    dmstatus_rdata[7] = 1'b1;  // authenticated: no authentication block exists.
    dmstatus_rdata[3:0] = 4'd2; // version 2 denotes Debug Spec v0.13 behavior.
    if (dmactive_q) begin
      if (selected_hart_exists) begin
        dmstatus_rdata[19] = hart_havereset_i;
        dmstatus_rdata[18] = hart_havereset_i;
        dmstatus_rdata[17] = hart_resumeack_visible;
        dmstatus_rdata[16] = hart_resumeack_visible;
        dmstatus_rdata[11] = hart_running_i;
        dmstatus_rdata[10] = hart_running_i;
        dmstatus_rdata[9] = hart_halted_visible;
        dmstatus_rdata[8] = hart_halted_visible;
      end else begin
        dmstatus_rdata[15] = 1'b1;
        dmstatus_rdata[14] = 1'b1;
      end
    end
  end

  // Four words are advertised only after storage, postexec sequencing, and the
  // halted-core execution path are integrated and verified together.
  always_comb begin
    abstractcs_rdata = '0;
    abstractcs_rdata[28:24] = 5'(PROGBUF_WORD_COUNT);
    abstractcs_rdata[12] = abstract_busy_i;
    abstractcs_rdata[10:8] = cmderr_q;
    abstractcs_rdata[3:0] = 4'd2;
  end

  // Register read mux. hartinfo is zero because the initial hart integration
  // has no hart-local data window or debug scratch registers.
  always_comb begin
    read_data = '0;
    unique case (dmi.req_addr)
      DMI_ADDR_DATA0:      read_data = data0_q;
      DMI_ADDR_DATA1:      read_data = data1_q;
      DMI_ADDR_DMCONTROL:  read_data = dmcontrol_rdata;
      DMI_ADDR_DMSTATUS:   read_data = dmstatus_rdata;
      DMI_ADDR_HARTINFO:   read_data = 32'h0000_0000;
      DMI_ADDR_ABSTRACTCS: read_data = abstractcs_rdata;
      DMI_ADDR_COMMAND:    read_data = command_q;
      // Autoexec is not implemented; all fields are WARL-zero. Accepting the
      // register lets OpenOCD explicitly disable autoexec after discovering a
      // nonzero Program Buffer size without receiving a DMI transport error.
      DMI_ADDR_ABSTRACTAUTO: read_data = 32'h0000_0000;
      DMI_ADDR_PROGBUF0,
      DMI_ADDR_PROGBUF1,
      DMI_ADDR_PROGBUF2,
      DMI_ADDR_PROGBUF3:   read_data = progbuf_read_data;
      default:             read_data = 32'h0000_0000;
    endcase
  end

  // The verified storage leaf owns reset/clear/write priority and exposes both
  // indexed DMI readback and the full integrated-executor array view.
  debug_progbuf u_debug_progbuf (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .clear_i(progbuf_clear),
    .write_valid_i(progbuf_write_valid),
    .write_index_i(progbuf_index),
    .write_data_i(dmi.req_data),
    .read_index_i(progbuf_index),
    .read_data_o(progbuf_read_data),
    .words_o(progbuf_words_o)
  );

  // All architectural state and the DMI response slot update in this single
  // clock domain. Reset dominates; dmactive clear resets Debug Module state;
  // accepted DMI writes then apply address-specific side effects.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dmactive_q <= 1'b0;
      ndmreset_q <= 1'b0;
      haltreq_q <= 1'b0;
      resumereq_q <= 1'b0;
      hartsel_q <= '0;
      command_q <= '0;
      data0_q <= '0;
      data1_q <= '0;
      cmderr_q <= CMDERR_NONE;
      rsp_valid_q <= 1'b0;
      rsp_resp_q <= DMI_RESP_SUCCESS;
      rsp_data_q <= '0;
      ackhavereset_o <= 1'b0;
      command_valid_o <= 1'b0;
    end else begin
      // Pulse outputs default low and are asserted only by an accepted write.
      ackhavereset_o <= 1'b0;
      command_valid_o <= 1'b0;

      // Hart acknowledgement retires the level-sensitive resume request.
      if (hart_resumeack_i && selected_hart_exists) begin
        resumereq_q <= 1'b0;
      end

      // Executor updates are independent of DMI response backpressure, but an
      // inactive DM rejects stale completion signals from a prior session.
      if (dmactive_q && data0_we_i) begin
        data0_q <= data0_wdata_i;
      end
      if (dmactive_q && data1_we_i) begin
        data1_q <= data1_wdata_i;
      end
      if (dmactive_q && command_error_valid_i && (command_error_i != CMDERR_NONE) &&
          (cmderr_q == CMDERR_NONE)) begin
        cmderr_q <= command_error_i;
      end

      // Consuming the current response frees the one-entry response slot.
      if (rsp_valid_q && dmi.rsp_ready) begin
        rsp_valid_q <= 1'b0;
      end

      if (dmi.req_valid && dmi.req_ready) begin
        rsp_valid_q <= 1'b1;
        rsp_resp_q <= req_supported ? DMI_RESP_SUCCESS : DMI_RESP_FAILED;
        rsp_data_q <= (dmi.req_op == DMI_OP_READ) ? read_data : 32'h0000_0000;

        // Debug Spec busy protection applies to reads and writes of all
        // abstract payload registers. Reads still return their sampled data;
        // writes are suppressed by their address-specific logic below.
        if (req_supported && dmactive_q && abstract_busy_i &&
            req_abstract_payload &&
            ((dmi.req_op == DMI_OP_READ) || (dmi.req_op == DMI_OP_WRITE)) &&
            (cmderr_q == CMDERR_NONE)) begin
          cmderr_q <= CMDERR_BUSY;
        end

        if (req_supported && (dmi.req_op == DMI_OP_WRITE)) begin
          unique case (dmi.req_addr)
            DMI_ADDR_DMCONTROL: begin
              if (!dmi.req_data[0]) begin
                // Clearing dmactive resets all state except the DMI transport.
                dmactive_q <= 1'b0;
                ndmreset_q <= 1'b0;
                haltreq_q <= 1'b0;
                resumereq_q <= 1'b0;
                hartsel_q <= '0;
                command_q <= '0;
                data0_q <= '0;
                data1_q <= '0;
                cmderr_q <= CMDERR_NONE;
              end else if (!dmactive_q) begin
                // v0.13 activation writes ignore all fields except dmactive.
                dmactive_q <= 1'b1;
              end else begin
                haltreq_q <= dmi.req_data[31];
                if (dmi.req_data[31]) begin
                  // The Debug Spec gives a simultaneous halt request priority.
                  resumereq_q <= 1'b0;
                end else if (dmi.req_data[30]) begin
                  resumereq_q <= 1'b1;
                end
                if (dmi.req_data[28] && selected_hart_exists) begin
                  ackhavereset_o <= 1'b1;
                end
                hartsel_q <= {dmi.req_data[15:6], dmi.req_data[25:16]};
                ndmreset_q <= dmi.req_data[1];
              end
            end

            DMI_ADDR_DATA0: begin
              if (dmactive_q && !abstract_busy_i) begin
                data0_q <= dmi.req_data;
              end
            end

            DMI_ADDR_DATA1: begin
              if (dmactive_q && !abstract_busy_i) begin
                data1_q <= dmi.req_data;
              end
            end

            DMI_ADDR_PROGBUF0,
            DMI_ADDR_PROGBUF1,
            DMI_ADDR_PROGBUF2,
            DMI_ADDR_PROGBUF3: begin
              // debug_progbuf consumes accepted idle writes directly through
              // progbuf_write_valid; busy and inactive writes have no effect.
            end

            DMI_ADDR_ABSTRACTCS: begin
              // cmderr is write-one-to-clear; other abstractcs fields are RO.
              cmderr_q <= cmderr_q & ~dmi.req_data[10:8];
            end

            DMI_ADDR_COMMAND: begin
              if (dmactive_q) begin
                if (abstract_busy_i) begin
                  if (cmderr_q == CMDERR_NONE) cmderr_q <= CMDERR_BUSY;
                end else begin
                  command_q <= dmi.req_data;
                  command_valid_o <= 1'b1;
                end
              end
            end

            // Writes to defined read-only registers complete with no effect.
            default: begin
            end
          endcase
        end
      end
    end
  end
endmodule
