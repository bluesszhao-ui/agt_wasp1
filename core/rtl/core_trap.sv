`timescale 1ns/1ps

// Trap and redirect priority helper.
//
// This combinational block centralizes exception, MRET, and interrupt
// prioritization. It emits trap metadata for core_csr and a redirect target for
// the fetch/front-end path.
module core_trap (
  input  logic        valid_i,            // Current pipeline slot is valid.
  input  logic [31:0] pc_i,               // PC associated with this instruction slot.
  input  logic [31:0] instr_i,            // Instruction word used as illegal-instruction tval.

  input  logic        instr_misaligned_i,  // Fetch/branch target address was misaligned.
  input  logic [31:0] instr_fault_addr_i,  // Faulting instruction address target.
  input  logic        illegal_instr_i,     // Decode reported illegal instruction.
  input  logic        csr_illegal_i,       // CSR file reported illegal CSR access.
  input  logic        ecall_i,             // ECALL instruction qualifier.
  input  logic        ebreak_i,            // EBREAK instruction qualifier.
  input  logic        load_i,              // Current memory op is a load.
  input  logic        store_i,             // Current memory op is a store.
  input  logic        lsu_misaligned_i,    // LSU detected data address misalignment.
  input  logic [31:0] lsu_fault_addr_i,    // Faulting data address.
  input  logic        mret_i,              // MRET instruction qualifier.

  input  logic        mie_global_i,        // Global machine interrupt enable, mstatus.MIE.
  input  logic        mtie_i,              // Machine timer interrupt enable, mie.MTIE.
  input  logic        meie_i,              // Machine external interrupt enable, mie.MEIE.
  input  logic        mtip_i,              // Machine timer interrupt pending, mip.MTIP.
  input  logic        meip_i,              // Machine external interrupt pending, mip.MEIP.
  input  logic [31:0] mtvec_i,             // Trap vector base from CSR file.
  input  logic [31:0] mepc_i,              // MRET redirect PC from CSR file.

  output logic        trap_valid_o,        // Trap metadata is valid for core_csr.
  output logic        trap_interrupt_o,    // Trap is an interrupt, not synchronous exception.
  output logic [4:0]  trap_cause_o,        // Machine cause value without interrupt MSB.
  output logic [31:0] trap_tval_o,         // Trap value written to mtval.
  output logic [31:0] trap_pc_o,           // PC written to mepc on trap entry.
  output logic        mret_taken_o,        // MRET redirect selected.
  output logic        redirect_valid_o,    // Frontend redirect request.
  output logic [31:0] redirect_pc_o        // Redirect target, mtvec_i or mepc_i.
);
  import wasp1_pkg::*;

  logic timer_irq_enabled;    // Fully qualified timer interrupt request.
  logic external_irq_enabled; // Fully qualified external interrupt request.
  logic sync_trap;            // A synchronous exception was selected.

  assign timer_irq_enabled = mie_global_i && mtie_i && mtip_i;
  assign external_irq_enabled = mie_global_i && meie_i && meip_i;

  // Priority order:
  // 1. Synchronous traps from the current valid instruction.
  // 2. MRET redirect.
  // 3. Enabled external interrupt.
  // 4. Enabled timer interrupt.
  // 5. No redirect.
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
      // Synchronous exception priority is fixed so multiple asserted inputs
      // produce deterministic CSR state.
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

      // Once synchronous exceptions are resolved, choose redirect source.
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
