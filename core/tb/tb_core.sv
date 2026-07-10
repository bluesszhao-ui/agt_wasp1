`timescale 1ns/1ps

module tb_core;
  import wasp1_pkg::*;

  logic        clk;             // 100 MHz verification clock.
  logic        rst_n;           // Active-low reset driven by the testbench.
  logic        instr_valid;     // Instruction stream valid into the core.
  logic        instr_ready;     // Instruction stream ready from the core.
  logic [31:0] instr_pc;        // Instruction stream PC driven by the testbench.
  logic [31:0] instr;           // Instruction word driven by the testbench.
  logic        instr_fault;     // Instruction fetch fault driven by the testbench.
  logic        dmem_req_valid;  // Data-memory request valid from the core.
  logic        dmem_req_ready;  // Data-memory request ready into the core.
  logic [31:0] dmem_req_addr;   // Data-memory byte address from the core.
  logic        dmem_req_write;  // Data-memory store qualifier from the core.
  logic [1:0]  dmem_req_size;   // Data-memory access size from the core.
  logic [31:0] dmem_req_wdata;  // Data-memory store data from the core.
  logic [3:0]  dmem_req_wstrb;  // Data-memory store byte strobes from the core.
  logic        dmem_rsp_valid;  // Data-memory response valid into the core.
  logic        dmem_rsp_ready;  // Data-memory response ready from the core.
  logic [31:0] dmem_rsp_rdata;  // Data-memory read response.
  logic        dmem_rsp_err;    // Data-memory error response.
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
  logic        redirect_valid;  // Core redirect request toward frontend.
  logic [31:0] redirect_pc;     // Core redirect target toward frontend.
  logic [31:0] csr_rdata;       // Core CSR readback observation.
  logic        hazard_load_use; // Core load-use hazard observation.
  logic        hazard_fwd_rs1_ex;// Core rs1 EX-forward observation.
  logic        hazard_fwd_rs1_wb;// Core rs1 WB-forward observation.
  logic        hazard_fwd_rs2_ex;// Core rs2 EX-forward observation.
  logic        hazard_fwd_rs2_wb;// Core rs2 WB-forward observation.
  logic        unsupported;     // Core unsupported instruction observation.
  debug_if     core_debug (.clk(clk), .rst_n(rst_n)); // Debug control/GPR wrapper interface.

  integer pass_count;           // Total passing self-checks.
  integer commit_count;         // Architectural commit coverage counter.
  integer fetch_count;          // Fetch handshake coverage counter.
  integer dmem_count;           // Data-memory request coverage counter.
  integer hazard_count;         // Load-use hazard coverage counter.
  integer trap_count;           // Trap redirect coverage counter.
  integer suppress_count;       // No-write suppression coverage counter.
  integer debug_count;          // Debug halt/resume and GPR wrapper coverage.
  logic [31:0] exp_fetch_pc;    // Scoreboard expected frontend stream PC.

  core dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .instr_valid_i(instr_valid),
    .instr_ready_o(instr_ready),
    .instr_pc_i(instr_pc),
    .instr_i(instr),
    .instr_fault_i(instr_fault),
    .dmem_req_valid_o(dmem_req_valid),
    .dmem_req_ready_i(dmem_req_ready),
    .dmem_req_addr_o(dmem_req_addr),
    .dmem_req_write_o(dmem_req_write),
    .dmem_req_size_o(dmem_req_size),
    .dmem_req_wdata_o(dmem_req_wdata),
    .dmem_req_wstrb_o(dmem_req_wstrb),
    .dmem_rsp_valid_i(dmem_rsp_valid),
    .dmem_rsp_ready_o(dmem_rsp_ready),
    .dmem_rsp_rdata_i(dmem_rsp_rdata),
    .dmem_rsp_err_i(dmem_rsp_err),
    .timer_irq_i(timer_irq),
    .external_irq_i(external_irq),
    .core_debug(core_debug),
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
    .redirect_valid_o(redirect_valid),
    .redirect_pc_o(redirect_pc),
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

  // Zero-wait read-only valid/ready memory response used to verify wrapper
  // pass-through of load requests.
  always_comb begin
    dmem_req_ready = 1'b1;
    dmem_rsp_valid = dmem_req_valid;
    dmem_rsp_err = 1'b0;
    unique case (dmem_req_addr)
      32'h0000_0300: dmem_rsp_rdata = 32'hCAFE_BABE;
      default:       dmem_rsp_rdata = 32'h0000_0000;
    endcase
  end

  // Drive one instruction response from a frontend-side PC model. The core
  // consumes `{pc,instr,fault}` and emits redirects; it no longer owns fetch PC.
  task automatic drive_instr_expect_next(
    input logic [31:0] t_instr,
    input logic [31:0] exp_next_pc
  );
    begin
      @(negedge clk);
      instr_valid = 1'b1;
      instr_pc = exp_fetch_pc;
      instr = t_instr;
      instr_fault = 1'b0;
      #1;
      if (!instr_ready) begin
        $fatal(1, "instruction stream not ready instr=%08x", t_instr);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_next_pc;
      fetch_count++;
    end
  endtask

  task automatic drive_instr(input logic [31:0] t_instr);
    begin
      drive_instr_expect_next(t_instr, exp_fetch_pc + 32'd4);
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
      if (!hazard_load_use || instr_ready || (exp_fetch_pc !== held_pc)) begin
        $fatal(1, "%s hazard mismatch hazard=%0b ready=%0b pc=%08x held=%08x",
               name, hazard_load_use, instr_ready, exp_fetch_pc, held_pc);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = held_pc;
      if (ex_valid) begin
        $fatal(1, "%s bubble mismatch ex_valid=%0b", name, ex_valid);
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
          (trap_tval !== exp_tval) || (trap_pc !== exp_pc) || instr_ready ||
          !redirect_valid || (redirect_pc !== exp_target)) begin
        $fatal(1, "%s trap mismatch valid=%0b intr=%0b cause=%0d tval=%08x pc=%08x ready=%0b redir=%0b target=%08x",
               name, trap_valid, trap_interrupt, trap_cause, trap_tval,
               trap_pc, instr_ready, redirect_valid, redirect_pc);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_target;
      if (ex_valid) begin
        $fatal(1, "%s redirect mismatch ex_valid=%0b", name, ex_valid);
      end
      pass_count++;
      trap_count++;
    end
  endtask

  // Wrapper-level Debug Mode smoke that proves the public core port forwards
  // halt/resume and halted GPR read/write traffic into the datapath.
  task automatic check_debug_wrapper_path;
    begin
      @(negedge clk);
      instr_valid = 1'b0;
      core_debug.halt_req = 1'b1;
      for (int unsigned tries = 0; tries < 20; tries++) begin
        @(posedge clk);
        #1;
        if (core_debug.halted) begin
          if (instr_ready || core_debug.running) begin
            $fatal(1, "debug halt wrapper mismatch ready=%0b running=%0b",
                   instr_ready, core_debug.running);
          end
          pass_count++;
          debug_count++;
          break;
        end
        if (tries == 19) begin
          $fatal(1, "debug halt wrapper timeout");
        end
      end

      @(negedge clk);
      core_debug.gpr_req_valid = 1'b1;
      core_debug.gpr_req_write = 1'b0;
      core_debug.gpr_req_addr = 5'd21;
      core_debug.gpr_req_wdata = 32'h0000_0000;
      core_debug.gpr_rsp_ready = 1'b1;
      #1;
      if (!core_debug.gpr_req_ready) begin
        $fatal(1, "debug read wrapper not ready");
      end
      @(posedge clk);
      #1;
      if (!core_debug.gpr_rsp_valid ||
          (core_debug.gpr_rsp_rdata !== 32'hCAFE_BABE) ||
          core_debug.gpr_rsp_err) begin
        $fatal(1, "debug read wrapper mismatch valid=%0b data=%08x err=%0b",
               core_debug.gpr_rsp_valid, core_debug.gpr_rsp_rdata,
               core_debug.gpr_rsp_err);
      end
      core_debug.gpr_req_valid = 1'b0;
      @(posedge clk);
      pass_count++;
      debug_count++;

      @(negedge clk);
      core_debug.gpr_req_valid = 1'b1;
      core_debug.gpr_req_write = 1'b1;
      core_debug.gpr_req_addr = 5'd11;
      core_debug.gpr_req_wdata = 32'hABCD_0055;
      @(posedge clk);
      #1;
      if (!core_debug.gpr_rsp_valid || core_debug.gpr_rsp_err) begin
        $fatal(1, "debug write wrapper response mismatch");
      end
      core_debug.gpr_req_valid = 1'b0;
      @(posedge clk);
      pass_count++;
      debug_count++;

      @(negedge clk);
      core_debug.gpr_req_valid = 1'b1;
      core_debug.gpr_req_write = 1'b0;
      core_debug.gpr_req_addr = 5'd11;
      @(posedge clk);
      #1;
      if (!core_debug.gpr_rsp_valid ||
          (core_debug.gpr_rsp_rdata !== 32'hABCD_0055)) begin
        $fatal(1, "debug readback wrapper mismatch data=%08x",
               core_debug.gpr_rsp_rdata);
      end
      core_debug.gpr_req_valid = 1'b0;
      @(posedge clk);
      pass_count++;
      debug_count++;

      @(negedge clk);
      core_debug.halt_req = 1'b0;
      core_debug.resume_req = 1'b1;
      @(posedge clk);
      #1;
      core_debug.resume_req = 1'b0;
      if (core_debug.halted || !core_debug.running) begin
        $fatal(1, "debug resume wrapper mismatch halted=%0b running=%0b",
               core_debug.halted, core_debug.running);
      end
      pass_count++;
      debug_count++;
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
    debug_count = 0;

    exp_fetch_pc = 32'h0001_0000;
    rst_n = 1'b0;
    instr_valid = 1'b0;
    instr_pc = exp_fetch_pc;
    instr = 32'h0000_0013;
    instr_fault = 1'b0;
    timer_irq = 1'b0;
    external_irq = 1'b0;
    core_debug.halt_req = 1'b0;
    core_debug.resume_req = 1'b0;
    core_debug.step_req = 1'b0;
    core_debug.trigger_execute_valid = '0;
    core_debug.trigger_execute_addr = '0;
    core_debug.gpr_req_valid = 1'b0;
    core_debug.gpr_req_write = 1'b0;
    core_debug.gpr_req_addr = 5'd0;
    core_debug.gpr_req_wdata = 32'h0000_0000;
    core_debug.gpr_rsp_ready = 1'b1;

    repeat (2) @(posedge clk);
    #1;
    if (ex_valid || commit_valid || trap_valid) begin
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
    check_debug_wrapper_path();

    if (pass_count < 9 || commit_count < 6 || fetch_count < 8 ||
        dmem_count < 1 || hazard_count < 1 || trap_count < 1 ||
        suppress_count < 1 || debug_count < 5) begin
      $fatal(1, "core wrapper coverage goal missed");
    end

    $display("tb_core coverage: pass_count=%0d commit=%0d fetch=%0d dmem=%0d hazard=%0d trap=%0d suppress=%0d debug=%0d",
             pass_count, commit_count, fetch_count, dmem_count,
             hazard_count, trap_count, suppress_count, debug_count);
    $display("tb_core PASS");
    $finish;
  end
endmodule
