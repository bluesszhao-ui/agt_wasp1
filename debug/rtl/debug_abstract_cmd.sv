`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Decoder and controller for RV32 GPR/CSR Access Register commands plus a
// minimal physical Access Memory command path through the halted core.
module debug_abstract_cmd (
  input  logic        clk_i,                 // Debug command clock.
  input  logic        rst_ni,                // Asynchronous active-low command reset.
  input  logic        dmactive_i,            // Debug Module activation state.
  input  logic        hart_halted_i,         // Selected hart must be halted for access.
  input  logic        command_valid_i,       // One-cycle pulse for a newly accepted command.
  input  logic [31:0] command_i,             // Raw v0.13.x abstract command register value.
  input  logic [31:0] data0_i,               // Current abstract data0 write payload.
  input  logic [31:0] data1_i,               // Current abstract data1 address payload.
  input  logic [31:0] hart_dpc_i,            // Core-captured Debug PC returned for CSR dpc reads.
  input  logic [2:0]  hart_dcsr_cause_i,     // Core-reported DCSR cause for the current halt.
  output logic        busy_o,                // Abstract command is decoding or executing.
  output logic        command_error_valid_o, // One-cycle pulse for a nonzero cmderr result.
  output logic [2:0]  command_error_o,       // cmderr encoding from debug_dmi_pkg.
  output logic        data0_we_o,            // One-cycle successful-read update for data0.
  output logic [31:0] data0_wdata_o,         // Successful GPR/memory read result.
  output logic        data1_we_o,            // One-cycle Access Memory postincrement update for data1.
  output logic [31:0] data1_wdata_o,         // Postincremented Access Memory address.
  output logic        reg_cmd_valid_o,       // Decoded command request to debug_reg_access.
  input  logic        reg_cmd_ready_i,       // Register-access sequencer accepts the command.
  output logic        reg_cmd_write_o,       // One selects GPR write; zero selects read.
  output logic [4:0]  reg_cmd_addr_o,        // Decoded x0-x31 register index.
  output logic [31:0] reg_cmd_wdata_o,       // GPR write payload captured from data0.
  input  logic        reg_rsp_valid_i,       // Register-access result is available.
  output logic        reg_rsp_ready_o,       // Abstract controller accepts the result.
  input  logic [31:0] reg_rsp_rdata_i,       // Successful GPR read data.
  input  logic        reg_rsp_error_i,       // Register-access sequencer/core reported error.
  output logic        mem_cmd_valid_o,       // Decoded Access Memory request to the halted core.
  input  logic        mem_cmd_ready_i,       // Halted core accepted the memory request.
  output logic        mem_cmd_write_o,       // One selects memory write; zero selects read.
  output logic [31:0] mem_cmd_addr_o,        // Memory byte address from data1.
  output logic [1:0]  mem_cmd_size_o,        // Byte/half/word memory size.
  output logic [31:0] mem_cmd_wdata_o,       // Lane-aligned memory write data.
  output logic [3:0]  mem_cmd_wstrb_o,       // Memory write byte strobes.
  input  logic        mem_rsp_valid_i,       // Memory response is available.
  output logic        mem_rsp_ready_o,       // Abstract controller accepts the memory result.
  input  logic [31:0] mem_rsp_rdata_i,       // Raw 32-bit memory read data.
  input  logic        mem_rsp_error_i,       // Memory path reported access/bus error.
  output logic        dcsr_step_o,           // Latched DCSR.step bit used by resume single-step.
  output logic        trigger_execute_valid_o,// Execute-address trigger enable toward the core.
  output logic [31:0] trigger_execute_addr_o,// Execute-address trigger compare value.
  output logic        reg_flush_o,           // Abort/drain downstream GPR work on DM/hart loss.
  output logic        mem_flush_o            // Abort/drain downstream memory work on DM/hart loss.
);
  import debug_dmi_pkg::*;
  import wasp1_pkg::*;

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
  logic        command_mem_type;
  logic        command_mem_virtual;
  logic [2:0]  command_mem_size;
  logic        command_mem_postincrement;
  logic        command_mem_write;
  logic        command_gpr_supported;
  logic        command_csr_read_supported;
  logic        command_csr_write_supported;
  logic        command_csr_supported;
  logic        command_transfer_supported;
  logic        command_access_reg_supported;
  logic        command_access_mem_supported;
  logic        command_encoding_supported;
  logic [31:0] command_csr_rdata;
  logic [31:0] command_csr_warl_tdata1;
  logic [1:0]  command_mem_size2;
  logic [31:0] command_mem_wdata;
  logic [3:0]  command_mem_wstrb;
  logic [31:0] command_mem_rdata;
  logic [31:0] command_mem_next_addr;

  // Captured downstream command fields and completion result.
  logic        op_is_reg_q;
  logic        op_is_mem_q;
  logic        reg_write_q;
  logic [4:0]  reg_addr_q;
  logic [31:0] reg_wdata_q;
  logic        mem_write_q;
  logic [31:0] mem_addr_q;
  logic [1:0]  mem_size_q;
  logic [31:0] mem_wdata_q;
  logic [3:0]  mem_wstrb_q;
  logic        mem_postincrement_q;
  logic        read_result_valid_q;
  logic [31:0] read_result_q;
  logic        data1_update_valid_q;
  logic [31:0] data1_update_q;
  logic [2:0]  completion_error_q;
  logic        dcsr_step_q;
  logic [31:0] trigger_tdata1_q;
  logic [31:0] trigger_tdata2_q;

  logic reg_cmd_fire;
  logic reg_rsp_fire;
  logic mem_cmd_fire;
  logic mem_rsp_fire;

  assign command_type = command_i[31:24];
  assign command_reserved_bit = command_i[23];
  assign command_aarsize = command_i[22:20];
  assign command_postincrement = command_i[19];
  assign command_postexec = command_i[18];
  assign command_transfer = command_i[17];
  assign command_write = command_i[16];
  assign command_regno = command_i[15:0];
  assign command_mem_type = (command_type == ABSTRACT_CMD_ACCESS_MEMORY);
  assign command_mem_virtual = command_i[23];
  assign command_mem_size = command_i[22:20];
  assign command_mem_postincrement = command_i[19];
  assign command_mem_write = command_i[16];

  // The first implementation accepts RV32 integer registers plus local
  // debugger probe CSRs. When transfer=0, size/regno/write are ignored and the
  // command is a successful no-op.
  assign command_gpr_supported = (command_regno >= ABSTRACT_GPR_BASE) &&
                                 (command_regno <= ABSTRACT_GPR_LAST);
  assign command_csr_read_supported =
      (command_type == ABSTRACT_CMD_ACCESS_REGISTER) &&
      (command_regno < ABSTRACT_GPR_BASE) && !command_write;
  assign command_csr_write_supported =
      (command_type == ABSTRACT_CMD_ACCESS_REGISTER) &&
      (command_regno < ABSTRACT_GPR_BASE) && command_write;
  assign command_csr_supported = command_csr_read_supported ||
                                 command_csr_write_supported;
  assign command_transfer_supported = command_gpr_supported ||
                                      command_csr_supported;
  assign command_access_reg_supported =
      (command_type == ABSTRACT_CMD_ACCESS_REGISTER) &&
      !command_reserved_bit && !command_postincrement && !command_postexec &&
      (!command_transfer ||
       ((command_aarsize == ABSTRACT_AARSIZE_32) && command_transfer_supported));
  assign command_access_mem_supported =
      command_mem_type && !command_mem_virtual &&
      ((command_mem_size == ABSTRACT_AAMSIZE_8) ||
       (command_mem_size == ABSTRACT_AAMSIZE_16) ||
       (command_mem_size == ABSTRACT_AAMSIZE_32));
  assign command_encoding_supported = command_access_reg_supported ||
                                      command_access_mem_supported;

  // CSR values cover debugger discovery. dpc is captured by the core when it
  // enters Debug Mode, so GDB sees the real resume PC instead of a reset stub.
  always_comb begin
    unique case (command_regno)
      ABSTRACT_CSR_MSTATUS: command_csr_rdata = ABSTRACT_CSR_MSTATUS_RV32_M;
      ABSTRACT_CSR_MISA: command_csr_rdata = ABSTRACT_CSR_MISA_RV32I;
      ABSTRACT_CSR_TSELECT: command_csr_rdata = 32'h0000_0000;
      ABSTRACT_CSR_TDATA1: command_csr_rdata = trigger_tdata1_q;
      ABSTRACT_CSR_TDATA2: command_csr_rdata = trigger_tdata2_q;
      ABSTRACT_CSR_TDATA3: command_csr_rdata = 32'h0000_0000;
      ABSTRACT_CSR_TINFO: command_csr_rdata = ABSTRACT_TINFO_MCONTROL_ONLY;
      ABSTRACT_CSR_TCONTROL: command_csr_rdata = 32'h0000_0000;
      ABSTRACT_CSR_DCSR: command_csr_rdata =
          ABSTRACT_CSR_DCSR_BASE_RV32_M |
          ({29'h0000_0000, hart_dcsr_cause_i} << 6) |
          (dcsr_step_q ? ABSTRACT_CSR_DCSR_STEP_MASK : 32'h0000_0000);
      ABSTRACT_CSR_DPC:  command_csr_rdata = hart_dpc_i;
      // OpenOCD probes several optional CSRs. Returning zero for unimplemented
      // read-only probes keeps abstract CSR access enabled without changing the
      // programmer-visible core CSR behavior.
      default:           command_csr_rdata = '0;
    endcase
  end

  // The single trigger is an RV32 mcontrol execute-address trigger. Unsupported
  // fields are WARL-zeroed, action accepts only Debug Mode, and unsupported
  // type writes fall back to a disabled mcontrol image so one trigger remains
  // discoverable through tdata1/tinfo.
  always_comb begin
    command_csr_warl_tdata1 =
        ABSTRACT_TDATA1_TYPE_MCONTROL |
        (data0_i & (ABSTRACT_TDATA1_DMODE |
                    ABSTRACT_MCONTROL_ACTION_MASK |
                    ABSTRACT_MCONTROL_MATCH_MASK |
                    ABSTRACT_MCONTROL_M |
                    ABSTRACT_MCONTROL_EXECUTE));

    if ((data0_i & ABSTRACT_TDATA1_TYPE_MASK) != ABSTRACT_TDATA1_TYPE_MCONTROL) begin
      command_csr_warl_tdata1 = ABSTRACT_TDATA1_TYPE_MCONTROL;
    end

    if ((data0_i & ABSTRACT_MCONTROL_ACTION_MASK) != ABSTRACT_MCONTROL_ACTION_DEBUG) begin
      command_csr_warl_tdata1 &= ~ABSTRACT_MCONTROL_ACTION_MASK;
    end
  end

  always_comb begin
    unique case (command_mem_size)
      ABSTRACT_AAMSIZE_8:  command_mem_size2 = wasp1_pkg::MEM_SIZE_BYTE;
      ABSTRACT_AAMSIZE_16: command_mem_size2 = wasp1_pkg::MEM_SIZE_HALF;
      default:             command_mem_size2 = wasp1_pkg::MEM_SIZE_WORD;
    endcase

    command_mem_wdata = data0_i;
    command_mem_wstrb = 4'b1111;
    unique case (command_mem_size)
      ABSTRACT_AAMSIZE_8: begin
        command_mem_wdata = data0_i << (8 * data1_i[1:0]);
        command_mem_wstrb = 4'b0001 << data1_i[1:0];
      end
      ABSTRACT_AAMSIZE_16: begin
        command_mem_wdata = data1_i[1] ? {data0_i[15:0], 16'h0000} :
                                         {16'h0000, data0_i[15:0]};
        command_mem_wstrb = data1_i[1] ? 4'b1100 : 4'b0011;
      end
      default: begin
        command_mem_wdata = data0_i;
        command_mem_wstrb = 4'b1111;
      end
    endcase

    unique case (mem_size_q)
      wasp1_pkg::MEM_SIZE_BYTE: begin
        unique case (mem_addr_q[1:0])
          2'd0: command_mem_rdata = {24'h000000, mem_rsp_rdata_i[7:0]};
          2'd1: command_mem_rdata = {24'h000000, mem_rsp_rdata_i[15:8]};
          2'd2: command_mem_rdata = {24'h000000, mem_rsp_rdata_i[23:16]};
          default: command_mem_rdata = {24'h000000, mem_rsp_rdata_i[31:24]};
        endcase
        command_mem_next_addr = mem_addr_q + 32'd1;
      end
      wasp1_pkg::MEM_SIZE_HALF: begin
        command_mem_rdata = mem_addr_q[1] ? {16'h0000, mem_rsp_rdata_i[31:16]} :
                                             {16'h0000, mem_rsp_rdata_i[15:0]};
        command_mem_next_addr = mem_addr_q + 32'd2;
      end
      default: begin
        command_mem_rdata = mem_rsp_rdata_i;
        command_mem_next_addr = mem_addr_q + 32'd4;
      end
    endcase
  end

  assign reg_cmd_fire = reg_cmd_valid_o && reg_cmd_ready_i;
  assign reg_rsp_fire = reg_rsp_valid_i && reg_rsp_ready_o;
  assign mem_cmd_fire = mem_cmd_valid_o && mem_cmd_ready_i;
  assign mem_rsp_fire = mem_rsp_valid_i && mem_rsp_ready_o;

  // Busy spans decode, issue, wait, and one completion-report cycle.
  assign busy_o = (state_q != ABSTRACT_IDLE);
  assign reg_cmd_valid_o = (state_q == ABSTRACT_ISSUE) && op_is_reg_q &&
                           dmactive_i && hart_halted_i;
  assign reg_cmd_write_o = reg_write_q;
  assign reg_cmd_addr_o = reg_addr_q;
  assign reg_cmd_wdata_o = reg_wdata_q;
  assign reg_rsp_ready_o = (state_q == ABSTRACT_WAIT) && op_is_reg_q;
  assign mem_cmd_valid_o = (state_q == ABSTRACT_ISSUE) && op_is_mem_q &&
                           dmactive_i && hart_halted_i;
  assign mem_cmd_write_o = mem_write_q;
  assign mem_cmd_addr_o = mem_addr_q;
  assign mem_cmd_size_o = mem_size_q;
  assign mem_cmd_wdata_o = mem_wdata_q;
  assign mem_cmd_wstrb_o = mem_wstrb_q;
  assign mem_rsp_ready_o = (state_q == ABSTRACT_WAIT) && op_is_mem_q;
  assign dcsr_step_o = dcsr_step_q;
  assign trigger_execute_valid_o =
      ((trigger_tdata1_q & ABSTRACT_TDATA1_TYPE_MASK) ==
       ABSTRACT_TDATA1_TYPE_MCONTROL) &&
      ((trigger_tdata1_q & ABSTRACT_MCONTROL_ACTION_MASK) ==
       ABSTRACT_MCONTROL_ACTION_DEBUG) &&
      ((trigger_tdata1_q & ABSTRACT_MCONTROL_MATCH_MASK) == 32'h0000_0000) &&
      ((trigger_tdata1_q & ABSTRACT_MCONTROL_M) != 32'h0000_0000) &&
      ((trigger_tdata1_q & ABSTRACT_MCONTROL_EXECUTE) != 32'h0000_0000);
  assign trigger_execute_addr_o = trigger_tdata2_q;

  // Losing DM activation or halted state aborts the downstream transaction.
  assign reg_flush_o = !dmactive_i ||
                       (op_is_reg_q && (((state_q == ABSTRACT_ISSUE) ||
                         (state_q == ABSTRACT_WAIT)) && !hart_halted_i));
  assign mem_flush_o = !dmactive_i ||
                       (op_is_mem_q && (((state_q == ABSTRACT_ISSUE) ||
                         (state_q == ABSTRACT_WAIT)) && !hart_halted_i));

  // Completion outputs are driven from registered results, so they remain
  // independent of downstream combinational timing.
  assign command_error_valid_o = (state_q == ABSTRACT_COMPLETE) &&
                                 (completion_error_q != CMDERR_NONE);
  assign command_error_o = completion_error_q;
  assign data0_we_o = (state_q == ABSTRACT_COMPLETE) && read_result_valid_q &&
                      (completion_error_q == CMDERR_NONE);
  assign data0_wdata_o = read_result_q;
  assign data1_we_o = (state_q == ABSTRACT_COMPLETE) && data1_update_valid_q &&
                      (completion_error_q == CMDERR_NONE);
  assign data1_wdata_o = data1_update_q;

  // Protocol state transitions. command_valid_i is expected only while idle;
  // debug_dmi_regs rejects command writes while busy.
  always_comb begin
    state_d = state_q;
    unique case (state_q)
      ABSTRACT_IDLE: begin
        if (command_valid_i && dmactive_i) begin
          if (!command_encoding_supported || !hart_halted_i ||
              ((command_type == ABSTRACT_CMD_ACCESS_REGISTER) && !command_transfer) ||
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
        end else if (reg_cmd_fire || mem_cmd_fire) begin
          state_d = ABSTRACT_WAIT;
        end
      end

      ABSTRACT_WAIT: begin
        if (!dmactive_i) begin
          state_d = ABSTRACT_IDLE;
        end else if (!hart_halted_i) begin
          state_d = ABSTRACT_COMPLETE;
        end else if (reg_rsp_fire || mem_rsp_fire) begin
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
      op_is_reg_q <= 1'b0;
      op_is_mem_q <= 1'b0;
      reg_write_q <= 1'b0;
      reg_addr_q <= '0;
      reg_wdata_q <= '0;
      mem_write_q <= 1'b0;
      mem_addr_q <= '0;
      mem_size_q <= '0;
      mem_wdata_q <= '0;
      mem_wstrb_q <= '0;
      mem_postincrement_q <= 1'b0;
      read_result_valid_q <= 1'b0;
      read_result_q <= '0;
      data1_update_valid_q <= 1'b0;
      data1_update_q <= '0;
      completion_error_q <= CMDERR_NONE;
      dcsr_step_q <= 1'b0;
      trigger_tdata1_q <= ABSTRACT_TDATA1_TYPE_MCONTROL;
      trigger_tdata2_q <= 32'h0000_0000;
    end else begin
      state_q <= state_d;

      if (!dmactive_i) begin
        read_result_valid_q <= 1'b0;
        data1_update_valid_q <= 1'b0;
        completion_error_q <= CMDERR_NONE;
        dcsr_step_q <= 1'b0;
        trigger_tdata1_q <= ABSTRACT_TDATA1_TYPE_MCONTROL;
        trigger_tdata2_q <= 32'h0000_0000;
      end else if ((state_q == ABSTRACT_IDLE) && command_valid_i) begin
        op_is_reg_q <= (command_type == ABSTRACT_CMD_ACCESS_REGISTER) &&
                       command_transfer && !command_csr_supported;
        op_is_mem_q <= command_mem_type && command_access_mem_supported;
        reg_write_q <= command_write;
        reg_addr_q <= command_regno[4:0];
        reg_wdata_q <= data0_i;
        mem_write_q <= command_mem_write;
        mem_addr_q <= data1_i;
        mem_size_q <= command_mem_size2;
        mem_wdata_q <= command_mem_wdata;
        mem_wstrb_q <= command_mem_wstrb;
        mem_postincrement_q <= command_mem_postincrement;
        read_result_valid_q <= 1'b0;
        read_result_q <= '0;
        data1_update_valid_q <= 1'b0;
        data1_update_q <= '0;

        if (!command_encoding_supported) begin
          completion_error_q <= CMDERR_NOTSUP;
        end else if (!hart_halted_i) begin
          completion_error_q <= CMDERR_HALT_RESUME;
        end else if (command_transfer && command_csr_supported) begin
          completion_error_q <= CMDERR_NONE;
          read_result_valid_q <= command_csr_read_supported;
          read_result_q <= command_csr_read_supported ? command_csr_rdata : '0;
          if (command_csr_write_supported &&
              (command_regno == ABSTRACT_CSR_DCSR)) begin
            dcsr_step_q <= (data0_i & ABSTRACT_CSR_DCSR_STEP_MASK) != 32'h0000_0000;
          end else if (command_csr_write_supported &&
                       (command_regno == ABSTRACT_CSR_TDATA1)) begin
            trigger_tdata1_q <= command_csr_warl_tdata1;
          end else if (command_csr_write_supported &&
                       (command_regno == ABSTRACT_CSR_TDATA2)) begin
            trigger_tdata2_q <= data0_i;
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
      end else if ((state_q == ABSTRACT_WAIT) && mem_rsp_fire) begin
        completion_error_q <= mem_rsp_error_i ? CMDERR_BUS : CMDERR_NONE;
        read_result_valid_q <= !mem_write_q && !mem_rsp_error_i;
        read_result_q <= command_mem_rdata;
        data1_update_valid_q <= mem_postincrement_q && !mem_rsp_error_i;
        data1_update_q <= command_mem_next_addr;
      end
    end
  end
endmodule
