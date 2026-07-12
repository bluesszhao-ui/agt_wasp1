`timescale 1ns/1ps

module tb_core_int_datapath;
  import wasp1_pkg::*;

  logic        clk;            // Testbench clock.
  logic        rst_n;          // Active-low reset.
  logic        instr_valid;    // Testbench frontend instruction valid.
  logic        instr_ready;    // DUT can accept frontend instruction.
  logic [31:0] instr_pc;       // Testbench frontend instruction PC.
  logic [31:0] instr;          // Testbench frontend instruction word.
  logic        instr_fault;    // Testbench frontend instruction fetch fault.
  logic        dmem_req_valid; // DUT data-memory request valid.
  logic        dmem_req_ready; // Testbench data-memory request ready.
  logic [31:0] dmem_req_addr;  // DUT data-memory request address.
  logic        dmem_req_write; // DUT data-memory write qualifier.
  logic [1:0]  dmem_req_size;  // DUT data-memory access size.
  logic [31:0] dmem_req_wdata; // DUT data-memory write data.
  logic [3:0]  dmem_req_wstrb; // DUT data-memory byte strobes.
  logic        dmem_rsp_valid; // Testbench data-memory response valid.
  logic        dmem_rsp_ready; // DUT data-memory response ready.
  logic [31:0] dmem_rsp_rdata; // Testbench data-memory read data.
  logic        dmem_rsp_err;   // Testbench data-memory response error.
  logic        timer_irq;      // Testbench timer interrupt pending.
  logic        external_irq;   // Testbench external interrupt pending.
  logic        commit_valid;   // DUT writeback valid.
  logic [4:0]  commit_rd;      // DUT writeback register.
  logic [31:0] commit_data;    // DUT writeback data.
  logic        ex_valid;       // DUT execute slot valid.
  logic [31:0] ex_pc;          // DUT execute slot PC.
  logic [31:0] ex_instr;       // DUT execute slot instruction.
  logic        illegal;        // DUT illegal instruction flag.
  logic        lsu_fault;      // DUT load/store fault flag.
  logic        trap_valid;     // DUT trap entry selected.
  logic        trap_interrupt; // DUT trap is an interrupt.
  logic [4:0]  trap_cause;     // DUT trap cause.
  logic [31:0] trap_tval;      // DUT trap value.
  logic [31:0] trap_pc;        // DUT trap PC.
  logic        mret_taken;     // DUT MRET redirect selected.
  logic        redirect_valid; // DUT redirect request toward frontend.
  logic [31:0] redirect_pc;    // DUT redirect target toward frontend.
  logic [31:0] csr_rdata;      // DUT CSR read data.
  logic        hazard_load_use;// DUT load-use hazard indicator.
  logic        hazard_fwd_rs1_ex;// DUT rs1 EX-forward indicator.
  logic        hazard_fwd_rs1_wb;// DUT rs1 WB-forward indicator.
  logic        hazard_fwd_rs2_ex;// DUT rs2 EX-forward indicator.
  logic        hazard_fwd_rs2_wb;// DUT rs2 WB-forward indicator.
  logic        unsupported;    // DUT unsupported instruction class flag.
  debug_if     core_debug (.clk(clk), .rst_n(rst_n)); // Debug control/GPR test interface.

  integer pass_count;          // Total passing checks.
  integer commit_count;        // Number of observed commits.
  integer alu_i_count;         // Immediate ALU coverage.
  integer alu_r_count;         // Register ALU coverage.
  integer upper_count;         // LUI/AUIPC coverage.
  integer link_count;          // JAL/JALR link write coverage.
  integer branch_count;        // Conditional branch coverage.
  integer redirect_count;      // Taken redirect and flush coverage.
  integer load_count;          // Load writeback coverage.
  integer store_count;         // Store request coverage.
  integer lsu_fault_count;     // LSU misalignment/error coverage.
  integer dmem_wait_count;     // Data-memory wait/backpressure coverage.
  integer dmem_bp_count;       // Data request-ready backpressure coverage.
  integer csr_count;           // CSR read/write coverage.
  integer trap_count;          // Trap and MRET coverage.
  integer irq_count;           // Interrupt trap coverage.
  integer hazard_count;        // Load-use stall coverage.
  integer suppress_count;      // x0/illegal/unsupported suppression coverage.
  integer pc_count;            // Fetch PC stepping coverage.
  integer debug_count;         // Debug halt/resume and GPR access coverage.
  integer debug_exec_count;    // Halted Program Buffer injection coverage.
  integer trigger_count;       // Execute-address debug trigger coverage.
  integer load_trigger_count;  // Precise load-address debug trigger coverage.
  integer store_trigger_count; // Precise store-address debug trigger coverage.
  logic [31:0] exp_fetch_pc;   // Scoreboard expected frontend stream PC.
  logic        mem_zero_wait;   // Select zero-wait or registered response model.
  logic        mem_req_ready_en;// Allows directed request-ready backpressure.
  logic        mem_rsp_pending_q;// Registered data response pending.
  logic [31:0] mem_rsp_data_q;  // Registered data response payload.
  logic        mem_rsp_err_q;   // Registered data response error.
  logic [31:0] saved_ecall_pc;  // ECALL PC captured for MEPC/MRET checks.

  core_int_datapath dut (
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

  function automatic logic [31:0] enc_u(
    input logic [19:0] imm20,
    input logic [4:0]  rd,
    input logic [6:0]  opcode
  );
    enc_u = {imm20, rd, opcode};
  endfunction

  function automatic logic [31:0] enc_jal(
    input logic [20:0] imm,
    input logic [4:0]  rd
  );
    enc_jal = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  function automatic logic [31:0] enc_jalr(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [4:0]  rd
  );
    enc_jalr = {imm, rs1, 3'b000, rd, 7'b1100111};
  endfunction

  function automatic logic [31:0] enc_branch(
    input logic [12:0] imm,
    input logic [4:0]  rs2,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3
  );
    enc_branch = {imm[12], imm[10:5], rs2, rs1, funct3,
                  imm[4:1], imm[11], 7'b1100011};
  endfunction

  function automatic logic [31:0] enc_load(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3,
    input logic [4:0]  rd
  );
    enc_load = {imm, rs1, funct3, rd, 7'b0000011};
  endfunction

  function automatic logic [31:0] enc_store(
    input logic [11:0] imm,
    input logic [4:0]  rs2,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3
  );
    enc_store = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
  endfunction

  function automatic logic [31:0] enc_csr(
    input logic [11:0] csr,
    input logic [4:0]  rs1_zimm,
    input logic [2:0]  funct3,
    input logic [4:0]  rd
  );
    enc_csr = {csr, rs1_zimm, funct3, rd, 7'b1110011};
  endfunction

  function automatic logic [31:0] mem_read_data(input logic [31:0] addr);
    begin
      unique case (addr)
        32'h0000_0300: mem_read_data = 32'h89AB_CDEF;
        32'h0000_0301: mem_read_data = 32'h4433_8022;
        32'h0000_0302: mem_read_data = 32'h0080_2211;
        32'h0000_03F0: mem_read_data = 32'hBAD0_0BAD;
        default:       mem_read_data = 32'h0000_0000;
      endcase
    end
  endfunction

  function automatic logic mem_read_error(
    input logic [31:0] addr,
    input logic        valid,
    input logic        write
  );
    begin
      mem_read_error = valid && !write && (addr == 32'h0000_03F0);
    end
  endfunction

  // Data-memory model with a default zero-wait mode and a registered response
  // mode used by directed wait-state coverage.
  always_comb begin
    dmem_req_ready = mem_req_ready_en && (mem_zero_wait || !mem_rsp_pending_q);
    dmem_rsp_valid = mem_zero_wait ? (dmem_req_valid && dmem_req_ready) :
                                     mem_rsp_pending_q;
    dmem_rsp_rdata = mem_zero_wait ? mem_read_data(dmem_req_addr) :
                                     mem_rsp_data_q;
    dmem_rsp_err = mem_zero_wait ? mem_read_error(dmem_req_addr,
                                                  dmem_req_valid,
                                                  dmem_req_write) :
                                   mem_rsp_err_q;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem_rsp_pending_q <= 1'b0;
      mem_rsp_data_q <= 32'h0000_0000;
      mem_rsp_err_q <= 1'b0;
    end else if (!mem_zero_wait) begin
      if (mem_rsp_pending_q && dmem_rsp_ready) begin
        mem_rsp_pending_q <= 1'b0;
      end
      if (dmem_req_valid && dmem_req_ready) begin
        mem_rsp_pending_q <= 1'b1;
        mem_rsp_data_q <= mem_read_data(dmem_req_addr);
        mem_rsp_err_q <= mem_read_error(dmem_req_addr, dmem_req_valid,
                                        dmem_req_write);
      end
    end else begin
      mem_rsp_pending_q <= 1'b0;
      mem_rsp_data_q <= 32'h0000_0000;
      mem_rsp_err_q <= 1'b0;
    end
  end

  // Drive one frontend stream beat before the next active edge and check the
  // expected stream PC after the edge. Redirect tests override exp_next_pc.
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
        $fatal(1, "fetch handshake not ready for instr %08x", t_instr);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_next_pc;
      pc_count++;
    end
  endtask

  // Execute one injected instruction without leaving Debug Mode. This task
  // checks request/response handshakes, response backpressure, frontend/DPC
  // isolation, optional register commit, and optional LSU request formatting.
  task automatic debug_exec_instr(
    input string       name,
    input logic [31:0] exec_instr,
    input logic [1:0]  exec_index,
    input logic        exp_error,
    input logic        exp_commit,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_data,
    input logic        exp_mem_req,
    input logic        exp_mem_write,
    input logic [31:0] exp_mem_addr,
    input logic        hold_response
  );
    logic [31:0] saved_dpc;
    logic        saw_commit;
    logic        saw_mem_req;
    begin
      saved_dpc = core_debug.dpc;
      saw_commit = 1'b0;
      saw_mem_req = 1'b0;

      @(negedge clk);
      core_debug.exec_req_valid = 1'b1;
      core_debug.exec_req_instr = exec_instr;
      core_debug.exec_req_index = exec_index;
      core_debug.exec_rsp_ready = !hold_response;
      #1;
      if (!core_debug.exec_req_ready) begin
        $fatal(1, "%s execution request not ready", name);
      end

      @(posedge clk);
      #1;
      if (!core_debug.halted || core_debug.running || instr_ready) begin
        $fatal(1, "%s left halted state on request", name);
      end
      @(negedge clk);
      core_debug.exec_req_valid = 1'b0;

      for (int unsigned tries = 0; tries < 16; tries++) begin
        @(posedge clk);
        #1;
        if (!core_debug.halted || core_debug.running || instr_ready ||
            (core_debug.dpc !== saved_dpc)) begin
          $fatal(1, "%s debug isolation mismatch halted=%0b running=%0b ready=%0b dpc=%08x exp_dpc=%08x",
                 name, core_debug.halted, core_debug.running, instr_ready,
                 core_debug.dpc, saved_dpc);
        end
        if (redirect_valid || trap_valid || illegal || lsu_fault) begin
          $fatal(1, "%s leaked architectural error/redirect redir=%0b trap=%0b illegal=%0b lsu_fault=%0b",
                 name, redirect_valid, trap_valid, illegal, lsu_fault);
        end
        if (commit_valid) begin
          if (!exp_commit || saw_commit || (commit_rd !== exp_rd) ||
              (commit_data !== exp_data)) begin
            $fatal(1, "%s commit mismatch valid=%0b rd=%0d data=%08x exp_valid=%0b exp_rd=%0d exp_data=%08x",
                   name, commit_valid, commit_rd, commit_data, exp_commit,
                   exp_rd, exp_data);
          end
          saw_commit = 1'b1;
        end
        if (dmem_req_valid && dmem_req_ready) begin
          if (!exp_mem_req || saw_mem_req ||
              (dmem_req_write !== exp_mem_write) ||
              (dmem_req_addr !== exp_mem_addr)) begin
            $fatal(1, "%s memory request mismatch write=%0b addr=%08x exp_req=%0b exp_write=%0b exp_addr=%08x",
                   name, dmem_req_write, dmem_req_addr, exp_mem_req,
                   exp_mem_write, exp_mem_addr);
          end
          saw_mem_req = 1'b1;
        end

        if (core_debug.exec_rsp_valid) begin
          if (core_debug.exec_rsp_error !== exp_error ||
              (saw_commit !== exp_commit) ||
              (saw_mem_req !== exp_mem_req)) begin
            $fatal(1, "%s response mismatch err=%0b commit=%0b mem=%0b exp_err=%0b exp_commit=%0b exp_mem=%0b",
                   name, core_debug.exec_rsp_error, saw_commit, saw_mem_req,
                   exp_error, exp_commit, exp_mem_req);
          end
          if (core_debug.exec_req_ready) begin
            $fatal(1, "%s accepted a second request with response pending", name);
          end

          if (hold_response) begin
            // A resume request cannot escape Debug Mode while completion is
            // still owned by the DM and has not handshaken.
            core_debug.resume_req = 1'b1;
            repeat (2) begin
              @(posedge clk);
              #1;
              if (!core_debug.exec_rsp_valid ||
                  (core_debug.exec_rsp_error !== exp_error) ||
                  !core_debug.halted || instr_ready ||
                  (core_debug.dpc !== saved_dpc)) begin
                $fatal(1, "%s response changed under backpressure", name);
              end
            end
            @(negedge clk);
            core_debug.resume_req = 1'b0;
            core_debug.exec_rsp_ready = 1'b1;
          end

          @(posedge clk);
          #1;
          if (core_debug.exec_rsp_valid) begin
            $fatal(1, "%s execution response did not clear", name);
          end
          pass_count++;
          debug_count++;
          debug_exec_count++;
          return;
        end
      end
      $fatal(1, "%s execution response timed out", name);
    end
  endtask

  task automatic drive_instr(input logic [31:0] t_instr);
    begin
      drive_instr_expect_next(t_instr, exp_fetch_pc + 32'd4);
    end
  endtask

  task automatic expect_commit(
    input string       name,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_data
  );
    begin
      #1;
      if (!commit_valid || (commit_rd !== exp_rd) || (commit_data !== exp_data)) begin
        $fatal(1, "%s commit mismatch got valid=%0b rd=%0d data=%08x exp rd=%0d data=%08x",
               name, commit_valid, commit_rd, commit_data, exp_rd, exp_data);
      end
      pass_count++;
      commit_count++;
    end
  endtask

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

  task automatic expect_store_req(
    input string       name,
    input logic [31:0] exp_addr,
    input logic [1:0]  exp_size,
    input logic [31:0] exp_wdata,
    input logic [3:0]  exp_wstrb
  );
    begin
      #1;
      if (!dmem_req_valid || !dmem_req_write || (dmem_req_addr !== exp_addr) ||
          (dmem_req_size !== exp_size) || (dmem_req_wdata !== exp_wdata) ||
          (dmem_req_wstrb !== exp_wstrb)) begin
        $fatal(1, "%s store mismatch valid=%0b write=%0b addr=%08x size=%0d wdata=%08x wstrb=%b",
               name, dmem_req_valid, dmem_req_write, dmem_req_addr,
               dmem_req_size, dmem_req_wdata, dmem_req_wstrb);
      end
      store_count++;
    end
  endtask

  task automatic expect_lsu_fault(
    input string name,
    input logic  exp_req_valid
  );
    begin
      #1;
      if (commit_valid || (dmem_req_valid !== exp_req_valid) || !lsu_fault) begin
        $fatal(1, "%s lsu fault mismatch commit=%0b req=%0b fault=%0b",
               name, commit_valid, dmem_req_valid, lsu_fault);
      end
      pass_count++;
      suppress_count++;
      lsu_fault_count++;
    end
  endtask

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
        $fatal(1, "%s trap redirect mismatch ex_valid=%0b", name, ex_valid);
      end
      pass_count++;
      trap_count++;
      redirect_count++;
    end
  endtask

  task automatic expect_irq_redirect(
    input string       name,
    input logic [4:0]  exp_cause,
    input logic [31:0] exp_pc,
    input logic [31:0] exp_target
  );
    begin
      #1;
      if (!trap_valid || !trap_interrupt || (trap_cause !== exp_cause) ||
          (trap_tval !== 32'h0000_0000) || (trap_pc !== exp_pc) ||
          instr_ready || !redirect_valid || (redirect_pc !== exp_target)) begin
        $fatal(1, "%s irq mismatch valid=%0b intr=%0b cause=%0d tval=%08x pc=%08x ready=%0b redir=%0b target=%08x",
               name, trap_valid, trap_interrupt, trap_cause, trap_tval,
               trap_pc, instr_ready, redirect_valid, redirect_pc);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_target;
      if (ex_valid) begin
        $fatal(1, "%s irq redirect mismatch ex_valid=%0b", name, ex_valid);
      end
      pass_count++;
      trap_count++;
      irq_count++;
      redirect_count++;
    end
  endtask

  task automatic expect_mret_redirect(
    input string       name,
    input logic [31:0] exp_target
  );
    begin
      #1;
      if (!mret_taken || trap_valid || instr_ready ||
          !redirect_valid || (redirect_pc !== exp_target)) begin
        $fatal(1, "%s mret mismatch mret=%0b trap_valid=%0b ready=%0b redir=%0b target=%08x",
               name, mret_taken, trap_valid, instr_ready, redirect_valid, redirect_pc);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_target;
      if (ex_valid) begin
        $fatal(1, "%s mret redirect mismatch ex_valid=%0b", name, ex_valid);
      end
      pass_count++;
      trap_count++;
      redirect_count++;
    end
  endtask

  task automatic expect_redirect_flush(
    input string       name,
    input logic [31:0] exp_target
  );
    begin
      #1;
      if (instr_ready || !redirect_valid || (redirect_pc !== exp_target)) begin
        $fatal(1, "%s redirect did not block instruction stream acceptance", name);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_target;
      if (ex_valid) begin
        $fatal(1, "%s redirect flush mismatch ex_valid=%0b", name, ex_valid);
      end
      pass_count++;
      redirect_count++;
    end
  endtask

  task automatic expect_load_use_stall(
    input string       name,
    input logic [31:0] held_pc
  );
    begin
      @(negedge clk);
      #1;
      if (!hazard_load_use || instr_ready || (exp_fetch_pc !== held_pc)) begin
        $fatal(1, "%s load-use stall mismatch hazard=%0b ready=%0b pc=%08x exp_pc=%08x",
               name, hazard_load_use, instr_ready, exp_fetch_pc, held_pc);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = held_pc;
      if (ex_valid) begin
        $fatal(1, "%s load-use bubble mismatch ex_valid=%0b", name, ex_valid);
      end
      pass_count++;
      hazard_count++;
    end
  endtask

  task automatic expect_dmem_wait_then_commit(
    input string       name,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_data
  );
    begin
      #1;
      if (!dmem_req_valid || !dmem_req_ready || dmem_rsp_valid ||
          instr_ready || commit_valid) begin
        $fatal(1, "%s wait-start mismatch req_v=%0b req_r=%0b rsp_v=%0b instr_ready=%0b commit=%0b",
               name, dmem_req_valid, dmem_req_ready, dmem_rsp_valid,
               instr_ready, commit_valid);
      end
      @(posedge clk);
      #1;
      if (!dmem_rsp_valid || !dmem_rsp_ready || !commit_valid ||
          (commit_rd !== exp_rd) || (commit_data !== exp_data)) begin
        $fatal(1, "%s wait-complete mismatch rsp_v=%0b rsp_r=%0b commit=%0b rd=%0d data=%08x",
               name, dmem_rsp_valid, dmem_rsp_ready, commit_valid,
               commit_rd, commit_data);
      end
      pass_count++;
      commit_count++;
      load_count++;
      dmem_wait_count++;
      @(posedge clk);
      #1;
      if (!instr_ready || dmem_rsp_valid || dmem_req_valid) begin
        $fatal(1, "%s wait-release mismatch instr_ready=%0b req_v=%0b rsp_v=%0b",
               name, instr_ready, dmem_req_valid, dmem_rsp_valid);
      end
    end
  endtask

  task automatic expect_dmem_backpressure_then_commit(
    input string       name,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_data
  );
    begin
      #1;
      if (!dmem_req_valid || dmem_req_ready || dmem_rsp_valid ||
          instr_ready || commit_valid) begin
        $fatal(1, "%s backpressure-start mismatch req_v=%0b req_r=%0b rsp_v=%0b instr_ready=%0b commit=%0b",
               name, dmem_req_valid, dmem_req_ready, dmem_rsp_valid,
               instr_ready, commit_valid);
      end
      mem_req_ready_en = 1'b1;
      @(posedge clk);
      #1;
      if (!dmem_rsp_valid || !dmem_rsp_ready || !commit_valid ||
          (commit_rd !== exp_rd) || (commit_data !== exp_data)) begin
        $fatal(1, "%s backpressure-complete mismatch rsp_v=%0b rsp_r=%0b commit=%0b rd=%0d data=%08x",
               name, dmem_rsp_valid, dmem_rsp_ready, commit_valid,
               commit_rd, commit_data);
      end
      pass_count++;
      commit_count++;
      load_count++;
      dmem_wait_count++;
      dmem_bp_count++;
      @(posedge clk);
      #1;
      if (!instr_ready || dmem_rsp_valid || dmem_req_valid) begin
        $fatal(1, "%s backpressure-release mismatch instr_ready=%0b req_v=%0b rsp_v=%0b",
               name, instr_ready, dmem_req_valid, dmem_rsp_valid);
      end
    end
  endtask

  // Request Debug Mode, wait for the pipeline to drain, and verify the public
  // halted/running status plus frontend backpressure seen by integration logic.
  task automatic debug_enter_halt(input string name);
    begin
      @(negedge clk);
      instr_valid = 1'b0;
      core_debug.halt_req = 1'b1;
      for (int unsigned tries = 0; tries < 20; tries++) begin
        @(posedge clk);
        #1;
        if (core_debug.halted) begin
          if (core_debug.running || instr_ready) begin
            $fatal(1, "%s halted status mismatch running=%0b ready=%0b",
                   name, core_debug.running, instr_ready);
          end
          @(posedge clk);
          #1;
          if (core_debug.dpc !== exp_fetch_pc) begin
            $fatal(1, "%s DPC mismatch dpc=%08x exp=%08x",
                   name, core_debug.dpc, exp_fetch_pc);
          end
          pass_count++;
          debug_count++;
          return;
        end
      end
      $fatal(1, "%s did not halt", name);
    end
  endtask

  // Issue one halted-core GPR read through the debug interface and check the
  // registered response returned to the Debug Module side.
  task automatic debug_read_gpr(
    input string       name,
    input logic [4:0]  addr,
    input logic [31:0] exp_data
  );
    begin
      @(negedge clk);
      core_debug.gpr_req_valid = 1'b1;
      core_debug.gpr_req_write = 1'b0;
      core_debug.gpr_req_addr = addr;
      core_debug.gpr_req_wdata = 32'h0000_0000;
      core_debug.gpr_rsp_ready = 1'b1;
      #1;
      if (!core_debug.gpr_req_ready) begin
        $fatal(1, "%s read request not ready", name);
      end
      @(posedge clk);
      #1;
      if (!core_debug.gpr_rsp_valid ||
          (core_debug.gpr_rsp_rdata !== exp_data) ||
          core_debug.gpr_rsp_err) begin
        $fatal(1, "%s read response mismatch valid=%0b data=%08x err=%0b exp=%08x",
               name, core_debug.gpr_rsp_valid, core_debug.gpr_rsp_rdata,
               core_debug.gpr_rsp_err, exp_data);
      end
      core_debug.gpr_req_valid = 1'b0;
      @(posedge clk);
      #1;
      if (core_debug.gpr_rsp_valid) begin
        $fatal(1, "%s read response did not clear", name);
      end
      pass_count++;
      debug_count++;
    end
  endtask

  // Issue one halted-core GPR write and verify the write response handshake.
  task automatic debug_write_gpr(
    input string       name,
    input logic [4:0]  addr,
    input logic [31:0] data
  );
    begin
      @(negedge clk);
      core_debug.gpr_req_valid = 1'b1;
      core_debug.gpr_req_write = 1'b1;
      core_debug.gpr_req_addr = addr;
      core_debug.gpr_req_wdata = data;
      core_debug.gpr_rsp_ready = 1'b1;
      #1;
      if (!core_debug.gpr_req_ready) begin
        $fatal(1, "%s write request not ready", name);
      end
      @(posedge clk);
      #1;
      if (!core_debug.gpr_rsp_valid || core_debug.gpr_rsp_err) begin
        $fatal(1, "%s write response mismatch valid=%0b err=%0b",
               name, core_debug.gpr_rsp_valid, core_debug.gpr_rsp_err);
      end
      core_debug.gpr_req_valid = 1'b0;
      @(posedge clk);
      #1;
      if (core_debug.gpr_rsp_valid) begin
        $fatal(1, "%s write response did not clear", name);
      end
      pass_count++;
      debug_count++;
    end
  endtask

  // Release one instruction from Debug Mode, verify it retires, and confirm
  // the core returns to halted state with DPC advanced to the next stream PC.
  task automatic debug_single_step_addi(
    input string       name,
    input logic [4:0]  rd,
    input logic [11:0] imm,
    input logic [31:0] exp_data
  );
    begin
      @(negedge clk);
      core_debug.halt_req = 1'b0;
      core_debug.resume_req = 1'b1;
      core_debug.step_req = 1'b1;
      @(posedge clk);
      #1;
      core_debug.resume_req = 1'b0;
      core_debug.step_req = 1'b0;
      if (!core_debug.running || core_debug.halted || !instr_ready) begin
        $fatal(1, "%s step release mismatch running=%0b halted=%0b ready=%0b",
               name, core_debug.running, core_debug.halted, instr_ready);
      end

      drive_instr(enc_i(imm, 5'd0, 3'b000, rd));
      @(negedge clk);
      instr_valid = 1'b0;
      instr = 32'h0000_0013;
      instr_fault = 1'b0;
      @(posedge clk);
      expect_commit(name, rd, exp_data);
      alu_i_count++;

      for (int unsigned tries = 0; tries < 8; tries++) begin
        @(posedge clk);
        #1;
        if (core_debug.halted) begin
          if (core_debug.running || instr_ready) begin
            $fatal(1, "%s rehalt status mismatch running=%0b ready=%0b",
                   name, core_debug.running, instr_ready);
          end
          @(posedge clk);
          #1;
          if (core_debug.dpc !== exp_fetch_pc) begin
            $fatal(1, "%s rehalt DPC mismatch dpc=%08x exp=%08x",
                   name, core_debug.dpc, exp_fetch_pc);
          end
          pass_count++;
          debug_count++;
          return;
        end
      end
      $fatal(1, "%s did not re-enter halt after step", name);
    end
  endtask

  // Resume normal execution from Debug Mode and verify running status returns.
  task automatic debug_resume(input string name);
    begin
      @(negedge clk);
      core_debug.halt_req = 1'b0;
      core_debug.resume_req = 1'b1;
      @(posedge clk);
      #1;
      core_debug.resume_req = 1'b0;
      if (core_debug.halted || !core_debug.running) begin
        $fatal(1, "%s resume status mismatch halted=%0b running=%0b",
               name, core_debug.halted, core_debug.running);
      end
      pass_count++;
      debug_count++;
    end
  endtask

  // Enable one execute-address trigger at the next frontend PC and verify the
  // matched instruction is redirected into Debug Mode before retirement.
  task automatic debug_trigger_breakpoint(input string name);
    logic [31:0] match_pc;
    begin
      match_pc = exp_fetch_pc;
      @(negedge clk);
      core_debug.trigger_execute_addr = '0;
      core_debug.trigger_execute_valid = '0;
      core_debug.trigger_load_valid = '0;
      core_debug.trigger_store_valid = '0;
      core_debug.trigger_data_addr = '0;
      core_debug.trigger_execute_addr[0] = match_pc;
      core_debug.trigger_execute_valid[0] = 1'b1;

      drive_instr(enc_i(12'd7, 5'd0, 3'b000, 5'd13));
      #1;
      if (!redirect_valid || (redirect_pc !== match_pc) || instr_ready ||
          commit_valid) begin
        $fatal(1, "%s trigger redirect mismatch redir=%0b pc=%08x ready=%0b commit=%0b exp=%08x",
               name, redirect_valid, redirect_pc, instr_ready, commit_valid,
               match_pc);
      end
      exp_fetch_pc = match_pc;
      @(negedge clk);
      instr_valid = 1'b0;

      for (int unsigned tries = 0; tries < 10; tries++) begin
        @(posedge clk);
        #1;
        if (commit_valid) begin
          $fatal(1, "%s trigger allowed matched instruction to retire rd=%0d data=%08x",
                 name, commit_rd, commit_data);
        end
        if (core_debug.halted) begin
          if (core_debug.running || instr_ready ||
              (core_debug.dpc !== match_pc) ||
              (core_debug.dcsr_cause !== 3'd2)) begin
            $fatal(1, "%s trigger halt mismatch running=%0b ready=%0b dpc=%08x cause=%0d exp_pc=%08x",
                   name, core_debug.running, instr_ready, core_debug.dpc,
                   core_debug.dcsr_cause, match_pc);
          end
          core_debug.trigger_execute_valid = '0;
          pass_count++;
          debug_count++;
          trigger_count++;
          return;
        end
      end
      $fatal(1, "%s did not halt on trigger", name);
    end
  endtask

  // Check the common precise data-trigger entry contract after a matched load
  // or store reaches EX. No memory or architectural side effect is permitted.
  task automatic wait_for_data_trigger_halt(
    input string       name,
    input logic [31:0] match_pc
  );
    begin
      #1;
      if (!redirect_valid || (redirect_pc !== match_pc) || instr_ready ||
          dmem_req_valid || commit_valid || trap_valid || lsu_fault) begin
        $fatal(1, "%s precise trigger mismatch redir=%0b pc=%08x ready=%0b req=%0b commit=%0b trap=%0b fault=%0b exp_pc=%08x",
               name, redirect_valid, redirect_pc, instr_ready, dmem_req_valid,
               commit_valid, trap_valid, lsu_fault, match_pc);
      end
      exp_fetch_pc = match_pc;
      @(negedge clk);
      instr_valid = 1'b0;

      for (int unsigned tries = 0; tries < 10; tries++) begin
        @(posedge clk);
        #1;
        if (dmem_req_valid || commit_valid || trap_valid || lsu_fault) begin
          $fatal(1, "%s produced a side effect while entering Debug Mode", name);
        end
        if (core_debug.halted) begin
          if (core_debug.running || instr_ready ||
              (core_debug.dpc !== match_pc) ||
              (core_debug.dcsr_cause !== 3'd2)) begin
            $fatal(1, "%s halt mismatch running=%0b ready=%0b dpc=%08x cause=%0d exp_pc=%08x",
                   name, core_debug.running, instr_ready, core_debug.dpc,
                   core_debug.dcsr_cause, match_pc);
          end
          core_debug.trigger_load_valid = '0;
          core_debug.trigger_store_valid = '0;
          pass_count++;
          debug_count++;
          trigger_count++;
          return;
        end
      end
      $fatal(1, "%s did not halt on data trigger", name);
    end
  endtask

  // Prove load-only qualification, precise suppression, and one normal load
  // execution after clearing the trigger and resuming from DPC.
  task automatic debug_load_trigger(input string name);
    logic [31:0] match_pc;
    begin
      @(negedge clk);
      core_debug.trigger_execute_valid = '0;
      core_debug.trigger_load_valid = '0;
      core_debug.trigger_store_valid = '0;
      core_debug.trigger_data_addr = '0;
      core_debug.trigger_data_addr[0] = 32'h0000_0300;
      core_debug.trigger_load_valid[0] = 1'b1;

      // A load to another address must execute normally while the trigger is armed.
      drive_instr(enc_load(12'h304, 5'd0, 3'b010, 5'd14));
      drive_instr(32'h0000_0013);
      expect_commit({name, " address isolation"}, 5'd14, 32'h0000_0000);
      if (redirect_valid || trap_valid || lsu_fault) begin
        $fatal(1, "%s load trigger matched a different address", name);
      end
      load_count++;

      // A load-only trigger must not match a store to the same address.
      drive_instr(enc_store(12'h300, 5'd13, 5'd0, 3'b010));
      drive_instr(32'h0000_0013);
      expect_store_req({name, " store isolation"}, 32'h0000_0300,
                       MEM_SIZE_WORD, 32'h0000_0007, 4'b1111);
      if (redirect_valid || trap_valid || lsu_fault || commit_valid) begin
        $fatal(1, "%s load-only trigger matched store", name);
      end
      pass_count++;

      match_pc = exp_fetch_pc;
      drive_instr(enc_load(12'h300, 5'd0, 3'b010, 5'd14));
      drive_instr(32'h0000_0013);
      wait_for_data_trigger_halt({name, " precise halt"}, match_pc);
      load_trigger_count++;

      debug_resume({name, " resume"});
      drive_instr(enc_load(12'h300, 5'd0, 3'b010, 5'd14));
      drive_instr(32'h0000_0013);
      expect_commit({name, " resumed load"}, 5'd14, 32'h89AB_CDEF);
      load_count++;
    end
  endtask

  // Prove store-only qualification, precise write suppression, and one normal
  // store request after clearing the trigger and resuming from DPC.
  task automatic debug_store_trigger(input string name);
    logic [31:0] match_pc;
    begin
      @(negedge clk);
      core_debug.trigger_execute_valid = '0;
      core_debug.trigger_load_valid = '0;
      core_debug.trigger_store_valid = '0;
      core_debug.trigger_data_addr = '0;
      core_debug.trigger_data_addr[0] = 32'h0000_0304;
      core_debug.trigger_store_valid[0] = 1'b1;

      // A store to another address must execute normally while the trigger is armed.
      drive_instr(enc_store(12'h308, 5'd13, 5'd0, 3'b010));
      drive_instr(32'h0000_0013);
      expect_store_req({name, " address isolation"}, 32'h0000_0308,
                       MEM_SIZE_WORD, 32'h0000_0007, 4'b1111);
      if (redirect_valid || trap_valid || lsu_fault || commit_valid) begin
        $fatal(1, "%s store trigger matched a different address", name);
      end
      pass_count++;

      // A store-only trigger must not match a load to the same address.
      drive_instr(enc_load(12'h304, 5'd0, 3'b010, 5'd14));
      drive_instr(32'h0000_0013);
      expect_commit({name, " load isolation"}, 5'd14, 32'h0000_0000);
      if (redirect_valid || trap_valid || lsu_fault || dmem_req_write) begin
        $fatal(1, "%s store-only trigger matched load", name);
      end
      load_count++;

      match_pc = exp_fetch_pc;
      drive_instr(enc_store(12'h304, 5'd13, 5'd0, 3'b010));
      drive_instr(32'h0000_0013);
      wait_for_data_trigger_halt({name, " precise halt"}, match_pc);
      store_trigger_count++;

      debug_resume({name, " resume"});
      drive_instr(enc_store(12'h304, 5'd13, 5'd0, 3'b010));
      drive_instr(32'h0000_0013);
      expect_store_req({name, " resumed store"}, 32'h0000_0304,
                       MEM_SIZE_WORD, 32'h0000_0007, 4'b1111);
      if (redirect_valid || trap_valid || lsu_fault || commit_valid) begin
        $fatal(1, "%s resumed store side-effect mismatch", name);
      end
      pass_count++;
    end
  endtask

  // Trigger entry has priority over the local alignment exception. Once the
  // trigger is cleared, resuming the same instruction must expose the original
  // architectural load-misaligned trap.
  task automatic debug_misaligned_load_trigger(input string name);
    logic [31:0] match_pc;
    begin
      @(negedge clk);
      core_debug.trigger_execute_valid = '0;
      core_debug.trigger_load_valid = '0;
      core_debug.trigger_store_valid = '0;
      core_debug.trigger_data_addr = '0;
      core_debug.trigger_data_addr[0] = 32'h0000_0301;
      core_debug.trigger_load_valid[0] = 1'b1;

      match_pc = exp_fetch_pc;
      drive_instr(enc_load(12'h301, 5'd0, 3'b010, 5'd15));
      drive_instr(32'h0000_0013);
      wait_for_data_trigger_halt({name, " precise halt"}, match_pc);
      load_trigger_count++;

      debug_resume({name, " resume"});
      drive_instr(enc_load(12'h301, 5'd0, 3'b010, 5'd15));
      drive_instr(32'h0000_0013);
      expect_trap_redirect({name, " resumed misalignment"},
                           TRAP_CAUSE_LOAD_MISALIGNED, 32'h0000_0301,
                           match_pc, 32'h0000_0200);
    end
  endtask

  initial begin
    pass_count = 0;
    commit_count = 0;
    alu_i_count = 0;
    alu_r_count = 0;
    upper_count = 0;
    link_count = 0;
    branch_count = 0;
    redirect_count = 0;
    load_count = 0;
    store_count = 0;
    lsu_fault_count = 0;
    dmem_wait_count = 0;
    dmem_bp_count = 0;
    csr_count = 0;
    trap_count = 0;
    irq_count = 0;
    hazard_count = 0;
    suppress_count = 0;
    pc_count = 0;
    debug_count = 0;
    debug_exec_count = 0;
    trigger_count = 0;
    load_trigger_count = 0;
    store_trigger_count = 0;

    exp_fetch_pc = 32'h0001_0000;
    rst_n = 1'b0;
    instr_valid = 1'b0;
    instr_pc = exp_fetch_pc;
    instr = 32'h0000_0013;
    instr_fault = 1'b0;
    mem_zero_wait = 1'b1;
    mem_req_ready_en = 1'b1;
    saved_ecall_pc = 32'h0000_0000;
    timer_irq = 1'b0;
    external_irq = 1'b0;
    core_debug.halt_req = 1'b0;
    core_debug.resume_req = 1'b0;
    core_debug.step_req = 1'b0;
    core_debug.trigger_execute_valid = '0;
    core_debug.trigger_execute_addr = '0;
    core_debug.trigger_load_valid = '0;
    core_debug.trigger_store_valid = '0;
    core_debug.trigger_data_addr = '0;
    core_debug.gpr_req_valid = 1'b0;
    core_debug.gpr_req_write = 1'b0;
    core_debug.gpr_req_addr = 5'd0;
    core_debug.gpr_req_wdata = 32'h0000_0000;
    core_debug.gpr_rsp_ready = 1'b1;
    core_debug.exec_req_valid = 1'b0;
    core_debug.exec_req_instr = 32'h0000_0013;
    core_debug.exec_req_index = 2'd0;
    core_debug.exec_rsp_ready = 1'b1;

    repeat (2) @(posedge clk);
    #1;
    if (ex_valid || commit_valid) begin
      $fatal(1, "reset state mismatch");
    end
    rst_n = 1'b1;

    // Fill the two-stage pipe. The first fetched ADDI reaches execute after
    // two accepted responses.
    drive_instr(enc_i(12'd5, 5'd0, 3'b000, 5'd1));  // addi x1,x0,5
    drive_instr(enc_i(12'd3, 5'd1, 3'b000, 5'd2));  // addi x2,x1,3
    expect_commit("addi x1", 5'd1, 32'd5);
    alu_i_count++;

    drive_instr(enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3)); // add x3,x1,x2
    expect_commit("addi x2", 5'd2, 32'd8);
    alu_i_count++;

    drive_instr(enc_r(7'b0100000, 5'd1, 5'd3, 3'b000, 5'd4)); // sub x4,x3,x1
    expect_commit("add x3", 5'd3, 32'd13);
    alu_r_count++;

    drive_instr(enc_i(12'd0, 5'd4, 3'b110, 5'd5)); // ori x5,x4,0
    expect_commit("sub x4", 5'd4, 32'd8);
    alu_r_count++;

    drive_instr(enc_u(20'h12345, 5'd6, 7'b0110111)); // lui x6,0x12345
    expect_commit("ori x5", 5'd5, 32'd8);
    alu_i_count++;

    drive_instr(enc_u(20'h00002, 5'd7, 7'b0010111)); // auipc x7,0x2000
    expect_commit("lui x6", 5'd6, 32'h1234_5000);
    upper_count++;

    drive_instr(enc_jal(21'd8, 5'd8)); // jal x8,+8
    expect_commit("auipc x7", 5'd7, 32'h0001_2018);
    upper_count++;

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd0)); // fall-through, flushed
    expect_commit("jal x8", 5'd8, 32'h0001_0020);
    link_count++;
    expect_redirect_flush("initial jal redirect", ex_pc + 32'd8);

    drive_instr(enc_i(12'd2, 5'd0, 3'b000, 5'd0)); // x0 write suppressed
    expect_no_commit("initial jal redirect bubble");

    drive_instr(32'h0000_0013); // nop drain
    expect_no_commit("x0 suppress after redirect");

    drive_instr(32'h0000_0013); // nop drain
    expect_no_commit("nop suppress after redirect");

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd0)); // addi x0,x0,1, suppressed
    expect_no_commit("nop x0 drain");

    drive_instr(enc_i(12'd9, 5'd0, 3'b000, 5'd10)); // addi x10,x0,9
    expect_no_commit("x0 suppress");

    drive_instr(enc_i(12'd9, 5'd0, 3'b000, 5'd11)); // addi x11,x0,9
    expect_commit("addi x10", 5'd10, 32'd9);
    alu_i_count++;

    drive_instr(enc_branch(13'd16, 5'd11, 5'd10, 3'b000)); // beq x10,x11,+16
    expect_commit("addi x11", 5'd11, 32'd9);
    alu_i_count++;

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd12)); // fall-through, flushed
    expect_no_commit("taken beq no write");
    branch_count++;
    expect_redirect_flush("beq redirect", ex_pc + 32'd16);

    drive_instr(enc_i(12'd7, 5'd0, 3'b000, 5'd12)); // branch target addi
    expect_no_commit("beq redirect bubble");

    drive_instr(enc_i(12'd2, 5'd12, 3'b000, 5'd13)); // addi x13,x12,2
    expect_commit("target addi x12", 5'd12, 32'd7);
    alu_i_count++;

    drive_instr(enc_jal(21'd12, 5'd14)); // jal x14,+12
    expect_commit("target addi x13", 5'd13, 32'd9);
    alu_i_count++;

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd15)); // fall-through, flushed
    expect_commit("jal x14 redirect link", 5'd14, ex_pc + 32'd4);
    link_count++;
    expect_redirect_flush("jal redirect", ex_pc + 32'd12);

    drive_instr(enc_jalr(12'h104, 5'd0, 5'd16)); // jalr x16,x0,0x104
    expect_no_commit("jal redirect bubble");

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd17)); // fall-through, flushed
    expect_commit("jalr x16 redirect link", 5'd16, ex_pc + 32'd4);
    link_count++;
    expect_redirect_flush("jalr redirect", 32'h0000_0104);

    drive_instr(enc_i(12'd4, 5'd0, 3'b000, 5'd18)); // jalr target addi
    expect_no_commit("jalr redirect bubble");

    drive_instr(enc_branch(13'd8, 5'd18, 5'd17, 3'b000)); // beq x17,x18,+8 not taken
    expect_commit("jalr target addi x18", 5'd18, 32'd4);
    alu_i_count++;

    drive_instr(enc_i(12'd5, 5'd0, 3'b000, 5'd19)); // sequential after not-taken
    expect_no_commit("not-taken bne no write");
    branch_count++;

    drive_instr(enc_i(12'h300, 5'd0, 3'b000, 5'd20)); // addi x20,x0,0x300
    expect_commit("post branch addi x19", 5'd19, 32'd5);
    alu_i_count++;

    drive_instr(enc_load(12'd0, 5'd20, 3'b010, 5'd21)); // lw x21,0(x20)
    expect_commit("base addi x20", 5'd20, 32'h0000_0300);
    alu_i_count++;

    drive_instr(enc_load(12'd1, 5'd20, 3'b000, 5'd22)); // lb x22,1(x20)
    expect_commit("lw x21", 5'd21, 32'h89AB_CDEF);
    load_count++;

    drive_instr(enc_load(12'd2, 5'd20, 3'b100, 5'd23)); // lbu x23,2(x20)
    expect_commit("lb x22", 5'd22, 32'hFFFF_FF80);
    load_count++;

    drive_instr(enc_store(12'd4, 5'd21, 5'd20, 3'b010)); // sw x21,4(x20)
    expect_commit("lbu x23", 5'd23, 32'h0000_0080);
    load_count++;

    drive_instr(enc_store(12'd1, 5'd23, 5'd20, 3'b000)); // sb x23,1(x20)
    expect_store_req("sw x21", 32'h0000_0304, 2'd2, 32'h89AB_CDEF, 4'b1111);
    expect_no_commit("sw no commit");

    drive_instr(enc_load(12'd2, 5'd20, 3'b010, 5'd24)); // misaligned lw
    expect_store_req("sb x23", 32'h0000_0301, 2'd0, 32'h0000_8000, 4'b0010);
    expect_no_commit("sb no commit");

    drive_instr(32'h0000_0013); // fall-through, flushed by misaligned trap
    expect_trap_redirect("misaligned lw trap", TRAP_CAUSE_LOAD_MISALIGNED,
                         32'h0000_0302, ex_pc, 32'h0000_0000);

    drive_instr(enc_load(12'h0F0, 5'd20, 3'b010, 5'd25)); // memory error
    expect_no_commit("misaligned trap bubble");

    drive_instr(32'h0000_0013); // drain memory error load
    expect_lsu_fault("memory error lw", 1'b1);

    drive_instr(enc_load(12'd0, 5'd20, 3'b010, 5'd24)); // lw x24,0(x20)
    expect_no_commit("memory error drain");

    drive_instr(enc_r(7'b0000000, 5'd0, 5'd24, 3'b000, 5'd25)); // add x25,x24,x0
    expect_commit("hazard test lw x24", 5'd24, 32'h89AB_CDEF);
    load_count++;
    expect_load_use_stall("load-use x24->x25", exp_fetch_pc);

    drive_instr(32'h0000_0013); // drain dependent add
    expect_commit("load-use dependent add", 5'd25, 32'h89AB_CDEF);
    alu_r_count++;

    drive_instr(enc_i(12'h200, 5'd0, 3'b000, 5'd26)); // addi x26,x0,0x200
    expect_no_commit("load-use drain nop");

    mem_zero_wait = 1'b0;
    drive_instr(enc_load(12'd0, 5'd20, 3'b010, 5'd9)); // delayed lw x9,0(x20)
    expect_commit("delayed load setup x26", 5'd26, 32'h0000_0200);

    drive_instr(32'h0000_0013); // advance delayed load into EX
    expect_dmem_wait_then_commit("delayed lw x9", 5'd9, 32'h89AB_CDEF);

    mem_req_ready_en = 1'b0;
    drive_instr(enc_load(12'd0, 5'd20, 3'b010, 5'd10)); // ready-backpressured lw x10,0(x20)
    expect_no_commit("delayed load drain nop");

    drive_instr(32'h0000_0013); // advance backpressured load into EX
    expect_dmem_backpressure_then_commit("backpressured lw x10", 5'd10,
                                         32'h89AB_CDEF);
    mem_zero_wait = 1'b1;

    drive_instr(enc_csr(CSR_MSCRATCH, 5'd26, 3'b001, 5'd27)); // csrrw x27,mscratch,x26
    expect_no_commit("backpressured load drain nop");
    alu_i_count++;

    drive_instr(enc_csr(CSR_MSCRATCH, 5'd0, 3'b010, 5'd28)); // csrrs x28,mscratch,x0
    expect_commit("csrrw mscratch old", 5'd27, 32'h0000_0000);
    csr_count++;

    drive_instr(enc_csr(CSR_MTVEC, 5'd26, 3'b001, 5'd29)); // csrrw x29,mtvec,x26
    expect_commit("csrrs mscratch", 5'd28, 32'h0000_0200);
    csr_count++;

    drive_instr(32'h0000_0073); // ecall, trap to mtvec
    expect_commit("csrrw mtvec old", 5'd29, 32'h0000_0000);
    csr_count++;

    drive_instr(32'h0000_0013); // fall-through, flushed by trap
    saved_ecall_pc = ex_pc;
    expect_trap_redirect("ecall trap", TRAP_CAUSE_ECALL_MMODE, 32'h0000_0000,
                         saved_ecall_pc, 32'h0000_0200);

    drive_instr(enc_csr(CSR_MEPC, 5'd0, 3'b010, 5'd30)); // csrrs x30,mepc,x0
    expect_no_commit("ecall trap bubble");

    drive_instr(enc_csr(CSR_MCAUSE, 5'd0, 3'b010, 5'd31)); // csrrs x31,mcause,x0
    expect_commit("read mepc", 5'd30, saved_ecall_pc);
    csr_count++;

    drive_instr(32'h3020_0073); // mret
    expect_commit("read mcause", 5'd31, {27'h000_0000, TRAP_CAUSE_ECALL_MMODE});
    csr_count++;

    drive_instr(32'h0000_0013); // fall-through, flushed by mret
    expect_mret_redirect("mret redirect", saved_ecall_pc);

    drive_instr(enc_i(12'h7ff, 5'd0, 3'b000, 5'd26)); // addi x26,x0,0x7ff
    expect_no_commit("mret redirect bubble");

    drive_instr(enc_i(12'h089, 5'd26, 3'b000, 5'd26)); // addi x26,x26,0x89 -> 0x888
    expect_commit("irq enable base low", 5'd26, 32'h0000_07FF);
    alu_i_count++;

    drive_instr(enc_csr(CSR_MSTATUS, 5'd26, 3'b001, 5'd27)); // enable mstatus.MIE
    expect_commit("irq enable value", 5'd26, 32'h0000_0888);
    alu_i_count++;

    drive_instr(32'h0000_0013); // dependency gap before CSR reads x26
    expect_commit("write mstatus old", 5'd27, 32'h0000_1880);
    csr_count++;

    drive_instr(enc_csr(CSR_MIE, 5'd26, 3'b001, 5'd28)); // enable mie.MEIE/MTIE
    expect_no_commit("csr dependency gap nop");

    drive_instr(32'h0000_0013); // allow mie write to commit before IRQ
    expect_commit("write mie old", 5'd28, 32'h0000_0000);
    csr_count++;

    drive_instr(enc_csr(CSR_MSTATUS, 5'd0, 3'b010, 5'd29)); // read mstatus
    expect_no_commit("mie write drain nop");

    drive_instr(enc_csr(CSR_MIE, 5'd0, 3'b010, 5'd30)); // read mie
    expect_commit("read mstatus before irq", 5'd29, 32'h0000_1888);
    csr_count++;

    drive_instr(32'h0000_0013); // drain CSR read before IRQ
    expect_commit("read mie before irq", 5'd30, 32'h0000_0880);
    csr_count++;

    timer_irq = 1'b1;
    expect_irq_redirect("timer irq", TRAP_CAUSE_M_TIMER_IRQ, ex_pc, 32'h0000_0200);
    timer_irq = 1'b0;

    debug_enter_halt("debug halt after program");
    debug_single_step_addi("debug single-step addi", 5'd12, 12'h123,
                           32'h0000_0123);
    $display("tb_core_int_datapath phase debug_exec start=%0t", $time);
    debug_exec_instr("debug inject addi backpressure",
                     enc_i(12'd9, 5'd0, 3'b000, 5'd14), 2'd0,
                     1'b0, 1'b1, 5'd14, 32'd9,
                     1'b0, 1'b0, 32'h0000_0000, 1'b1);
    debug_exec_instr("debug inject lw",
                     enc_load(12'd0, 5'd20, 3'b010, 5'd15), 2'd1,
                     1'b0, 1'b1, 5'd15, 32'h89AB_CDEF,
                     1'b1, 1'b0, 32'h0000_0300, 1'b0);
    debug_exec_instr("debug inject sw",
                     enc_store(12'd4, 5'd14, 5'd20, 3'b010), 2'd2,
                     1'b0, 1'b0, 5'd0, 32'h0000_0000,
                     1'b1, 1'b1, 32'h0000_0304, 1'b0);
    debug_exec_instr("debug inject illegal", 32'hffff_ffff, 2'd3,
                     1'b1, 1'b0, 5'd0, 32'h0000_0000,
                     1'b0, 1'b0, 32'h0000_0000, 1'b0);
    debug_exec_instr("debug inject misaligned lw",
                     enc_load(12'h301, 5'd0, 3'b010, 5'd16), 2'd0,
                     1'b1, 1'b0, 5'd16, 32'h0000_0000,
                     1'b0, 1'b0, 32'h0000_0000, 1'b0);
    debug_exec_instr("debug inject control flow",
                     enc_jal(21'd8, 5'd17), 2'd1,
                     1'b1, 1'b0, 5'd17, 32'h0000_0000,
                     1'b0, 1'b0, 32'h0000_0000, 1'b0);
    debug_exec_instr("debug inject read preserved mcause",
                     enc_csr(CSR_MCAUSE, 5'd0, 3'b010, 5'd18), 2'd2,
                     1'b0, 1'b1, 5'd18,
                     {1'b1, 26'h000_0000, TRAP_CAUSE_M_TIMER_IRQ},
                     1'b0, 1'b0, 32'h0000_0000, 1'b0);
    debug_read_gpr("debug read injected x14", 5'd14, 32'h0000_0009);
    debug_read_gpr("debug read injected x15", 5'd15, 32'h89AB_CDEF);
    debug_read_gpr("debug read preserved mcause", 5'd18,
                   {1'b1, 26'h000_0000, TRAP_CAUSE_M_TIMER_IRQ});
    $display("tb_core_int_datapath phase debug_exec end=%0t", $time);
    debug_read_gpr("debug read stepped x12", 5'd12, 32'h0000_0123);
    debug_read_gpr("debug read x26", 5'd26, 32'h0000_0888);
    debug_write_gpr("debug write x10", 5'd10, 32'hCAFE_1234);
    debug_read_gpr("debug readback x10", 5'd10, 32'hCAFE_1234);
    debug_write_gpr("debug write x0 ignored", 5'd0, 32'hFFFF_FFFF);
    debug_read_gpr("debug read x0", 5'd0, 32'h0000_0000);
    debug_resume("debug resume");
    debug_trigger_breakpoint("debug execute trigger");
    debug_resume("debug trigger resume");
    drive_instr(enc_i(12'd7, 5'd0, 3'b000, 5'd13));
    drive_instr(32'h0000_0013);
    expect_commit("post-trigger addi x13", 5'd13, 32'd7);
    alu_i_count++;
    $display("tb_core_int_datapath phase data_trigger start=%0t", $time);
    debug_load_trigger("debug load trigger");
    $display("tb_core_int_datapath phase load_trigger end=%0t", $time);
    debug_store_trigger("debug store trigger");
    $display("tb_core_int_datapath phase store_trigger end=%0t", $time);
    debug_misaligned_load_trigger("debug misaligned load trigger");
    $display("tb_core_int_datapath phase data_trigger end=%0t", $time);

    if (commit_count < 8 || alu_i_count < 3 || alu_r_count < 2 ||
        upper_count < 2 || link_count < 3 || branch_count < 2 ||
        redirect_count < 4 || load_count < 3 || store_count < 2 ||
        lsu_fault_count < 1 || dmem_wait_count < 2 || dmem_bp_count < 1 ||
        csr_count < 9 || trap_count < 4 ||
        irq_count < 1 || hazard_count < 1 || suppress_count < 17 ||
        pc_count < 59 || debug_count < 27 || debug_exec_count < 7 ||
        trigger_count < 4 ||
        load_trigger_count < 2 || store_trigger_count < 1) begin
      $fatal(1, "coverage goal missed");
    end

    $display("tb_core_int_datapath phase complete=%0t", $time);
    $display("tb_core_int_datapath coverage: pass_count=%0d commit=%0d alu_i=%0d alu_r=%0d upper=%0d link=%0d branch=%0d redirect=%0d load=%0d store=%0d lsu_fault=%0d dmem_wait=%0d dmem_bp=%0d csr=%0d trap=%0d irq=%0d hazard=%0d suppress=%0d pc=%0d debug=%0d debug_exec=%0d trigger=%0d load_trigger=%0d store_trigger=%0d",
             pass_count, commit_count, alu_i_count, alu_r_count,
             upper_count, link_count, branch_count, redirect_count,
             load_count, store_count, lsu_fault_count, dmem_wait_count,
             dmem_bp_count, csr_count, trap_count, irq_count, hazard_count,
             suppress_count, pc_count, debug_count, debug_exec_count, trigger_count,
             load_trigger_count, store_trigger_count);
    $display("tb_core_int_datapath PASS");
    $finish;
  end
endmodule
