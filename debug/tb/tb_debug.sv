`timescale 1ns/1ps

// Self-checking integration testbench for the stage-1 debug top.
module tb_debug;
  import debug_dmi_pkg::*;

  localparam time CLK_PERIOD = 10ns;

  logic clk;                    // 100 MHz verification clock.
  logic rst_n;                  // Active-low test reset.
  debug_dmi_if dmi (.clk(clk), .rst_n(rst_n));
  debug_if core_debug (.clk(clk), .rst_n(rst_n));

  logic hart_reset_event;       // Simulated hart reset pulse.
  logic dmactive;               // Observed Debug Module active state.
  logic ndmreset;               // Observed non-debug reset request.

  int unsigned pass_count;
  int unsigned dmi_read_count;
  int unsigned dmi_write_count;
  int unsigned halt_count;
  int unsigned resume_count;
  int unsigned gpr_write_count;
  int unsigned gpr_read_count;
  int unsigned csr_read_count;
  int unsigned step_count;
  int unsigned error_count;
  int unsigned reset_count;
  int unsigned postexec_count;

  debug u_debug (
    .clk_i(clk),
    .rst_ni(rst_n),
    .dmi(dmi),
    .core_debug(core_debug),
    .hart_reset_event_i(hart_reset_event),
    .dmactive_o(dmactive),
    .ndmreset_o(ndmreset)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  function automatic logic [31:0] make_access_command(
    input logic [2:0] aarsize,
    input logic transfer,
    input logic write_value,
    input logic [15:0] regno
  );
    logic [31:0] value;
    begin
      value = '0;
      value[31:24] = ABSTRACT_CMD_ACCESS_REGISTER;
      value[22:20] = aarsize;
      value[17] = transfer;
      value[16] = write_value;
      value[15:0] = regno;
      make_access_command = value;
    end
  endfunction

  task automatic step_clock;
    begin
      @(posedge clk);
      #1ns;
    end
  endtask

  task automatic drive_idle;
    begin
      dmi.req_valid = 1'b0;
      dmi.req_op = DMI_OP_NOP;
      dmi.req_addr = '0;
      dmi.req_data = '0;
      dmi.rsp_ready = 1'b1;
      core_debug.halted = 1'b0;
      core_debug.running = 1'b1;
      core_debug.dpc = 32'h0000_0000;
      core_debug.dcsr_cause = ABSTRACT_DCSR_CAUSE_HALTREQ;
      core_debug.gpr_req_ready = 1'b0;
      core_debug.gpr_rsp_valid = 1'b0;
      core_debug.gpr_rsp_rdata = '0;
      core_debug.gpr_rsp_err = 1'b0;
      core_debug.mem_req_ready = 1'b0;
      core_debug.mem_rsp_valid = 1'b0;
      core_debug.mem_rsp_rdata = '0;
      core_debug.mem_rsp_err = 1'b0;
      core_debug.exec_req_ready = 1'b0;
      core_debug.exec_rsp_valid = 1'b0;
      core_debug.exec_rsp_error = 1'b0;
      hart_reset_event = 1'b0;
    end
  endtask

  task automatic apply_reset;
    begin
      drive_idle();
      rst_n = 1'b0;
      repeat (3) @(posedge clk);
      rst_n = 1'b1;
      step_clock();
      if (dmactive || ndmreset || core_debug.halt_req || core_debug.resume_req ||
          core_debug.step_req || dmi.rsp_valid || core_debug.gpr_req_valid ||
          core_debug.gpr_rsp_ready || core_debug.exec_req_valid ||
          core_debug.exec_rsp_ready) begin
        $error("reset integration state mismatch");
        $fatal(1);
      end
      reset_count++;
      pass_count++;
    end
  endtask

  // Accept one Program Buffer word from the integrated executor, apply
  // request and response backpressure, and return the requested core result.
  task automatic complete_exec_word(
    input logic [31:0] expected_instr,
    input logic [1:0]  expected_index,
    input logic        response_error,
    input string       label
  );
    int unsigned timeout;
    begin
      timeout = 0;
      while (!core_debug.exec_req_valid && timeout < 24) begin
        step_clock();
        timeout++;
      end
      if (!core_debug.exec_req_valid ||
          (core_debug.exec_req_instr !== expected_instr) ||
          (core_debug.exec_req_index !== expected_index)) begin
        $error("%s: execution request mismatch valid=%0b instr=%08x index=%0d",
               label, core_debug.exec_req_valid, core_debug.exec_req_instr,
               core_debug.exec_req_index);
        $fatal(1);
      end

      repeat (2) begin
        step_clock();
        if (!core_debug.exec_req_valid ||
            (core_debug.exec_req_instr !== expected_instr) ||
            (core_debug.exec_req_index !== expected_index)) begin
          $error("%s: execution request changed under backpressure", label);
          $fatal(1);
        end
      end

      @(negedge clk);
      core_debug.exec_req_ready = 1'b1;
      step_clock();
      core_debug.exec_req_ready = 1'b0;
      if (core_debug.exec_req_valid || !core_debug.exec_rsp_ready) begin
        $error("%s: executor did not enter response wait", label);
        $fatal(1);
      end

      repeat (2) begin
        step_clock();
        if (!core_debug.exec_rsp_ready || core_debug.exec_req_valid) begin
          $error("%s: execution response wait changed", label);
          $fatal(1);
        end
      end

      @(negedge clk);
      core_debug.exec_rsp_valid = 1'b1;
      core_debug.exec_rsp_error = response_error;
      step_clock();
      core_debug.exec_rsp_valid = 1'b0;
      core_debug.exec_rsp_error = 1'b0;
      pass_count++;
    end
  endtask

  // Program through DMI, dispatch postexec with and without a preceding GPR
  // transfer, and prove core execution errors become sticky abstract cmderr.
  task automatic check_postexec;
    logic [31:0] command_word;
    begin
      dmi_write(DMI_ADDR_PROGBUF0, 32'h0090_0713, "progbuf addi word 0");
      dmi_write(DMI_ADDR_PROGBUF1, 32'h0017_0713, "progbuf addi word 1");
      dmi_write(DMI_ADDR_PROGBUF2, PROGBUF_EBREAK_INSN, "progbuf terminator");
      dmi_write(DMI_ADDR_PROGBUF3, PROGBUF_EBREAK_INSN, "progbuf spare terminator");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0400_0002, 32'h1f00_000f,
               "advertise four-word program buffer");

      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 16'h0000);
      command_word[18] = 1'b1;
      dmi_write(DMI_ADDR_COMMAND, command_word, "postexec without transfer");
      complete_exec_word(32'h0090_0713, 2'd0, 1'b0, "postexec word 0");
      complete_exec_word(32'h0017_0713, 2'd1, 1'b0, "postexec word 1");
      wait_abstract_idle("postexec no-transfer idle");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0400_0002, 32'h1f00_1f0f,
               "postexec no-transfer clean");
      postexec_count++;

      dmi_write(DMI_ADDR_PROGBUF0, 32'h0000_0013, "postexec transfer nop");
      dmi_write(DMI_ADDR_PROGBUF1, PROGBUF_EBREAK_INSN,
                "postexec transfer terminator");
      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b1, 1'b0, ABSTRACT_GPR_BASE + 16'd6);
      command_word[18] = 1'b1;
      dmi_write(DMI_ADDR_COMMAND, command_word, "GPR read then postexec");
      repeat (2) begin
        step_clock();
        if (core_debug.exec_req_valid) begin
          $error("postexec started before GPR transfer completed");
          $fatal(1);
        end
      end
      complete_gpr_access(1'b0, 5'd6, 32'h0000_0000, 32'h6b6b_5678, 1'b0,
                          "complete x6 before postexec");
      complete_exec_word(32'h0000_0013, 2'd0, 1'b0,
                         "postexec after GPR read");
      wait_abstract_idle("GPR postexec idle");
      dmi_read(DMI_ADDR_DATA0, 32'h6b6b_5678, 32'hffff_ffff,
               "GPR postexec deferred data0");
      postexec_count++;

      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 16'h0000);
      command_word[18] = 1'b1;
      dmi_write(DMI_ADDR_COMMAND, command_word, "postexec core error");
      complete_exec_word(32'h0000_0013, 2'd0, 1'b1,
                         "postexec error word");
      wait_abstract_idle("postexec error idle");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0400_0302, 32'h1f00_1f0f,
               "postexec exception cmderr");
      dmi_write(DMI_ADDR_ABSTRACTCS, 32'h0000_0700,
                "clear postexec exception");
      postexec_count++;
      error_count++;
    end
  endtask

  task automatic dmi_transfer(
    input  logic [1:0] op,
    input  logic [DMI_ADDR_WIDTH-1:0] addr,
    input  logic [31:0] request_data,
    input  logic [1:0] expected_resp,
    input  logic [31:0] expected_data,
    input  logic [31:0] mask,
    input  string label
  );
    begin
      @(negedge clk);
      dmi.req_valid = 1'b1;
      dmi.req_op = op;
      dmi.req_addr = addr;
      dmi.req_data = request_data;
      while (!dmi.req_ready) @(negedge clk);
      step_clock();
      dmi.req_valid = 1'b0;
      if (!dmi.rsp_valid || (dmi.rsp_resp !== expected_resp) ||
          ((dmi.rsp_data & mask) !== (expected_data & mask))) begin
        $error("%s: DMI resp=%0b data=0x%08h expected_resp=%0b expected=0x%08h mask=0x%08h",
               label, dmi.rsp_resp, dmi.rsp_data, expected_resp, expected_data, mask);
        $fatal(1);
      end
      step_clock();
      if (dmi.rsp_valid) begin
        $error("%s: DMI response did not retire", label);
        $fatal(1);
      end
      if (op == DMI_OP_READ) dmi_read_count++;
      if (op == DMI_OP_WRITE) dmi_write_count++;
      pass_count++;
    end
  endtask

  task automatic dmi_write(
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0] value,
    input string label
  );
    dmi_transfer(DMI_OP_WRITE, addr, value, DMI_RESP_SUCCESS, '0, 32'hFFFF_FFFF, label);
  endtask

  task automatic dmi_read(
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0] expected,
    input logic [31:0] mask,
    input string label
  );
    dmi_transfer(DMI_OP_READ, addr, '0, DMI_RESP_SUCCESS, expected, mask, label);
  endtask

  task automatic wait_for_gpr_req(input string label);
    int unsigned timeout;
    begin
      timeout = 0;
      while (!core_debug.gpr_req_valid && timeout < 20) begin
        step_clock();
        timeout++;
      end
      if (!core_debug.gpr_req_valid) begin
        $error("%s: timed out waiting for GPR request", label);
        $fatal(1);
      end
    end
  endtask

  task automatic complete_gpr_access(
    input logic expected_write,
    input logic [4:0] expected_addr,
    input logic [31:0] expected_wdata,
    input logic [31:0] response_data,
    input logic response_error,
    input string label
  );
    begin
      wait_for_gpr_req(label);
      if ((core_debug.gpr_req_write !== expected_write) ||
          (core_debug.gpr_req_addr !== expected_addr) ||
          (expected_write && (core_debug.gpr_req_wdata !== expected_wdata))) begin
        $error("%s: GPR req mismatch write=%0b addr=%0d wdata=0x%08h",
               label, core_debug.gpr_req_write, core_debug.gpr_req_addr,
               core_debug.gpr_req_wdata);
        $fatal(1);
      end
      @(negedge clk);
      core_debug.gpr_req_ready = 1'b1;
      core_debug.gpr_rsp_valid = 1'b1;
      core_debug.gpr_rsp_rdata = response_data;
      core_debug.gpr_rsp_err = response_error;
      step_clock();
      core_debug.gpr_req_ready = 1'b0;
      core_debug.gpr_rsp_valid = 1'b0;
      core_debug.gpr_rsp_rdata = '0;
      core_debug.gpr_rsp_err = 1'b0;
      pass_count++;
    end
  endtask

  task automatic wait_abstract_idle(input string label);
    int unsigned timeout;
    begin
      timeout = 0;
      while (u_debug.abstract_busy && timeout < 20) begin
        step_clock();
        timeout++;
      end
      if (u_debug.abstract_busy) begin
        $error("%s: abstract command did not return idle", label);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic check_halt_resume;
    begin
      dmi_write(DMI_ADDR_DMCONTROL, 32'h0000_0001, "activate Debug Module");
      if (!dmactive || ndmreset || core_debug.halt_req || core_debug.resume_req ||
          core_debug.step_req) begin
        $error("activation state mismatch");
        $fatal(1);
      end

      dmi_write(DMI_ADDR_DMCONTROL, 32'h8000_0001, "request halt");
      if (!core_debug.halt_req || core_debug.resume_req || core_debug.step_req) begin
        $error("halt request not driven to core");
        $fatal(1);
      end
      core_debug.running = 1'b0;
      core_debug.halted = 1'b1;
      step_clock();
      if (core_debug.halt_req) begin
        $error("halt request did not retire after core halted");
        $fatal(1);
      end
      dmi_read(DMI_ADDR_DMSTATUS, 32'h000C_0382, 32'h000F_FFFF, "halted dmstatus");
      halt_count++;

      dmi_write(DMI_ADDR_DMCONTROL, 32'h4000_0001, "request resume");
      if (!core_debug.resume_req || core_debug.halt_req) begin
        $error("resume request not driven to core");
        $fatal(1);
      end
      core_debug.halted = 1'b0;
      core_debug.running = 1'b1;
      step_clock();
      if (core_debug.resume_req) begin
        $error("resume request did not retire after core running");
        $fatal(1);
      end
      step_clock();
      dmi_read(DMI_ADDR_DMSTATUS, 32'h000F_0C82, 32'h000F_FFFF, "resumeack dmstatus");
      resume_count++;
      pass_count++;
    end
  endtask

  task automatic check_gpr_write;
    logic [31:0] command_word;
    begin
      core_debug.running = 1'b0;
      core_debug.halted = 1'b1;
      dmi_write(DMI_ADDR_DMCONTROL, 32'h0000_0001, "active halted hart");
      dmi_write(DMI_ADDR_DATA0, 32'hA5A5_1234, "write data0 for GPR write");
      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b1, 1'b1, ABSTRACT_GPR_BASE + 16'd5);
      dmi_write(DMI_ADDR_COMMAND, command_word, "write x5 abstract command");
      complete_gpr_access(1'b1, 5'd5, 32'hA5A5_1234, 32'h0000_0000, 1'b0,
                          "complete x5 write");
      wait_abstract_idle("x5 write idle");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_0002, 32'h0000_1F0F,
               "x5 write abstractcs clean");
      gpr_write_count++;
    end
  endtask

  task automatic check_gpr_read;
    logic [31:0] command_word;
    begin
      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b1, 1'b0, ABSTRACT_GPR_BASE + 16'd6);
      dmi_write(DMI_ADDR_COMMAND, command_word, "read x6 abstract command");
      complete_gpr_access(1'b0, 5'd6, 32'h0000_0000, 32'h6A6A_5678, 1'b0,
                          "complete x6 read");
      wait_abstract_idle("x6 read idle");
      dmi_read(DMI_ADDR_DATA0, 32'h6A6A_5678, 32'hFFFF_FFFF, "x6 read data0");
      gpr_read_count++;
    end
  endtask

  task automatic check_csr_read;
    logic [31:0] command_word;
    begin
      core_debug.running = 1'b0;
      core_debug.halted = 1'b1;
      core_debug.dpc = 32'h1000_00A8;
      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b1, 1'b0, ABSTRACT_CSR_DPC);
      dmi_write(DMI_ADDR_COMMAND, command_word, "read dpc abstract command");
      wait_abstract_idle("dpc read idle");
      dmi_read(DMI_ADDR_DATA0, 32'h1000_00A8, 32'hFFFF_FFFF, "dpc read data0");
      csr_read_count++;
    end
  endtask

  task automatic write_dcsr(input logic [31:0] value, input string label);
    logic [31:0] command_word;
    begin
      dmi_write(DMI_ADDR_DATA0, value, {label, " data0"});
      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b1, 1'b1, ABSTRACT_CSR_DCSR);
      dmi_write(DMI_ADDR_COMMAND, command_word, {label, " command"});
      wait_abstract_idle({label, " idle"});
    end
  endtask

  task automatic check_single_step;
    logic [31:0] command_word;
    begin
      core_debug.running = 1'b0;
      core_debug.halted = 1'b1;
      write_dcsr(ABSTRACT_CSR_DCSR_HALTED_M | ABSTRACT_CSR_DCSR_STEP_MASK,
                 "set dcsr step");

      command_word = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b1, 1'b0, ABSTRACT_CSR_DCSR);
      dmi_write(DMI_ADDR_COMMAND, command_word, "read stepped dcsr command");
      wait_abstract_idle("stepped dcsr read idle");
      dmi_read(DMI_ADDR_DATA0,
               ABSTRACT_CSR_DCSR_HALTED_M | ABSTRACT_CSR_DCSR_STEP_MASK,
               32'hFFFF_FFFF, "stepped dcsr data0");

      dmi_write(DMI_ADDR_DMCONTROL, 32'h4000_0001, "step resume request");
      if (!core_debug.resume_req || !core_debug.step_req || core_debug.halt_req) begin
        $error("single-step request mismatch resume=%0b step=%0b halt=%0b",
               core_debug.resume_req, core_debug.step_req, core_debug.halt_req);
        $fatal(1);
      end

      core_debug.halted = 1'b0;
      core_debug.running = 1'b1;
      step_clock();
      if (core_debug.resume_req || core_debug.step_req) begin
        $error("single-step resume did not retire resume=%0b step=%0b",
               core_debug.resume_req, core_debug.step_req);
        $fatal(1);
      end
      core_debug.running = 1'b0;
      core_debug.halted = 1'b1;
      step_clock();
      dmi_read(DMI_ADDR_DMSTATUS, 32'h000F_0382, 32'h000F_FFFF,
               "single-step halted resumeack dmstatus");

      write_dcsr(ABSTRACT_CSR_DCSR_HALTED_M, "clear dcsr step");
      step_count++;
    end
  endtask

  task automatic check_errors_and_reset_status;
    logic [31:0] bad_command;
    begin
      bad_command = make_access_command(
          3'd3, 1'b1, 1'b0, ABSTRACT_GPR_BASE + 16'd1);
      dmi_write(DMI_ADDR_COMMAND, bad_command, "unsupported aarsize command");
      repeat (3) step_clock();
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_0202, 32'h0000_1F0F,
               "unsupported command cmderr");
      dmi_write(DMI_ADDR_ABSTRACTCS, 32'h0000_0700, "clear cmderr");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_0002, 32'h0000_1F0F,
               "cmderr cleared");
      error_count++;

      hart_reset_event = 1'b1;
      step_clock();
      hart_reset_event = 1'b0;
      dmi_read(DMI_ADDR_DMSTATUS, 32'h000C_0382, 32'h000F_FFFF,
               "havereset visible");
      dmi_write(DMI_ADDR_DMCONTROL, 32'h1000_0001, "ack havereset");
      dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_0382, 32'h000F_FFFF,
               "havereset cleared");
      reset_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    dmi_read_count = 0;
    dmi_write_count = 0;
    halt_count = 0;
    resume_count = 0;
    gpr_write_count = 0;
    gpr_read_count = 0;
    csr_read_count = 0;
    step_count = 0;
    error_count = 0;
    reset_count = 0;
    postexec_count = 0;

    $display("tb_debug phase reset start=%0t", $time);
    apply_reset();
    $display("tb_debug phase discovery start=%0t", $time);
    dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_0082, 32'h000F_FFFF, "inactive dmstatus");
    $display("tb_debug phase halt_resume start=%0t", $time);
    check_halt_resume();
    $display("tb_debug phase gpr start=%0t", $time);
    check_gpr_write();
    check_gpr_read();
    $display("tb_debug phase csr start=%0t", $time);
    check_csr_read();
    $display("tb_debug phase postexec start=%0t", $time);
    check_postexec();
    $display("tb_debug phase step start=%0t", $time);
    check_single_step();
    $display("tb_debug phase error_reset start=%0t", $time);
    check_errors_and_reset_status();
    $display("tb_debug phase complete=%0t", $time);

    if ((halt_count != 1) || (resume_count != 1) || (gpr_write_count != 1) ||
        (gpr_read_count != 1) || (csr_read_count != 1) || (step_count != 1) ||
        (error_count != 2) || (reset_count < 2) || (postexec_count != 3)) begin
      $error("coverage counters missed expected top-level classes");
      $fatal(1);
    end
    $display("tb_debug coverage: pass_count=%0d dmi_reads=%0d dmi_writes=%0d halt=%0d resume=%0d gpr_write=%0d gpr_read=%0d csr_read=%0d step=%0d errors=%0d resets=%0d postexec=%0d",
             pass_count, dmi_read_count, dmi_write_count, halt_count,
             resume_count, gpr_write_count, gpr_read_count, csr_read_count,
             step_count, error_count, reset_count, postexec_count);
    $display("tb_debug PASS");
    $finish;
  end
endmodule
