`timescale 1ns/1ps

module tb_core_trap;
  import wasp1_pkg::*;

  logic valid;
  logic [31:0] pc;
  logic [31:0] instr;
  logic instr_misaligned;
  logic [31:0] instr_fault_addr;
  logic illegal_instr;
  logic csr_illegal;
  logic ecall;
  logic ebreak;
  logic load;
  logic store;
  logic lsu_misaligned;
  logic [31:0] lsu_fault_addr;
  logic mret;
  logic mie_global;
  logic mtie;
  logic meie;
  logic mtip;
  logic meip;
  logic [31:0] mtvec;
  logic [31:0] mepc;
  logic trap_valid;
  logic trap_interrupt;
  logic [4:0] trap_cause;
  logic [31:0] trap_tval;
  logic [31:0] trap_pc;
  logic mret_taken;
  logic redirect_valid;
  logic [31:0] redirect_pc;

  int unsigned pass_count;
  int unsigned sync_count;
  int unsigned irq_count;
  int unsigned mret_count;
  int unsigned priority_count;
  int unsigned masked_count;

  core_trap u_core_trap (
    .valid_i(valid),
    .pc_i(pc),
    .instr_i(instr),
    .instr_misaligned_i(instr_misaligned),
    .instr_fault_addr_i(instr_fault_addr),
    .illegal_instr_i(illegal_instr),
    .csr_illegal_i(csr_illegal),
    .ecall_i(ecall),
    .ebreak_i(ebreak),
    .load_i(load),
    .store_i(store),
    .lsu_misaligned_i(lsu_misaligned),
    .lsu_fault_addr_i(lsu_fault_addr),
    .mret_i(mret),
    .mie_global_i(mie_global),
    .mtie_i(mtie),
    .meie_i(meie),
    .mtip_i(mtip),
    .meip_i(meip),
    .mtvec_i(mtvec),
    .mepc_i(mepc),
    .trap_valid_o(trap_valid),
    .trap_interrupt_o(trap_interrupt),
    .trap_cause_o(trap_cause),
    .trap_tval_o(trap_tval),
    .trap_pc_o(trap_pc),
    .mret_taken_o(mret_taken),
    .redirect_valid_o(redirect_valid),
    .redirect_pc_o(redirect_pc)
  );

  task automatic drive_idle;
    begin
      valid = 1'b1;
      pc = 32'h0000_1000;
      instr = 32'h0000_0013;
      instr_misaligned = 1'b0;
      instr_fault_addr = 32'h0000_0000;
      illegal_instr = 1'b0;
      csr_illegal = 1'b0;
      ecall = 1'b0;
      ebreak = 1'b0;
      load = 1'b0;
      store = 1'b0;
      lsu_misaligned = 1'b0;
      lsu_fault_addr = 32'h0000_0000;
      mret = 1'b0;
      mie_global = 1'b0;
      mtie = 1'b0;
      meie = 1'b0;
      mtip = 1'b0;
      meip = 1'b0;
      mtvec = 32'h0000_8000;
      mepc = 32'h0000_4000;
    end
  endtask

  task automatic check(
    input logic exp_trap_valid,
    input logic exp_interrupt,
    input logic [4:0] exp_cause,
    input logic [31:0] exp_tval,
    input logic exp_mret_taken,
    input logic exp_redirect_valid,
    input logic [31:0] exp_redirect_pc,
    input string label
  );
    begin
      #1ns;
      if (trap_valid !== exp_trap_valid ||
          trap_interrupt !== exp_interrupt ||
          trap_cause !== exp_cause ||
          trap_tval !== exp_tval ||
          trap_pc !== pc ||
          mret_taken !== exp_mret_taken ||
          redirect_valid !== exp_redirect_valid ||
          redirect_pc !== exp_redirect_pc) begin
        $error("%s mismatch trap=%0b/%0b int=%0b/%0b cause=%0d/%0d tval=0x%08h/0x%08h pc=0x%08h/0x%08h mret=%0b/%0b redir=%0b/%0b redir_pc=0x%08h/0x%08h",
               label, trap_valid, exp_trap_valid, trap_interrupt, exp_interrupt,
               trap_cause, exp_cause, trap_tval, exp_tval, trap_pc, pc,
               mret_taken, exp_mret_taken, redirect_valid, exp_redirect_valid,
               redirect_pc, exp_redirect_pc);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic check_sync_traps;
    begin
      drive_idle();
      instr_misaligned = 1'b1;
      instr_fault_addr = 32'h0000_1002;
      check(1'b1, 1'b0, TRAP_CAUSE_IADDR_MISALIGNED, 32'h0000_1002,
            1'b0, 1'b1, mtvec, "instruction address misaligned");
      sync_count++;

      drive_idle();
      illegal_instr = 1'b1;
      instr = 32'h0000_0000;
      check(1'b1, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'h0000_0000,
            1'b0, 1'b1, mtvec, "illegal instruction");
      sync_count++;

      drive_idle();
      csr_illegal = 1'b1;
      instr = 32'hFFF0_1073;
      check(1'b1, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'hFFF0_1073,
            1'b0, 1'b1, mtvec, "illegal csr");
      sync_count++;

      drive_idle();
      ebreak = 1'b1;
      check(1'b1, 1'b0, TRAP_CAUSE_BREAKPOINT, pc,
            1'b0, 1'b1, mtvec, "ebreak");
      sync_count++;

      drive_idle();
      ecall = 1'b1;
      check(1'b1, 1'b0, TRAP_CAUSE_ECALL_MMODE, 32'h0000_0000,
            1'b0, 1'b1, mtvec, "ecall");
      sync_count++;

      drive_idle();
      load = 1'b1;
      lsu_misaligned = 1'b1;
      lsu_fault_addr = 32'h2000_0001;
      check(1'b1, 1'b0, TRAP_CAUSE_LOAD_MISALIGNED, 32'h2000_0001,
            1'b0, 1'b1, mtvec, "load misaligned");
      sync_count++;

      drive_idle();
      store = 1'b1;
      lsu_misaligned = 1'b1;
      lsu_fault_addr = 32'h2000_0002;
      check(1'b1, 1'b0, TRAP_CAUSE_STORE_MISALIGNED, 32'h2000_0002,
            1'b0, 1'b1, mtvec, "store misaligned");
      sync_count++;
    end
  endtask

  task automatic check_mret;
    begin
      drive_idle();
      mret = 1'b1;
      check(1'b0, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'h0000_0000,
            1'b1, 1'b1, mepc, "mret redirect");
      mret_count++;
    end
  endtask

  task automatic check_interrupts;
    begin
      drive_idle();
      mie_global = 1'b1;
      mtie = 1'b1;
      mtip = 1'b1;
      check(1'b1, 1'b1, TRAP_CAUSE_M_TIMER_IRQ, 32'h0000_0000,
            1'b0, 1'b1, mtvec, "timer irq");
      irq_count++;

      drive_idle();
      mie_global = 1'b1;
      meie = 1'b1;
      meip = 1'b1;
      check(1'b1, 1'b1, TRAP_CAUSE_M_EXTERNAL_IRQ, 32'h0000_0000,
            1'b0, 1'b1, mtvec, "external irq");
      irq_count++;

      drive_idle();
      mie_global = 1'b1;
      mtie = 1'b1;
      meie = 1'b1;
      mtip = 1'b1;
      meip = 1'b1;
      check(1'b1, 1'b1, TRAP_CAUSE_M_EXTERNAL_IRQ, 32'h0000_0000,
            1'b0, 1'b1, mtvec, "external irq priority");
      irq_count++;
      priority_count++;
    end
  endtask

  task automatic check_masking_and_priority;
    begin
      drive_idle();
      mie_global = 1'b0;
      mtie = 1'b1;
      meie = 1'b1;
      mtip = 1'b1;
      meip = 1'b1;
      check(1'b0, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'h0000_0000,
            1'b0, 1'b0, mtvec, "global irq masked");
      masked_count++;

      drive_idle();
      mie_global = 1'b1;
      mtie = 1'b0;
      mtip = 1'b1;
      check(1'b0, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'h0000_0000,
            1'b0, 1'b0, mtvec, "timer enable masked");
      masked_count++;

      drive_idle();
      valid = 1'b0;
      illegal_instr = 1'b1;
      mie_global = 1'b1;
      meie = 1'b1;
      meip = 1'b1;
      check(1'b0, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'h0000_0000,
            1'b0, 1'b0, mtvec, "invalid instruction slot");
      masked_count++;

      drive_idle();
      illegal_instr = 1'b1;
      mret = 1'b1;
      mie_global = 1'b1;
      meie = 1'b1;
      meip = 1'b1;
      check(1'b1, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, instr,
            1'b0, 1'b1, mtvec, "sync trap priority");
      priority_count++;

      drive_idle();
      mret = 1'b1;
      mie_global = 1'b1;
      meie = 1'b1;
      meip = 1'b1;
      check(1'b0, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'h0000_0000,
            1'b1, 1'b1, mepc, "mret priority over irq");
      priority_count++;
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (sync_count < 7 || irq_count < 3 || mret_count < 1 ||
          priority_count < 3 || masked_count < 3) begin
        $error("coverage miss: sync=%0d irq=%0d mret=%0d priority=%0d masked=%0d",
               sync_count, irq_count, mret_count, priority_count, masked_count);
        $fatal(1);
      end
      $display("tb_core_trap coverage: pass_count=%0d sync=%0d irq=%0d mret=%0d priority=%0d masked=%0d",
               pass_count, sync_count, irq_count, mret_count, priority_count, masked_count);
    end
  endtask

  initial begin
    pass_count = 0;
    sync_count = 0;
    irq_count = 0;
    mret_count = 0;
    priority_count = 0;
    masked_count = 0;

    drive_idle();
    check(1'b0, 1'b0, TRAP_CAUSE_ILLEGAL_INSN, 32'h0000_0000,
          1'b0, 1'b0, mtvec, "idle");

    check_sync_traps();
    check_mret();
    check_interrupts();
    check_masking_and_priority();
    check_coverage_summary();

    $display("tb_core_trap PASS");
    $finish;
  end
endmodule
