`timescale 1ns/1ps

// Self-checking testbench for core_csr.
//
// The bench drives CSR instructions, traps, MRET, interrupt pending inputs, and
// retire pulses. It checks software-visible CSR values and side-effect outputs.
module tb_core_csr;
  import core_types_pkg::*;
  import wasp1_pkg::*;

  logic clk;                 // 100MHz test clock.
  logic rst_n;               // Active-low reset stimulus.
  logic csr_valid;           // CSR access qualifier stimulus.
  core_csr_cmd_e csr_cmd;    // CSR command stimulus.
  logic [11:0] csr_addr;     // CSR address stimulus.
  logic [31:0] csr_wdata;    // CSR write data/zimm stimulus.
  logic [31:0] csr_rdata;    // DUT CSR read data.
  logic csr_illegal;         // DUT illegal CSR indicator.
  logic retire;              // Retire pulse stimulus for instret.
  logic trap_valid;          // Trap-entry stimulus.
  logic trap_interrupt;      // Trap interrupt-class stimulus.
  logic [4:0] trap_cause;    // Trap cause stimulus.
  logic [31:0] trap_pc;      // Trap PC stimulus.
  logic [31:0] trap_tval;    // Trap value stimulus.
  logic mret;                // MRET stimulus.
  logic timer_irq;           // Timer IRQ pending stimulus.
  logic external_irq;        // External IRQ pending stimulus.
  logic [31:0] mtvec;        // DUT mtvec output.
  logic [31:0] mepc;         // DUT mepc output.
  logic mie_global;          // DUT mstatus.MIE output.
  logic mtie;                // DUT mie.MTIE output.
  logic meie;                // DUT mie.MEIE output.
  logic mtip;                // DUT mip.MTIP output.
  logic meip;                // DUT mip.MEIP output.

  int unsigned pass_count;      // Number of successful checks.
  int unsigned rw_count;        // Direct write/masked write coverage.
  int unsigned set_clear_count; // CSRRS/CSRRC coverage.
  int unsigned readonly_count;  // Read-only/unsupported illegal coverage.
  int unsigned trap_count;      // Trap/MRET coverage.
  int unsigned counter_count;   // cycle/instret coverage.
  int unsigned irq_count;       // IRQ enable/pending coverage.

  core_csr u_core_csr (
    .clk_i(clk),
    .rst_ni(rst_n),
    .csr_valid_i(csr_valid),
    .csr_cmd_i(csr_cmd),
    .csr_addr_i(csr_addr),
    .csr_wdata_i(csr_wdata),
    .csr_rdata_o(csr_rdata),
    .csr_illegal_o(csr_illegal),
    .retire_i(retire),
    .trap_valid_i(trap_valid),
    .trap_interrupt_i(trap_interrupt),
    .trap_cause_i(trap_cause),
    .trap_pc_i(trap_pc),
    .trap_tval_i(trap_tval),
    .mret_i(mret),
    .timer_irq_i(timer_irq),
    .external_irq_i(external_irq),
    .mtvec_o(mtvec),
    .mepc_o(mepc),
    .mie_global_o(mie_global),
    .mtie_o(mtie),
    .meie_o(meie),
    .mtip_o(mtip),
    .meip_o(meip)
  );

  // Generate the project default 10ns clock.
  initial begin
    clk = 1'b0;
    forever #5ns clk = ~clk;
  end

  // Drive all CSR side-effect inputs inactive.
  task automatic idle_inputs;
    begin
      csr_valid = 1'b0;
      csr_cmd = CORE_CSR_NONE;
      csr_addr = 12'h000;
      csr_wdata = 32'h0000_0000;
      retire = 1'b0;
      trap_valid = 1'b0;
      trap_interrupt = 1'b0;
      trap_cause = 5'd0;
      trap_pc = 32'h0000_0000;
      trap_tval = 32'h0000_0000;
      mret = 1'b0;
      timer_irq = 1'b0;
      external_irq = 1'b0;
    end
  endtask

  // Reset DUT and leave inputs idle.
  task automatic reset_dut;
    begin
      idle_inputs();
      rst_n = 1'b0;
      repeat (3) @(posedge clk);
      @(negedge clk);
      rst_n = 1'b1;
      #1ns;
    end
  endtask

  // Perform a pure CSR read and fail if the address is unexpectedly illegal.
  task automatic read_csr(input logic [11:0] addr, output logic [31:0] data);
    begin
      csr_valid = 1'b1;
      csr_cmd = CORE_CSR_NONE;
      csr_addr = addr;
      csr_wdata = 32'h0000_0000;
      #1ns;
      if (csr_illegal) begin
        $error("read_csr unexpected illegal addr=0x%03h", addr);
        $fatal(1);
      end
      data = csr_rdata;
      csr_valid = 1'b0;
      csr_addr = 12'h000;
      pass_count++;
    end
  endtask

  // Read one CSR and compare against an expected value.
  task automatic expect_read(input logic [11:0] addr, input logic [31:0] exp, input string label);
    logic [31:0] data;
    begin
      read_csr(addr, data);
      if (data !== exp) begin
        $error("%s: addr=0x%03h expected=0x%08h got=0x%08h", label, addr, exp, data);
        $fatal(1);
      end
    end
  endtask

  // Drive one CSR operation, check the old read value, and commit on a clock.
  task automatic write_csr(
    input core_csr_cmd_e cmd,
    input logic [11:0] addr,
    input logic [31:0] data,
    input logic [31:0] exp_old,
    input string label
  );
    begin
      @(negedge clk);
      csr_valid = 1'b1;
      csr_cmd = cmd;
      csr_addr = addr;
      csr_wdata = data;
      #1ns;
      if (csr_illegal || csr_rdata !== exp_old) begin
        $error("%s: illegal=%0b old expected=0x%08h got=0x%08h",
               label, csr_illegal, exp_old, csr_rdata);
        $fatal(1);
      end
      @(posedge clk);
      #1ns;
      csr_valid = 1'b0;
      csr_cmd = CORE_CSR_NONE;
      csr_addr = 12'h000;
      csr_wdata = 32'h0000_0000;
      pass_count++;
    end
  endtask

  task automatic expect_illegal_write(
    input core_csr_cmd_e cmd,
    input logic [11:0] addr,
    input string label
  );
    begin
      csr_valid = 1'b1;
      csr_cmd = cmd;
      csr_addr = addr;
      csr_wdata = 32'hFFFF_FFFF;
      #1ns;
      if (!csr_illegal) begin
        $error("%s: expected illegal addr=0x%03h", label, addr);
        $fatal(1);
      end
      csr_valid = 1'b0;
      csr_cmd = CORE_CSR_NONE;
      csr_addr = 12'h000;
      readonly_count++;
      pass_count++;
    end
  endtask

  task automatic check_reset;
    begin
      expect_read(CSR_MSTATUS, 32'h0000_1800, "reset mstatus");
      expect_read(CSR_MIE, 32'h0000_0000, "reset mie");
      expect_read(CSR_MTVEC, 32'h0000_0000, "reset mtvec");
      expect_read(CSR_MSCRATCH, 32'h0000_0000, "reset mscratch");
      expect_read(CSR_MEPC, 32'h0000_0000, "reset mepc");
      expect_read(CSR_MCAUSE, 32'h0000_0000, "reset mcause");
      expect_read(CSR_MTVAL, 32'h0000_0000, "reset mtval");
    end
  endtask

  task automatic check_rw_set_clear;
    begin
      write_csr(CORE_CSR_RW, CSR_MSCRATCH, 32'h1234_5678, 32'h0000_0000, "mscratch rw");
      expect_read(CSR_MSCRATCH, 32'h1234_5678, "mscratch after rw");
      rw_count++;

      write_csr(CORE_CSR_RS, CSR_MSCRATCH, 32'h0000_00F0, 32'h1234_5678, "mscratch set");
      expect_read(CSR_MSCRATCH, 32'h1234_56F8, "mscratch after set");
      set_clear_count++;

      write_csr(CORE_CSR_RC, CSR_MSCRATCH, 32'h0000_00F8, 32'h1234_56F8, "mscratch clear");
      expect_read(CSR_MSCRATCH, 32'h1234_5600, "mscratch after clear");
      set_clear_count++;

      write_csr(CORE_CSR_RWI, CSR_MSCRATCH, 32'h0000_001F, 32'h1234_5600, "mscratch rwi");
      expect_read(CSR_MSCRATCH, 32'h0000_001F, "mscratch after rwi");
      rw_count++;
    end
  endtask

  task automatic check_masks_and_irq;
    begin
      write_csr(CORE_CSR_RW, CSR_MSTATUS, 32'hFFFF_FFFF, 32'h0000_1800, "mstatus mask");
      expect_read(CSR_MSTATUS, 32'h0000_1888, "mstatus masked");
      if (!mie_global) begin
        $error("mie_global should be set");
        $fatal(1);
      end
      rw_count++;

      write_csr(CORE_CSR_RW, CSR_MIE, 32'hFFFF_FFFF, 32'h0000_0000, "mie mask");
      expect_read(CSR_MIE, 32'h0000_0880, "mie masked");
      if (!mtie || !meie) begin
        $error("mtie/meie should be set");
        $fatal(1);
      end
      irq_count++;

      timer_irq = 1'b1;
      external_irq = 1'b1;
      #1ns;
      if (!mtip || !meip) begin
        $error("pending irq outputs not set");
        $fatal(1);
      end
      expect_read(CSR_MIP, 32'h0000_0880, "mip external pending");
      irq_count++;
    end
  endtask

  task automatic check_mtvec_mepc_masks;
    begin
      write_csr(CORE_CSR_RW, CSR_MTVEC, 32'h0000_1003, 32'h0000_0000, "mtvec direct mask");
      expect_read(CSR_MTVEC, 32'h0000_1000, "mtvec masked");
      if (mtvec !== 32'h0000_1000) begin
        $error("mtvec output mismatch 0x%08h", mtvec);
        $fatal(1);
      end
      rw_count++;

      write_csr(CORE_CSR_RW, CSR_MEPC, 32'h0000_2003, 32'h0000_0000, "mepc mask");
      expect_read(CSR_MEPC, 32'h0000_2002, "mepc masked");
      if (mepc !== 32'h0000_2002) begin
        $error("mepc output mismatch 0x%08h", mepc);
        $fatal(1);
      end
      rw_count++;
    end
  endtask

  task automatic check_counters;
    logic [31:0] cycle_a;
    logic [31:0] cycle_b;
    logic [31:0] instret_a;
    logic [31:0] instret_b;
    begin
      read_csr(CSR_CYCLE, cycle_a);
      repeat (3) @(posedge clk);
      #1ns;
      read_csr(CSR_CYCLE, cycle_b);
      if (cycle_b <= cycle_a) begin
        $error("cycle did not advance: a=%0d b=%0d", cycle_a, cycle_b);
        $fatal(1);
      end
      counter_count++;

      read_csr(CSR_INSTRET, instret_a);
      @(negedge clk);
      retire = 1'b1;
      @(posedge clk);
      #1ns;
      retire = 1'b0;
      read_csr(CSR_INSTRET, instret_b);
      if (instret_b != (instret_a + 32'd1)) begin
        $error("instret expected +1 a=%0d b=%0d", instret_a, instret_b);
        $fatal(1);
      end
      counter_count++;

      expect_illegal_write(CORE_CSR_RW, CSR_CYCLE, "cycle read-only");
      expect_illegal_write(CORE_CSR_RW, CSR_INSTRET, "instret read-only");
    end
  endtask

  task automatic check_trap_mret;
    begin
      write_csr(CORE_CSR_RW, CSR_MSTATUS, 32'h0000_1888, 32'h0000_1888, "enable before trap");
      rw_count++;
      @(negedge clk);
      trap_valid = 1'b1;
      trap_interrupt = 1'b1;
      trap_cause = TRAP_CAUSE_M_TIMER_IRQ;
      trap_pc = 32'h0000_3003;
      trap_tval = 32'hDEAD_BEEF;
      @(posedge clk);
      #1ns;
      trap_valid = 1'b0;
      trap_interrupt = 1'b0;
      expect_read(CSR_MEPC, 32'h0000_3002, "trap mepc");
      expect_read(CSR_MCAUSE, 32'h8000_0007, "trap mcause");
      expect_read(CSR_MTVAL, 32'hDEAD_BEEF, "trap mtval");
      expect_read(CSR_MSTATUS, 32'h0000_1880, "trap mstatus");
      if (mie_global) begin
        $error("mie_global should be cleared after trap");
        $fatal(1);
      end
      trap_count++;

      @(negedge clk);
      mret = 1'b1;
      @(posedge clk);
      #1ns;
      mret = 1'b0;
      expect_read(CSR_MSTATUS, 32'h0000_1888, "mret mstatus");
      if (!mie_global) begin
        $error("mie_global should be restored after mret");
        $fatal(1);
      end
      trap_count++;
    end
  endtask

  task automatic check_illegal_addr;
    begin
      expect_illegal_write(CORE_CSR_RW, 12'hFFF, "unsupported csr");
      csr_valid = 1'b1;
      csr_cmd = CORE_CSR_NONE;
      csr_addr = 12'hFFF;
      #1ns;
      if (!csr_illegal) begin
        $error("unsupported csr read should be illegal");
        $fatal(1);
      end
      csr_valid = 1'b0;
      readonly_count++;
      pass_count++;
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (rw_count < 6 || set_clear_count < 2 || readonly_count < 4 ||
          trap_count < 2 || counter_count < 2 || irq_count < 2) begin
        $error("coverage miss: rw=%0d set_clear=%0d readonly=%0d trap=%0d counter=%0d irq=%0d",
               rw_count, set_clear_count, readonly_count, trap_count,
               counter_count, irq_count);
        $fatal(1);
      end
      $display("tb_core_csr coverage: pass_count=%0d rw=%0d set_clear=%0d readonly=%0d trap=%0d counter=%0d irq=%0d",
               pass_count, rw_count, set_clear_count, readonly_count,
               trap_count, counter_count, irq_count);
    end
  endtask

  initial begin
    pass_count = 0;
    rw_count = 0;
    set_clear_count = 0;
    readonly_count = 0;
    trap_count = 0;
    counter_count = 0;
    irq_count = 0;
    rst_n = 1'b1;

    reset_dut();
    check_reset();
    check_rw_set_clear();
    check_masks_and_irq();
    check_mtvec_mepc_masks();
    check_counters();
    check_trap_mret();
    check_illegal_addr();
    check_coverage_summary();

    $display("tb_core_csr PASS");
    $finish;
  end
endmodule
