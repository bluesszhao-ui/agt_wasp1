`timescale 1ns/1ps

module tb_core;
  import wasp1_pkg::*;

  logic        clk;             // 100 MHz verification clock.
  logic        rst_n;           // Active-low reset driven by the testbench.
  logic [31:0] boot_pc;         // Reset PC supplied to the core wrapper.
  logic        if_req_valid;    // Fetch request valid from the core.
  logic [31:0] if_req_pc;       // Fetch request PC from the core.
  logic        if_rsp_valid;    // Instruction response valid into the core.
  logic        if_rsp_ready;    // Instruction response ready from the core.
  logic [31:0] if_rsp_instr;    // Instruction word driven by the testbench.
  logic        if_rsp_fault;    // Instruction fetch fault driven by the testbench.
  logic        dmem_req_valid;  // Data-memory request valid from the core.
  logic [31:0] dmem_req_addr;   // Data-memory byte address from the core.
  logic        dmem_req_write;  // Data-memory store qualifier from the core.
  logic [1:0]  dmem_req_size;   // Data-memory access size from the core.
  logic [31:0] dmem_req_wdata;  // Data-memory store data from the core.
  logic [3:0]  dmem_req_wstrb;  // Data-memory store byte strobes from the core.
  logic [31:0] dmem_rsp_rdata;  // Combinational data-memory read response.
  logic        dmem_rsp_err;    // Combinational data-memory error response.
  logic        timer_irq;       // Timer interrupt input to the core.
  logic        external_irq;    // External interrupt input to the core.
  logic        commit_valid;    // Core architectural writeback valid.
  logic [4:0]  commit_rd;       // Core architectural writeback register.
  logic [31:0] commit_data;     // Core architectural writeback data.
  logic        ex_valid;        // Core execute slot valid indicator.
  logic [31:0] ex_pc;           // Core execute slot PC.
  logic [31:0] ex_instr;        // Core execute slot instruction.
  logic        illegal;         // Core illegal instruction indicator.
  logic        lsu_fault;       // Core load/store fault indicator.
  logic        trap_valid;      // Core trap entry indicator.
  logic        trap_interrupt;  // Core interrupt trap indicator.
  logic [4:0]  trap_cause;      // Core trap cause without interrupt MSB.
  logic [31:0] trap_tval;       // Core trap value.
  logic [31:0] trap_pc;         // Core trap PC.
  logic        mret_taken;      // Core MRET redirect indicator.
  logic [31:0] csr_rdata;       // Core CSR readback observation.
  logic        hazard_load_use; // Core load-use hazard observation.
  logic        hazard_fwd_rs1_ex;// Core rs1 EX-forward observation.
  logic        hazard_fwd_rs1_wb;// Core rs1 WB-forward observation.
  logic        hazard_fwd_rs2_ex;// Core rs2 EX-forward observation.
  logic        hazard_fwd_rs2_wb;// Core rs2 WB-forward observation.
  logic        unsupported;     // Core unsupported instruction observation.

  integer pass_count;           // Total passing self-checks.
  integer commit_count;         // Architectural commit coverage counter.
  integer fetch_count;          // Fetch handshake coverage counter.
  integer dmem_count;           // Data-memory request coverage counter.
  integer hazard_count;         // Load-use hazard coverage counter.
  integer trap_count;           // Trap redirect coverage counter.
  integer suppress_count;       // No-write suppression coverage counter.
  logic [31:0] exp_fetch_pc;    // Scoreboard expected fetch request PC.

  core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .boot_pc_i(boot_pc),
    .if_req_valid_o(if_req_valid),
    .if_req_pc_o(if_req_pc),
    .if_rsp_valid_i(if_rsp_valid),
    .if_rsp_ready_o(if_rsp_ready),
    .if_rsp_instr_i(if_rsp_instr),
    .if_rsp_fault_i(if_rsp_fault),
    .dmem_req_valid_o(dmem_req_valid),
    .dmem_req_addr_o(dmem_req_addr),
    .dmem_req_write_o(dmem_req_write),
    .dmem_req_size_o(dmem_req_size),
    .dmem_req_wdata_o(dmem_req_wdata),
    .dmem_req_wstrb_o(dmem_req_wstrb),
    .dmem_rsp_rdata_i(dmem_rsp_rdata),
    .dmem_rsp_err_i(dmem_rsp_err),
    .timer_irq_i(timer_irq),
    .external_irq_i(external_irq),
    .commit_valid_o(commit_valid),
    .commit_rd_o(commit_rd),
    .commit_data_o(commit_data),
    .ex_valid_o(ex_valid),
    .ex_pc_o(ex_pc),
    .ex_instr_o(ex_instr),
    .illegal_o(illegal),
    .lsu_fault_o(lsu_fault),
    .trap_valid_o(trap_valid),
    .trap_interrupt_o(trap_interrupt),
    .trap_cause_o(trap_cause),
    .trap_tval_o(trap_tval),
    .trap_pc_o(trap_pc),
    .mret_taken_o(mret_taken),
    .csr_rdata_o(csr_rdata),
    .hazard_load_use_o(hazard_load_use),
    .hazard_fwd_rs1_ex_o(hazard_fwd_rs1_ex),
    .hazard_fwd_rs1_wb_o(hazard_fwd_rs1_wb),
    .hazard_fwd_rs2_ex_o(hazard_fwd_rs2_ex),
    .hazard_fwd_rs2_wb_o(hazard_fwd_rs2_wb),
    .unsupported_o(unsupported)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [31:0] enc_r(
    input logic [6:0] funct7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd
  );
    enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
  endfunction

  function automatic logic [31:0] enc_i(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3,
    input logic [4:0]  rd
  );
    enc_i = {imm, rs1, funct3, rd, 7'b0010011};
  endfunction

  function automatic logic [31:0] enc_load(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3,
    input logic [4:0]  rd
  );
    enc_load = {imm, rs1, funct3, rd, 7'b0000011};
  endfunction

  // Single-cycle read-only memory response used to verify wrapper pass-through
  // of load requests. Cache and AHB timing are covered by later modules.
  always_comb begin
    dmem_rsp_err = 1'b0;
    unique case (dmem_req_addr)
      32'h0000_0300: dmem_rsp_rdata = 32'hCAFE_BABE;
      default:       dmem_rsp_rdata = 32'h0000_0000;
    endcase
  end

  // Drive one instruction response and check the fetch PC before and after the
  // accepted handshake. This keeps the wrapper test tied to the public IF port.
  task automatic drive_instr_expect_next(
    input logic [31:0] instr,
    input logic [31:0] exp_next_pc
  );
    begin
      @(negedge clk);
      if (if_req_pc !== exp_fetch_pc) begin
        $fatal(1, "fetch PC before drive mismatch got=%08x exp=%08x",
               if_req_pc, exp_fetch_pc);
      end
      if_rsp_valid = 1'b1;
      if_rsp_instr = instr;
      if_rsp_fault = 1'b0;
      #1;
      if (!if_req_valid || !if_rsp_ready) begin
        $fatal(1, "fetch handshake not ready instr=%08x valid=%0b ready=%0b",
               instr, if_req_valid, if_rsp_ready);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_next_pc;
      if (if_req_pc !== exp_fetch_pc) begin
        $fatal(1, "fetch PC after drive mismatch got=%08x exp=%08x",
               if_req_pc, exp_fetch_pc);
      end
      fetch_count++;
    end
  endtask

  task automatic drive_instr(input logic [31:0] instr);
    begin
      drive_instr_expect_next(instr, exp_fetch_pc + 32'd4);
    end
  endtask

  // Check an architectural register writeback from the wrapped datapath.
  task automatic expect_commit(
    input string       name,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_data
  );
    begin
      #1;
      if (!commit_valid || (commit_rd !== exp_rd) || (commit_data !== exp_data)) begin
        $fatal(1, "%s commit mismatch valid=%0b rd=%0d data=%08x exp_rd=%0d exp=%08x",
               name, commit_valid, commit_rd, commit_data, exp_rd, exp_data);
      end
      pass_count++;
      commit_count++;
    end
  endtask

  // Check that the current execute slot intentionally does not write back.
  task automatic expect_no_commit(input string name);
    begin
      #1;
      if (commit_valid) begin
        $fatal(1, "%s unexpected commit rd=%0d data=%08x", name, commit_rd, commit_data);
      end
      pass_count++;
      suppress_count++;
    end
  endtask

  // Check a load request on the data-memory interface.
  task automatic expect_load_req(
    input string       name,
    input logic [31:0] exp_addr,
    input logic [1:0]  exp_size
  );
    begin
      #1;
      if (!dmem_req_valid || dmem_req_write || (dmem_req_addr !== exp_addr) ||
          (dmem_req_size !== exp_size)) begin
        $fatal(1, "%s load request mismatch valid=%0b write=%0b addr=%08x size=%0d",
               name, dmem_req_valid, dmem_req_write, dmem_req_addr, dmem_req_size);
      end
      dmem_count++;
    end
  endtask

  // Check the public hazard observation and the stalled IF ready signal.
  task automatic expect_load_use_stall(input string name, input logic [31:0] held_pc);
    begin
      @(negedge clk);
      #1;
      if (!hazard_load_use || if_rsp_ready || (if_req_pc !== held_pc)) begin
        $fatal(1, "%s hazard mismatch hazard=%0b ready=%0b pc=%08x held=%08x",
               name, hazard_load_use, if_rsp_ready, if_req_pc, held_pc);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = held_pc;
      if (ex_valid || (if_req_pc !== held_pc)) begin
        $fatal(1, "%s bubble mismatch ex_valid=%0b pc=%08x", name, ex_valid, if_req_pc);
      end
      pass_count++;
      hazard_count++;
    end
  endtask

  // Check a synchronous trap redirect through the public trap and fetch ports.
  task automatic expect_trap_redirect(
    input string       name,
    input logic [4:0]  exp_cause,
    input logic [31:0] exp_tval,
    input logic [31:0] exp_pc,
    input logic [31:0] exp_target
  );
    begin
      #1;
      if (!trap_valid || trap_interrupt || (trap_cause !== exp_cause) ||
          (trap_tval !== exp_tval) || (trap_pc !== exp_pc) || if_rsp_ready) begin
        $fatal(1, "%s trap mismatch valid=%0b intr=%0b cause=%0d tval=%08x pc=%08x ready=%0b",
               name, trap_valid, trap_interrupt, trap_cause, trap_tval,
               trap_pc, if_rsp_ready);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_target;
      if (if_req_pc !== exp_target || ex_valid) begin
        $fatal(1, "%s redirect mismatch pc=%08x target=%08x ex_valid=%0b",
               name, if_req_pc, exp_target, ex_valid);
      end
      pass_count++;
      trap_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    commit_count = 0;
    fetch_count = 0;
    dmem_count = 0;
    hazard_count = 0;
    trap_count = 0;
    suppress_count = 0;

    boot_pc = 32'h0001_0000;
    exp_fetch_pc = boot_pc;
    rst_n = 1'b0;
    if_rsp_valid = 1'b0;
    if_rsp_instr = 32'h0000_0013;
    if_rsp_fault = 1'b0;
    timer_irq = 1'b0;
    external_irq = 1'b0;

    repeat (2) @(posedge clk);
    #1;
    if (if_req_pc !== boot_pc || ex_valid || commit_valid || trap_valid) begin
      $fatal(1, "core reset observation mismatch");
    end
    rst_n = 1'b1;

    drive_instr(enc_i(12'd5, 5'd0, 3'b000, 5'd1));  // addi x1,x0,5
    drive_instr(enc_i(12'd3, 5'd1, 3'b000, 5'd2));  // addi x2,x1,3
    expect_commit("addi x1", 5'd1, 32'd5);

    drive_instr(enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3)); // add x3,x1,x2
    expect_commit("addi x2", 5'd2, 32'd8);

    drive_instr(enc_i(12'h300, 5'd0, 3'b000, 5'd20)); // addi x20,x0,0x300
    expect_commit("add x3", 5'd3, 32'd13);

    drive_instr(enc_load(12'd0, 5'd20, 3'b010, 5'd21)); // lw x21,0(x20)
    expect_commit("base x20", 5'd20, 32'h0000_0300);

    drive_instr(enc_r(7'b0000000, 5'd0, 5'd21, 3'b000, 5'd22)); // add x22,x21,x0
    expect_load_req("lw request", 32'h0000_0300, 2'd2);
    expect_commit("lw x21", 5'd21, 32'hCAFE_BABE);
    expect_load_use_stall("lw/add load-use", exp_fetch_pc);

    drive_instr(32'h0000_0013); // nop drain for dependent add
    expect_commit("dependent add x22", 5'd22, 32'hCAFE_BABE);

    drive_instr(32'hFFFF_FFFF); // illegal instruction, mtvec reset value is zero
    expect_no_commit("nop no write before illegal");

    drive_instr(32'h0000_0013); // fall-through instruction flushed by trap
    expect_trap_redirect("illegal trap", TRAP_CAUSE_ILLEGAL_INSN,
                         32'hFFFF_FFFF, ex_pc, 32'h0000_0000);

    if (pass_count < 9 || commit_count < 6 || fetch_count < 8 ||
        dmem_count < 1 || hazard_count < 1 || trap_count < 1 ||
        suppress_count < 1) begin
      $fatal(1, "core wrapper coverage goal missed");
    end

    $display("tb_core coverage: pass_count=%0d commit=%0d fetch=%0d dmem=%0d hazard=%0d trap=%0d suppress=%0d",
             pass_count, commit_count, fetch_count, dmem_count,
             hazard_count, trap_count, suppress_count);
    $display("tb_core PASS");
    $finish;
  end
endmodule
