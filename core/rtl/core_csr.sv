`timescale 1ns/1ps

// Machine-mode CSR file for the wasp1 core.
//
// This block implements the software-visible M-mode CSRs needed by the minimal
// RV32I + Zicsr core. It owns CSR instruction side effects, trap entry state,
// MRET state restoration, interrupt pending reflection, and cycle/instret
// counters.
module core_csr (
  input  logic                         clk_i,          // CSR state update clock.
  input  logic                         rst_ni,         // Active-low asynchronous reset.

  input  logic                         csr_valid_i,    // CSR instruction/access qualifier.
  input  core_types_pkg::core_csr_cmd_e csr_cmd_i,     // Zicsr RW/RS/RC command.
  input  logic [11:0]                  csr_addr_i,     // 12-bit CSR address.
  input  logic [31:0]                  csr_wdata_i,    // Source data or zero-extended zimm.
  output logic [31:0]                  csr_rdata_o,    // Old CSR value for rd writeback.
  output logic                         csr_illegal_o,  // Unsupported or read-only write access.

  input  logic                         retire_i,       // Retired instruction pulse for instret.

  input  logic                         trap_valid_i,   // Trap entry request from core_trap.
  input  logic                         trap_interrupt_i,// Trap cause is interrupt when asserted.
  input  logic [4:0]                   trap_cause_i,   // Trap cause without interrupt MSB.
  input  logic [31:0]                  trap_pc_i,      // PC captured into mepc.
  input  logic [31:0]                  trap_tval_i,    // Value captured into mtval.

  input  logic                         mret_i,         // MRET state restore pulse.

  input  logic                         timer_irq_i,    // Machine timer interrupt pending input.
  input  logic                         external_irq_i, // Machine external interrupt pending input.

  output logic [31:0]                  mtvec_o,        // Trap vector base for redirects.
  output logic [31:0]                  mepc_o,         // Exception PC for MRET redirect.
  output logic                         mie_global_o,   // mstatus.MIE global interrupt enable.
  output logic                         mtie_o,         // mie.MTIE timer interrupt enable.
  output logic                         meie_o,         // mie.MEIE external interrupt enable.
  output logic                         mtip_o,         // mip.MTIP reflected pending bit.
  output logic                         meip_o          // mip.MEIP reflected pending bit.
);
  import core_types_pkg::*;
  import wasp1_pkg::*;

  localparam int MSTATUS_MIE_BIT  = 3;  // Machine interrupt enable bit in mstatus.
  localparam int MSTATUS_MPIE_BIT = 7;  // Previous MIE bit saved on trap entry.
  localparam int MSTATUS_MPP_LSB  = 11; // Machine previous privilege field LSB.
  localparam int MIE_MTIE_BIT     = 7;  // Machine timer interrupt enable bit.
  localparam int MIE_MEIE_BIT     = 11; // Machine external interrupt enable bit.
  localparam int MIP_MTIP_BIT     = 7;  // Machine timer interrupt pending bit.
  localparam int MIP_MEIP_BIT     = 11; // Machine external interrupt pending bit.

  logic [31:0] mstatus_q;  // Machine status CSR, masked to MIE/MPIE/MPP.
  logic [31:0] mie_q;      // Machine interrupt enable CSR, masked to MTIE/MEIE.
  logic [31:0] mtvec_q;    // Trap vector CSR, direct mode only.
  logic [31:0] mscratch_q; // Machine scratch CSR.
  logic [31:0] mepc_q;     // Machine exception PC CSR.
  logic [31:0] mcause_q;   // Machine cause CSR.
  logic [31:0] mtval_q;    // Machine trap value CSR.
  logic [63:0] cycle_q;    // 64-bit cycle counter exposed through cycle/cycleh.
  logic [63:0] instret_q;  // 64-bit retired instruction counter.

  logic [31:0] mip_read;        // Combinational read image of pending IRQ bits.
  logic [31:0] csr_read_data;   // Selected CSR read value.
  logic        csr_supported;   // Address decodes to an implemented CSR.
  logic        csr_read_only;   // Selected CSR cannot be written by CSR ops.
  logic [31:0] csr_write_data;  // Post-RW/RS/RC write value before masks.
  logic        csr_write_en;    // Final write enable after legality checks.

  assign mtvec_o = mtvec_q;
  assign mepc_o = mepc_q;
  assign mie_global_o = mstatus_q[MSTATUS_MIE_BIT];
  assign mtie_o = mie_q[MIE_MTIE_BIT];
  assign meie_o = mie_q[MIE_MEIE_BIT];
  assign mtip_o = timer_irq_i;
  assign meip_o = external_irq_i;

  // mip is not stored; it reflects live interrupt pending inputs.
  always_comb begin
    mip_read = 32'h0000_0000;
    mip_read[MIP_MTIP_BIT] = timer_irq_i;
    mip_read[MIP_MEIP_BIT] = external_irq_i;
  end

  // CSR read mux and access attributes. Unsupported addresses return zero and
  // flag illegal when csr_valid_i is asserted.
  always_comb begin
    csr_supported = 1'b1;
    csr_read_only = 1'b0;
    unique case (csr_addr_i)
      CSR_MSTATUS:  csr_read_data = mstatus_q;
      CSR_MIE:      csr_read_data = mie_q;
      CSR_MTVEC:    csr_read_data = mtvec_q;
      CSR_MSCRATCH: csr_read_data = mscratch_q;
      CSR_MEPC:     csr_read_data = mepc_q;
      CSR_MCAUSE:   csr_read_data = mcause_q;
      CSR_MTVAL:    csr_read_data = mtval_q;
      CSR_MIP: begin
        csr_read_data = mip_read;
        csr_read_only = 1'b1;
      end
      CSR_CYCLE: begin
        csr_read_data = cycle_q[31:0];
        csr_read_only = 1'b1;
      end
      CSR_CYCLEH: begin
        csr_read_data = cycle_q[63:32];
        csr_read_only = 1'b1;
      end
      CSR_INSTRET: begin
        csr_read_data = instret_q[31:0];
        csr_read_only = 1'b1;
      end
      CSR_INSTRETH: begin
        csr_read_data = instret_q[63:32];
        csr_read_only = 1'b1;
      end
      default: begin
        csr_read_data = 32'h0000_0000;
        csr_supported = 1'b0;
        csr_read_only = 1'b0;
      end
    endcase
  end

  // Compute the architectural Zicsr write value. Immediate CSR operations are
  // already expanded into csr_wdata_i by decode/execute.
  always_comb begin
    csr_write_data = csr_read_data;
    unique case (csr_cmd_i)
      CORE_CSR_RW,
      CORE_CSR_RWI: csr_write_data = csr_wdata_i;
      CORE_CSR_RS,
      CORE_CSR_RSI: csr_write_data = csr_read_data | csr_wdata_i;
      CORE_CSR_RC,
      CORE_CSR_RCI: csr_write_data = csr_read_data & ~csr_wdata_i;
      default:      csr_write_data = csr_read_data;
    endcase
  end

  // Writes are blocked for read-only CSRs and unsupported addresses. Reads to
  // read-only CSRs are legal when csr_cmd_i is CORE_CSR_NONE.
  assign csr_write_en = csr_valid_i && (csr_cmd_i != CORE_CSR_NONE) &&
                        csr_supported && !csr_read_only;
  assign csr_illegal_o = csr_valid_i &&
                         (!csr_supported ||
                          (csr_read_only && (csr_cmd_i != CORE_CSR_NONE)));
  assign csr_rdata_o = csr_read_data;

  // Preserve only supported mstatus fields. MPP is hardwired to machine mode
  // because wasp1 currently has only M-mode.
  function automatic logic [31:0] mask_mstatus(input logic [31:0] value);
    begin
      mask_mstatus = 32'h0000_0000;
      mask_mstatus[MSTATUS_MIE_BIT] = value[MSTATUS_MIE_BIT];
      mask_mstatus[MSTATUS_MPIE_BIT] = value[MSTATUS_MPIE_BIT];
      mask_mstatus[MSTATUS_MPP_LSB +: 2] = 2'b11;
    end
  endfunction

  // Keep only interrupt enables that have corresponding pending sources.
  function automatic logic [31:0] mask_mie(input logic [31:0] value);
    begin
      mask_mie = 32'h0000_0000;
      mask_mie[MIE_MTIE_BIT] = value[MIE_MTIE_BIT];
      mask_mie[MIE_MEIE_BIT] = value[MIE_MEIE_BIT];
    end
  endfunction

  // Force mtvec direct mode by clearing mode bits [1:0].
  function automatic logic [31:0] mask_mtvec(input logic [31:0] value);
    begin
      mask_mtvec = {value[31:2], 2'b00};
    end
  endfunction

  // Sequential CSR state update. Normal CSR writes happen first; trap entry has
  // priority over MRET for deterministic behavior if both are asserted.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      mstatus_q <= 32'h0000_1800;
      mie_q <= 32'h0000_0000;
      mtvec_q <= 32'h0000_0000;
      mscratch_q <= 32'h0000_0000;
      mepc_q <= 32'h0000_0000;
      mcause_q <= 32'h0000_0000;
      mtval_q <= 32'h0000_0000;
      cycle_q <= 64'h0000_0000_0000_0000;
      instret_q <= 64'h0000_0000_0000_0000;
    end else begin
      // Counters are free-running except for reset. instret increments only
      // when the pipeline reports a retired instruction.
      cycle_q <= cycle_q + 64'd1;
      if (retire_i) begin
        instret_q <= instret_q + 64'd1;
      end

      // Commit legal CSR writes with per-CSR masks and alignment rules.
      if (csr_write_en) begin
        unique case (csr_addr_i)
          CSR_MSTATUS:  mstatus_q <= mask_mstatus(csr_write_data);
          CSR_MIE:      mie_q <= mask_mie(csr_write_data);
          CSR_MTVEC:    mtvec_q <= mask_mtvec(csr_write_data);
          CSR_MSCRATCH: mscratch_q <= csr_write_data;
          CSR_MEPC:     mepc_q <= {csr_write_data[31:1], 1'b0};
          CSR_MCAUSE:   mcause_q <= csr_write_data;
          CSR_MTVAL:    mtval_q <= csr_write_data;
          default: begin
          end
        endcase
      end

      // Trap entry saves interrupt state and captures trap metadata.
      if (trap_valid_i) begin
        mstatus_q[MSTATUS_MPIE_BIT] <= mstatus_q[MSTATUS_MIE_BIT];
        mstatus_q[MSTATUS_MIE_BIT] <= 1'b0;
        mstatus_q[MSTATUS_MPP_LSB +: 2] <= 2'b11;
        mepc_q <= {trap_pc_i[31:1], 1'b0};
        mcause_q <= {trap_interrupt_i, 26'h000_0000, trap_cause_i};
        mtval_q <= trap_tval_i;
      end else if (mret_i) begin
        // MRET restores global interrupt enable from MPIE and leaves MPP as
        // machine mode because no lower privilege modes are implemented.
        mstatus_q[MSTATUS_MIE_BIT] <= mstatus_q[MSTATUS_MPIE_BIT];
        mstatus_q[MSTATUS_MPIE_BIT] <= 1'b1;
        mstatus_q[MSTATUS_MPP_LSB +: 2] <= 2'b11;
      end
    end
  end
endmodule
