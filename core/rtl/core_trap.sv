`timescale 1ns/1ps

module core_trap (
  input  logic        valid_i,
  input  logic [31:0] pc_i,
  input  logic [31:0] instr_i,

  input  logic        instr_misaligned_i,
  input  logic [31:0] instr_fault_addr_i,
  input  logic        illegal_instr_i,
  input  logic        csr_illegal_i,
  input  logic        ecall_i,
  input  logic        ebreak_i,
  input  logic        load_i,
  input  logic        store_i,
  input  logic        lsu_misaligned_i,
  input  logic [31:0] lsu_fault_addr_i,
  input  logic        mret_i,

  input  logic        mie_global_i,
  input  logic        mtie_i,
  input  logic        meie_i,
  input  logic        mtip_i,
  input  logic        meip_i,
  input  logic [31:0] mtvec_i,
  input  logic [31:0] mepc_i,

  output logic        trap_valid_o,
  output logic        trap_interrupt_o,
  output logic [4:0]  trap_cause_o,
  output logic [31:0] trap_tval_o,
  output logic [31:0] trap_pc_o,
  output logic        mret_taken_o,
  output logic        redirect_valid_o,
  output logic [31:0] redirect_pc_o
);
  import wasp1_pkg::*;

  logic timer_irq_enabled;
  logic external_irq_enabled;
  logic sync_trap;

  assign timer_irq_enabled = mie_global_i && mtie_i && mtip_i;
  assign external_irq_enabled = mie_global_i && meie_i && meip_i;

  always_comb begin
    trap_valid_o = 1'b0;
    trap_interrupt_o = 1'b0;
    trap_cause_o = TRAP_CAUSE_ILLEGAL_INSN;
    trap_tval_o = 32'h0000_0000;
    trap_pc_o = pc_i;
    mret_taken_o = 1'b0;
    redirect_valid_o = 1'b0;
    redirect_pc_o = mtvec_i;
    sync_trap = 1'b0;

    if (valid_i) begin
      if (instr_misaligned_i) begin
        sync_trap = 1'b1;
        trap_valid_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_IADDR_MISALIGNED;
        trap_tval_o = instr_fault_addr_i;
      end else if (illegal_instr_i || csr_illegal_i) begin
        sync_trap = 1'b1;
        trap_valid_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_ILLEGAL_INSN;
        trap_tval_o = instr_i;
      end else if (ebreak_i) begin
        sync_trap = 1'b1;
        trap_valid_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_BREAKPOINT;
        trap_tval_o = pc_i;
      end else if (ecall_i) begin
        sync_trap = 1'b1;
        trap_valid_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_ECALL_MMODE;
        trap_tval_o = 32'h0000_0000;
      end else if (lsu_misaligned_i && load_i) begin
        sync_trap = 1'b1;
        trap_valid_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_LOAD_MISALIGNED;
        trap_tval_o = lsu_fault_addr_i;
      end else if (lsu_misaligned_i && store_i) begin
        sync_trap = 1'b1;
        trap_valid_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_STORE_MISALIGNED;
        trap_tval_o = lsu_fault_addr_i;
      end

      if (sync_trap) begin
        redirect_valid_o = 1'b1;
        redirect_pc_o = mtvec_i;
      end else if (mret_i) begin
        mret_taken_o = 1'b1;
        redirect_valid_o = 1'b1;
        redirect_pc_o = mepc_i;
      end else if (external_irq_enabled) begin
        trap_valid_o = 1'b1;
        trap_interrupt_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_M_EXTERNAL_IRQ;
        trap_tval_o = 32'h0000_0000;
        redirect_valid_o = 1'b1;
        redirect_pc_o = mtvec_i;
      end else if (timer_irq_enabled) begin
        trap_valid_o = 1'b1;
        trap_interrupt_o = 1'b1;
        trap_cause_o = TRAP_CAUSE_M_TIMER_IRQ;
        trap_tval_o = 32'h0000_0000;
        redirect_valid_o = 1'b1;
        redirect_pc_o = mtvec_i;
      end
    end
  end
endmodule
