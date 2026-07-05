`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Decoder and controller for the RV32 GPR plus minimal CSR subset of Access
// Register commands.
module debug_abstract_cmd (
  input  logic        clk_i,                 // Debug command clock.
  input  logic        rst_ni,                // Asynchronous active-low command reset.
  input  logic        dmactive_i,            // Debug Module activation state.
  input  logic        hart_halted_i,         // Selected hart must be halted for access.
  input  logic        command_valid_i,       // One-cycle pulse for a newly accepted command.
  input  logic [31:0] command_i,             // Raw v0.13.x abstract command register value.
  input  logic [31:0] data0_i,               // Current abstract data0 write payload.
  input  logic [31:0] hart_dpc_i,            // Core-captured Debug PC returned for CSR dpc reads.
  output logic        busy_o,                // Abstract command is decoding or executing.
  output logic        command_error_valid_o, // One-cycle pulse for a nonzero cmderr result.
  output logic [2:0]  command_error_o,       // cmderr encoding from debug_dmi_pkg.
  output logic        data0_we_o,            // One-cycle successful-read update for data0.
  output logic [31:0] data0_wdata_o,         // Successful GPR read result.
  output logic        reg_cmd_valid_o,       // Decoded command request to debug_reg_access.
  input  logic        reg_cmd_ready_i,       // Register-access sequencer accepts the command.
  output logic        reg_cmd_write_o,       // One selects GPR write; zero selects read.
  output logic [4:0]  reg_cmd_addr_o,        // Decoded x0-x31 register index.
  output logic [31:0] reg_cmd_wdata_o,       // GPR write payload captured from data0.
  input  logic        reg_rsp_valid_i,       // Register-access result is available.
  output logic        reg_rsp_ready_o,       // Abstract controller accepts the result.
  input  logic [31:0] reg_rsp_rdata_i,       // Successful GPR read data.
  input  logic        reg_rsp_error_i,       // Register-access sequencer/core reported error.
  output logic        dcsr_step_o,           // Latched DCSR.step bit used by resume single-step.
  output logic        reg_flush_o            // Abort/drain downstream work on DM/hart loss.
);
  import debug_dmi_pkg::*;

  // COMPLETE produces registered side-effect pulses for exactly one cycle.
  typedef enum logic [2:0] {
    ABSTRACT_IDLE,
    ABSTRACT_ISSUE,
    ABSTRACT_WAIT,
    ABSTRACT_COMPLETE
  } abstract_state_e;

  abstract_state_e state_q;
  abstract_state_e state_d;

  // Raw command field decode is combinational and contains no protocol state.
  logic [7:0]  command_type;
  logic        command_reserved_bit;
  logic [2:0]  command_aarsize;
  logic        command_postincrement;
  logic        command_postexec;
  logic        command_transfer;
  logic        command_write;
  logic [15:0] command_regno;
  logic        command_gpr_supported;
  logic        command_csr_read_supported;
  logic        command_csr_write_supported;
  logic        command_csr_supported;
  logic        command_transfer_supported;
  logic        command_encoding_supported;
  logic [31:0] command_csr_rdata;

  // Captured downstream command fields and completion result.
  logic        reg_write_q;
  logic [4:0]  reg_addr_q;
  logic [31:0] reg_wdata_q;
  logic        read_result_valid_q;
  logic [31:0] read_result_q;
  logic [2:0]  completion_error_q;
  logic        dcsr_step_q;

  logic reg_cmd_fire;
  logic reg_rsp_fire;

  assign command_type = command_i[31:24];
  assign command_reserved_bit = command_i[23];
  assign command_aarsize = command_i[22:20];
  assign command_postincrement = command_i[19];
  assign command_postexec = command_i[18];
  assign command_transfer = command_i[17];
  assign command_write = command_i[16];
  assign command_regno = command_i[15:0];

  // The first implementation accepts RV32 integer registers plus local
  // debugger probe CSRs. When transfer=0, size/regno/write are ignored and the
  // command is a successful no-op.
  assign command_gpr_supported = (command_regno >= ABSTRACT_GPR_BASE) &&
                                 (command_regno <= ABSTRACT_GPR_LAST);
  assign command_csr_read_supported =
      ((command_regno == ABSTRACT_CSR_MISA) ||
       (command_regno == ABSTRACT_CSR_DCSR) ||
       (command_regno == ABSTRACT_CSR_DPC)) && !command_write;
  assign command_csr_write_supported =
      (command_regno == ABSTRACT_CSR_DCSR) && command_write;
  assign command_csr_supported = command_csr_read_supported ||
                                 command_csr_write_supported;
  assign command_transfer_supported = command_gpr_supported ||
                                      command_csr_supported;
  assign command_encoding_supported =
      (command_type == ABSTRACT_CMD_ACCESS_REGISTER) &&
      !command_reserved_bit && !command_postincrement && !command_postexec &&
      (!command_transfer ||
       ((command_aarsize == ABSTRACT_AARSIZE_32) && command_transfer_supported));

  // CSR values cover debugger discovery. dpc is captured by the core when it
  // enters Debug Mode, so GDB sees the real resume PC instead of a reset stub.
  always_comb begin
    unique case (command_regno)
      ABSTRACT_CSR_MISA: command_csr_rdata = ABSTRACT_CSR_MISA_RV32I;
      ABSTRACT_CSR_DCSR: command_csr_rdata =
          ABSTRACT_CSR_DCSR_HALTED_M |
          (dcsr_step_q ? ABSTRACT_CSR_DCSR_STEP_MASK : 32'h0000_0000);
      ABSTRACT_CSR_DPC:  command_csr_rdata = hart_dpc_i;
      default:           command_csr_rdata = '0;
    endcase
  end

  assign reg_cmd_fire = reg_cmd_valid_o && reg_cmd_ready_i;
  assign reg_rsp_fire = reg_rsp_valid_i && reg_rsp_ready_o;

  // Busy spans decode, issue, wait, and one completion-report cycle.
  assign busy_o = (state_q != ABSTRACT_IDLE);
  assign reg_cmd_valid_o = (state_q == ABSTRACT_ISSUE) && dmactive_i && hart_halted_i;
  assign reg_cmd_write_o = reg_write_q;
  assign reg_cmd_addr_o = reg_addr_q;
  assign reg_cmd_wdata_o = reg_wdata_q;
  assign reg_rsp_ready_o = (state_q == ABSTRACT_WAIT);
  assign dcsr_step_o = dcsr_step_q;

  // Losing DM activation or halted state aborts the downstream transaction.
  assign reg_flush_o = !dmactive_i ||
                       (((state_q == ABSTRACT_ISSUE) ||
                         (state_q == ABSTRACT_WAIT)) && !hart_halted_i);

  // Completion outputs are driven from registered results, so they remain
  // independent of downstream combinational timing.
  assign command_error_valid_o = (state_q == ABSTRACT_COMPLETE) &&
                                 (completion_error_q != CMDERR_NONE);
  assign command_error_o = completion_error_q;
  assign data0_we_o = (state_q == ABSTRACT_COMPLETE) && read_result_valid_q &&
                      (completion_error_q == CMDERR_NONE);
  assign data0_wdata_o = read_result_q;

  // Protocol state transitions. command_valid_i is expected only while idle;
  // debug_dmi_regs rejects command writes while busy.
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      ABSTRACT_IDLE: begin
        if (command_valid_i && dmactive_i) begin
          if (!command_encoding_supported || !hart_halted_i || !command_transfer ||
              command_csr_supported) begin
            state_d = ABSTRACT_COMPLETE;
          end else begin
            state_d = ABSTRACT_ISSUE;
          end
        end
      end

      ABSTRACT_ISSUE: begin
        if (!dmactive_i) begin
          state_d = ABSTRACT_IDLE;
        end else if (!hart_halted_i) begin
          state_d = ABSTRACT_COMPLETE;
        end else if (reg_cmd_fire) begin
          state_d = ABSTRACT_WAIT;
        end
      end

      ABSTRACT_WAIT: begin
        if (!dmactive_i) begin
          state_d = ABSTRACT_IDLE;
        end else if (!hart_halted_i) begin
          state_d = ABSTRACT_COMPLETE;
        end else if (reg_rsp_fire) begin
          state_d = ABSTRACT_COMPLETE;
        end
      end

      ABSTRACT_COMPLETE: state_d = ABSTRACT_IDLE;

      default: state_d = ABSTRACT_IDLE;
    endcase
  end

  // Capture decoded requests and completion results. Runtime priority is reset,
  // DM deactivation, new command decode, hart-state abort, then normal response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= ABSTRACT_IDLE;
      reg_write_q <= 1'b0;
      reg_addr_q <= '0;
      reg_wdata_q <= '0;
      read_result_valid_q <= 1'b0;
      read_result_q <= '0;
      completion_error_q <= CMDERR_NONE;
      dcsr_step_q <= 1'b0;
    end else begin
      state_q <= state_d;

      if (!dmactive_i) begin
        read_result_valid_q <= 1'b0;
        completion_error_q <= CMDERR_NONE;
        dcsr_step_q <= 1'b0;
      end else if ((state_q == ABSTRACT_IDLE) && command_valid_i) begin
        reg_write_q <= command_write;
        reg_addr_q <= command_regno[4:0];
        reg_wdata_q <= data0_i;
        read_result_valid_q <= 1'b0;
        read_result_q <= '0;

        if (!command_encoding_supported) begin
          completion_error_q <= CMDERR_NOTSUP;
        end else if (!hart_halted_i) begin
          completion_error_q <= CMDERR_HALT_RESUME;
        end else if (command_transfer && command_csr_supported) begin
          completion_error_q <= CMDERR_NONE;
          read_result_valid_q <= command_csr_read_supported;
          read_result_q <= command_csr_read_supported ? command_csr_rdata : '0;
          if (command_csr_write_supported) begin
            dcsr_step_q <= (data0_i & ABSTRACT_CSR_DCSR_STEP_MASK) != 32'h0000_0000;
          end
        end else begin
          completion_error_q <= CMDERR_NONE;
        end
      end else if (((state_q == ABSTRACT_ISSUE) ||
                    (state_q == ABSTRACT_WAIT)) && !hart_halted_i) begin
        read_result_valid_q <= 1'b0;
        completion_error_q <= CMDERR_HALT_RESUME;
      end else if ((state_q == ABSTRACT_WAIT) && reg_rsp_fire) begin
        completion_error_q <= reg_rsp_error_i ? CMDERR_EXCEPTION : CMDERR_NONE;
        read_result_valid_q <= !reg_write_q && !reg_rsp_error_i;
        read_result_q <= reg_rsp_rdata_i;
      end
    end
  end
endmodule
