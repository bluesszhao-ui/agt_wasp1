`timescale 1ns/1ps

// Self-checking verification environment for RV32 Access Register commands.
module tb_debug_abstract_cmd;
  import debug_dmi_pkg::*;

  localparam time CLK_PERIOD = 10ns;

  // Debug Module command-side inputs and completion outputs.
  logic        clk;
  logic        rst_n;
  logic        dmactive;
  logic        hart_halted;
  logic        command_valid;
  logic [31:0] command;
  logic [31:0] data0;
  logic [31:0] data1;
  logic [31:0] hart_dpc;
  logic [2:0]  hart_dcsr_cause;
  logic        busy;
  logic        command_error_valid;
  logic [2:0]  command_error;
  logic        data0_we;
  logic [31:0] data0_wdata;
  logic        data1_we;
  logic [31:0] data1_wdata;

  // Mock debug_reg_access command and response channels.
  logic        reg_cmd_valid;
  logic        reg_cmd_ready;
  logic        reg_cmd_write;
  logic [4:0]  reg_cmd_addr;
  logic [31:0] reg_cmd_wdata;
  logic        reg_rsp_valid;
  logic        reg_rsp_ready;
  logic [31:0] reg_rsp_rdata;
  logic        reg_rsp_error;
  logic        mem_cmd_valid;
  logic        mem_cmd_ready;
  logic        mem_cmd_write;
  logic [31:0] mem_cmd_addr;
  logic [1:0]  mem_cmd_size;
  logic [31:0] mem_cmd_wdata;
  logic [3:0]  mem_cmd_wstrb;
  logic        mem_rsp_valid;
  logic        mem_rsp_ready;
  logic [31:0] mem_rsp_rdata;
  logic        mem_rsp_error;
  logic        dcsr_step;
  logic [ABSTRACT_TRIGGER_COUNT-1:0] trigger_execute_valid;
  logic [ABSTRACT_TRIGGER_COUNT-1:0][31:0] trigger_execute_addr;
  logic        reg_flush;
  logic        mem_flush;

  // Functional coverage counters summarized at PASS.
  int unsigned pass_count;
  int unsigned read_count;
  int unsigned write_count;
  int unsigned csr_read_count;
  int unsigned csr_write_count;
  int unsigned trigger_count;
  int unsigned mem_read_count;
  int unsigned mem_write_count;
  int unsigned noop_count;
  int unsigned unsupported_count;
  int unsigned halt_error_count;
  int unsigned downstream_error_count;
  int unsigned issue_hold_count;
  int unsigned wait_count;
  int unsigned flush_count;
  int unsigned busy_ignore_count;
  int unsigned reset_abort_count;
  int unsigned random_count;

  debug_abstract_cmd u_debug_abstract_cmd (
    .clk_i(clk),
    .rst_ni(rst_n),
    .dmactive_i(dmactive),
    .hart_halted_i(hart_halted),
    .command_valid_i(command_valid),
    .command_i(command),
    .data0_i(data0),
    .data1_i(data1),
    .hart_dpc_i(hart_dpc),
    .hart_dcsr_cause_i(hart_dcsr_cause),
    .busy_o(busy),
    .command_error_valid_o(command_error_valid),
    .command_error_o(command_error),
    .data0_we_o(data0_we),
    .data0_wdata_o(data0_wdata),
    .data1_we_o(data1_we),
    .data1_wdata_o(data1_wdata),
    .reg_cmd_valid_o(reg_cmd_valid),
    .reg_cmd_ready_i(reg_cmd_ready),
    .reg_cmd_write_o(reg_cmd_write),
    .reg_cmd_addr_o(reg_cmd_addr),
    .reg_cmd_wdata_o(reg_cmd_wdata),
    .reg_rsp_valid_i(reg_rsp_valid),
    .reg_rsp_ready_o(reg_rsp_ready),
    .reg_rsp_rdata_i(reg_rsp_rdata),
    .reg_rsp_error_i(reg_rsp_error),
    .mem_cmd_valid_o(mem_cmd_valid),
    .mem_cmd_ready_i(mem_cmd_ready),
    .mem_cmd_write_o(mem_cmd_write),
    .mem_cmd_addr_o(mem_cmd_addr),
    .mem_cmd_size_o(mem_cmd_size),
    .mem_cmd_wdata_o(mem_cmd_wdata),
    .mem_cmd_wstrb_o(mem_cmd_wstrb),
    .mem_rsp_valid_i(mem_rsp_valid),
    .mem_rsp_ready_o(mem_rsp_ready),
    .mem_rsp_rdata_i(mem_rsp_rdata),
    .mem_rsp_error_i(mem_rsp_error),
    .dcsr_step_o(dcsr_step),
    .trigger_execute_valid_o(trigger_execute_valid),
    .trigger_execute_addr_o(trigger_execute_addr),
    .reg_flush_o(reg_flush),
    .mem_flush_o(mem_flush)
  );

  // Project-default 100 MHz clock.
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Construct a raw Access Register command without hiding field positions.
  function automatic logic [31:0] make_access_command(
    input logic [2:0] aarsize,
    input logic postincrement,
    input logic postexec,
    input logic transfer,
    input logic write_value,
    input logic [15:0] regno
  );
    logic [31:0] value;
    begin
      value = '0;
      value[31:24] = ABSTRACT_CMD_ACCESS_REGISTER;
      value[22:20] = aarsize;
      value[19] = postincrement;
      value[18] = postexec;
      value[17] = transfer;
      value[16] = write_value;
      value[15:0] = regno;
      make_access_command = value;
    end
  endfunction

  function automatic logic [31:0] make_memory_command(
    input logic [2:0] aamsize,
    input logic postincrement,
    input logic write_value
  );
    logic [31:0] value;
    begin
      value = '0;
      value[31:24] = ABSTRACT_CMD_ACCESS_MEMORY;
      value[22:20] = aamsize;
      value[19] = postincrement;
      value[16] = write_value;
      make_memory_command = value;
    end
  endfunction

  // Advance one active edge and allow outputs to settle.
  task automatic step_clock;
    begin
      @(posedge clk);
      #1ns;
    end
  endtask

  // Set all command and mock-reg-access inputs inactive.
  task automatic drive_idle;
    begin
      dmactive = 1'b1;
      hart_halted = 1'b1;
      command_valid = 1'b0;
      command = '0;
      data0 = '0;
      data1 = '0;
      hart_dpc = 32'h0000_0000;
      hart_dcsr_cause = ABSTRACT_DCSR_CAUSE_HALTREQ;
      reg_cmd_ready = 1'b0;
      reg_rsp_valid = 1'b0;
      reg_rsp_rdata = '0;
      reg_rsp_error = 1'b0;
      mem_cmd_ready = 1'b0;
      mem_rsp_valid = 1'b0;
      mem_rsp_rdata = '0;
      mem_rsp_error = 1'b0;
    end
  endtask

  // Verify the externally visible idle contract.
  task automatic expect_idle(input string label);
    begin
      if (busy || command_error_valid || data0_we || data1_we ||
          reg_cmd_valid || reg_rsp_ready || mem_cmd_valid || mem_rsp_ready) begin
        $error("%s: idle mismatch busy=%0b err=%0b data0_we=%0b data1_we=%0b reg_cmd=%0b mem_cmd=%0b",
               label, busy, command_error_valid, data0_we, data1_we,
               reg_cmd_valid, mem_cmd_valid);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Reset the controller and verify it returns idle.
  task automatic apply_reset;
    begin
      drive_idle();
      rst_n = 1'b0;
      repeat (3) @(posedge clk);
      rst_n = 1'b1;
      step_clock();
      expect_idle("reset idle");
    end
  endtask

  // Pulse one raw command into the idle controller.
  task automatic pulse_command(
    input logic [31:0] command_value,
    input logic [31:0] data_value
  );
    begin
      @(negedge clk);
      command = command_value;
      data0 = data_value;
      command_valid = 1'b1;
      step_clock();
      command_valid = 1'b0;
    end
  endtask

  task automatic pulse_memory_command(
    input logic [31:0] command_value,
    input logic [31:0] data_value,
    input logic [31:0] addr_value
  );
    begin
      @(negedge clk);
      command = command_value;
      data0 = data_value;
      data1 = addr_value;
      command_valid = 1'b1;
      step_clock();
      command_valid = 1'b0;
    end
  endtask

  // Start a supported transfer and verify the decoded downstream fields.
  task automatic start_gpr_transfer(
    input logic write_value,
    input logic [4:0] addr_value,
    input logic [31:0] data_value,
    input string label
  );
    logic [31:0] command_value;
    begin
      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, write_value,
          ABSTRACT_GPR_BASE + 16'(addr_value));
      pulse_command(command_value, data_value);
      if (!busy || !reg_cmd_valid || (reg_cmd_write !== write_value) ||
          (reg_cmd_addr !== addr_value) || (reg_cmd_wdata !== data_value) ||
          command_error_valid || data0_we) begin
        $error("%s: decoded GPR request mismatch", label);
        $fatal(1);
      end
      if (write_value) write_count++;
      else read_count++;
      pass_count++;
    end
  endtask

  // Hold downstream command backpressure and verify decoded fields are stable.
  task automatic hold_reg_command(input int unsigned cycles, input string label);
    logic held_write;
    logic [4:0] held_addr;
    logic [31:0] held_data;
    begin
      held_write = reg_cmd_write;
      held_addr = reg_cmd_addr;
      held_data = reg_cmd_wdata;
      repeat (cycles) begin
        step_clock();
        if (!reg_cmd_valid || (reg_cmd_write !== held_write) ||
            (reg_cmd_addr !== held_addr) || (reg_cmd_wdata !== held_data)) begin
          $error("%s: register command changed under backpressure", label);
          $fatal(1);
        end
        issue_hold_count++;
        pass_count++;
      end
    end
  endtask

  // Accept the decoded request and enter response wait.
  task automatic accept_reg_command(input string label);
    begin
      @(negedge clk);
      reg_cmd_ready = 1'b1;
      step_clock();
      reg_cmd_ready = 1'b0;
      if (!busy || reg_cmd_valid || !reg_rsp_ready) begin
        $error("%s: controller did not enter response wait", label);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Return a downstream result and check the one-cycle COMPLETE outputs.
  task automatic send_reg_response(
    input logic [31:0] data_value,
    input logic error_value,
    input logic expected_write,
    input string label
  );
    begin
      @(negedge clk);
      if (!reg_rsp_ready) begin
        $error("%s: downstream response unexpectedly not ready", label);
        $fatal(1);
      end
      reg_rsp_valid = 1'b1;
      reg_rsp_rdata = data_value;
      reg_rsp_error = error_value;
      step_clock();
      reg_rsp_valid = 1'b0;

      if (!busy) begin
        $error("%s: COMPLETE cycle did not keep busy asserted", label);
        $fatal(1);
      end
      if (error_value) begin
        if (!command_error_valid || (command_error != CMDERR_EXCEPTION) || data0_we) begin
          $error("%s: downstream error mapping mismatch", label);
          $fatal(1);
        end
        downstream_error_count++;
      end else if (expected_write) begin
        if (command_error_valid || data0_we) begin
          $error("%s: successful write produced unexpected side effect", label);
          $fatal(1);
        end
      end else begin
        if (command_error_valid || !data0_we || (data0_wdata !== data_value)) begin
          $error("%s: successful read data0 update mismatch", label);
          $fatal(1);
        end
      end
      pass_count++;

      step_clock();
      expect_idle({label, " idle"});
    end
  endtask

  task automatic start_mem_transfer(
    input logic        write_value,
    input logic [2:0]  size_value,
    input logic        postincrement,
    input logic [31:0] addr_value,
    input logic [31:0] data_value,
    input logic [31:0] exp_wdata,
    input logic [3:0]  exp_wstrb,
    input string       label
  );
    logic [31:0] command_value;
    begin
      command_value = make_memory_command(size_value, postincrement, write_value);
      pulse_memory_command(command_value, data_value, addr_value);
      if (!busy || !mem_cmd_valid || (mem_cmd_write !== write_value) ||
          (mem_cmd_addr !== addr_value) || (mem_cmd_wdata !== exp_wdata) ||
          (mem_cmd_wstrb !== exp_wstrb) || reg_cmd_valid ||
          command_error_valid || data0_we || data1_we) begin
        $error("%s: decoded memory request mismatch", label);
        $fatal(1);
      end
      if (write_value) mem_write_count++;
      else mem_read_count++;
      pass_count++;
    end
  endtask

  task automatic accept_mem_command(input string label);
    begin
      @(negedge clk);
      mem_cmd_ready = 1'b1;
      step_clock();
      mem_cmd_ready = 1'b0;
      if (!busy || mem_cmd_valid || !mem_rsp_ready) begin
        $error("%s: controller did not enter memory response wait", label);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic send_mem_response(
    input logic [31:0] data_value,
    input logic        error_value,
    input logic        expected_write,
    input logic        expected_postincrement,
    input logic [31:0] expected_data0,
    input logic [31:0] expected_data1,
    input string       label
  );
    begin
      @(negedge clk);
      if (!mem_rsp_ready) begin
        $error("%s: memory response unexpectedly not ready", label);
        $fatal(1);
      end
      mem_rsp_valid = 1'b1;
      mem_rsp_rdata = data_value;
      mem_rsp_error = error_value;
      step_clock();
      mem_rsp_valid = 1'b0;

      if (error_value) begin
        if (!command_error_valid || (command_error != CMDERR_BUS) ||
            data0_we || data1_we) begin
          $error("%s: memory error mapping mismatch", label);
          $fatal(1);
        end
        downstream_error_count++;
      end else begin
        if (command_error_valid) begin
          $error("%s: unexpected memory command error", label);
          $fatal(1);
        end
        if (!expected_write && (!data0_we || (data0_wdata !== expected_data0))) begin
          $error("%s: memory read data0 mismatch got=0x%08x exp=0x%08x",
                 label, data0_wdata, expected_data0);
          $fatal(1);
        end
        if (expected_write && data0_we) begin
          $error("%s: memory write should not update data0", label);
          $fatal(1);
        end
        if (expected_postincrement) begin
          if (!data1_we || (data1_wdata !== expected_data1)) begin
            $error("%s: memory postincrement mismatch got=0x%08x exp=0x%08x",
                   label, data1_wdata, expected_data1);
            $fatal(1);
          end
        end else if (data1_we) begin
          $error("%s: unexpected data1 update", label);
          $fatal(1);
        end
      end
      pass_count++;
      step_clock();
      expect_idle({label, " idle"});
    end
  endtask

  // Verify a complete supported read and write flow.
  task automatic check_normal_paths;
    begin
      start_gpr_transfer(1'b0, 5'd5, 32'hA5A5_0005, "read x5");
      hold_reg_command(3, "read issue hold");
      accept_reg_command("read accepted");
      repeat (2) begin
        step_clock();
        if (!reg_rsp_ready || command_error_valid || data0_we) begin
          $error("read response wait mismatch");
          $fatal(1);
        end
        wait_count++;
        pass_count++;
      end
      send_reg_response(32'h1234_5678, 1'b0, 1'b0, "read x5 complete");

      start_gpr_transfer(1'b1, 5'd10, 32'hCAFE_BABE, "write x10");
      accept_reg_command("write accepted");
      send_reg_response(32'h0000_0000, 1'b0, 1'b1, "write x10 complete");

      start_gpr_transfer(1'b0, 5'd31, 32'h0000_0000, "error read");
      accept_reg_command("error read accepted");
      send_reg_response(32'hDEAD_BEEF, 1'b1, 1'b0, "error read complete");
    end
  endtask

  // Immediate decoder/policy error returns one COMPLETE-cycle cmderr pulse.
  task automatic expect_immediate_error(
    input logic [31:0] command_value,
    input logic [2:0] expected_error,
    input string label
  );
    begin
      pulse_command(command_value, 32'h55AA_55AA);
      if (!busy || !command_error_valid || (command_error !== expected_error) ||
          reg_cmd_valid || data0_we) begin
        $error("%s: immediate error expected=%0d got_valid=%0b got=%0d",
               label, expected_error, command_error_valid, command_error);
        $fatal(1);
      end
      if (expected_error == CMDERR_NOTSUP) unsupported_count++;
      if (expected_error == CMDERR_HALT_RESUME) halt_error_count++;
      pass_count++;
      step_clock();
      expect_idle({label, " idle"});
    end
  endtask

  // Exercise every unsupported field and the transfer-disabled no-op.
  task automatic check_decode_errors_and_noop;
    logic [31:0] command_value;
    begin
      command_value = make_access_command(3'd7, 1'b0, 1'b0, 1'b0, 1'b1, 16'hFFFF);
      pulse_command(command_value, 32'h1111_2222);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid) begin
        $error("transfer-disabled command was not a successful no-op");
        $fatal(1);
      end
      noop_count++;
      pass_count++;
      step_clock();
      expect_idle("no-op idle");

      expect_immediate_error(32'h0102_1000, CMDERR_NOTSUP, "unsupported cmdtype");
      command_value = make_access_command(3'd3, 1'b0, 1'b0, 1'b1, 1'b0, 16'h1001);
      expect_immediate_error(command_value, CMDERR_NOTSUP, "unsupported aarsize");
      command_value = make_access_command(ABSTRACT_AARSIZE_32, 1'b1, 1'b0, 1'b1, 1'b0, 16'h1002);
      expect_immediate_error(command_value, CMDERR_NOTSUP, "postincrement unsupported");
      command_value = make_access_command(ABSTRACT_AARSIZE_32, 1'b0, 1'b1, 1'b1, 1'b0, 16'h1003);
      expect_immediate_error(command_value, CMDERR_NOTSUP, "postexec unsupported");
      command_value = make_access_command(ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b0, 16'h1020);
      expect_immediate_error(command_value, CMDERR_NOTSUP, "non-GPR unsupported");
      command_value = make_access_command(ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b0, 16'h1004);
      command_value[23] = 1'b1;
      expect_immediate_error(command_value, CMDERR_NOTSUP, "reserved bit unsupported");

      hart_halted = 1'b0;
      command_value = make_access_command(ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b0, 16'h1005);
      expect_immediate_error(command_value, CMDERR_HALT_RESUME, "running hart rejected");
      hart_halted = 1'b1;
    end
  endtask

  // Minimal OpenOCD/GDB probe support: selected read-only CSRs complete locally.
  task automatic check_csr_read(
    input logic [15:0] csr_regno,
    input logic [31:0] expected_rdata,
    input string label
  );
    logic [31:0] command_value;
    begin
      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b0, csr_regno);
      pulse_command(command_value, 32'h0000_0000);
      if (!busy || command_error_valid || !data0_we ||
          (data0_wdata !== expected_rdata) ||
          reg_cmd_valid || reg_rsp_ready) begin
        $error("%s: CSR read mismatch regno=0x%04x busy=%0b err=%0b data0_we=%0b data=0x%08x reg_cmd=%0b rsp_ready=%0b",
               label, csr_regno, busy, command_error_valid, data0_we, data0_wdata,
               reg_cmd_valid, reg_rsp_ready);
        $fatal(1);
      end
      csr_read_count++;
      pass_count++;
      step_clock();
      expect_idle({label, " idle"});
    end
  endtask

  // Supported DCSR writes update only the local step bit and do not issue a GPR
  // transaction or update data0.
  task automatic check_dcsr_write(
    input logic [31:0] write_value,
    input logic        expected_step,
    input string       label
  );
    logic [31:0] command_value;
    begin
      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b1, ABSTRACT_CSR_DCSR);
      pulse_command(command_value, write_value);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready || (dcsr_step !== expected_step)) begin
        $error("%s: DCSR write mismatch busy=%0b err=%0b data0_we=%0b reg_cmd=%0b rsp_ready=%0b step=%0b",
               label, busy, command_error_valid, data0_we, reg_cmd_valid,
               reg_rsp_ready, dcsr_step);
        $fatal(1);
      end
      csr_write_count++;
      pass_count++;
      step_clock();
      expect_idle({label, " idle"});
    end
  endtask

  // Writes to optional/unimplemented CSRs complete as no-ops so OpenOCD does
  // not disable all abstract CSR writes after probing trigger CSRs.
  task automatic check_csr_write_noop(
    input logic [15:0] csr_regno,
    input string       label
  );
    logic [31:0] command_value;
    begin
      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b1, csr_regno);
      pulse_command(command_value, 32'hFFFF_FFFF);
      if (!busy || command_error_valid || data0_we || data1_we ||
          reg_cmd_valid || reg_rsp_ready || mem_cmd_valid || mem_rsp_ready) begin
        $error("%s: CSR no-op write mismatch busy=%0b err=%0b data0_we=%0b",
               label, busy, command_error_valid, data0_we);
        $fatal(1);
      end
      csr_write_count++;
      pass_count++;
      step_clock();
      expect_idle({label, " idle"});
    end
  endtask

  // Exercise both mcontrol trigger images used by OpenOCD/GDB hardware
  // breakpoints. Writes are WARL-filtered before driving the core comparators.
  task automatic check_trigger_csrs;
    logic [31:0] command_value;
    logic [31:0] tselect_command;
    logic [31:0] valid_tdata1;
    logic [31:0] bad_action_tdata1;
    logic [31:0] bad_type_tdata1;
    begin
      valid_tdata1 = ABSTRACT_TDATA1_TYPE_MCONTROL |
                     ABSTRACT_MCONTROL_ACTION_DEBUG |
                     ABSTRACT_MCONTROL_M |
                     ABSTRACT_MCONTROL_EXECUTE;
      bad_action_tdata1 = ABSTRACT_TDATA1_TYPE_MCONTROL |
                          32'h0000_2000 |
                          ABSTRACT_MCONTROL_M |
                          ABSTRACT_MCONTROL_EXECUTE;
      bad_type_tdata1 = 32'hF000_0000 |
                        ABSTRACT_MCONTROL_ACTION_DEBUG |
                        ABSTRACT_MCONTROL_M |
                        ABSTRACT_MCONTROL_EXECUTE;

      tselect_command = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b1, ABSTRACT_CSR_TSELECT);
      pulse_command(tselect_command, 32'h0000_0000);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready) begin
        $error("tselect slot0 write mismatch");
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("tselect slot0 write idle");
      check_csr_read(ABSTRACT_CSR_TSELECT, 32'h0000_0000,
                     "tselect slot0 read");
      check_csr_read(ABSTRACT_CSR_TDATA1, ABSTRACT_TDATA1_TYPE_MCONTROL,
                     "slot0 tdata1 reset mcontrol read");
      check_csr_read(ABSTRACT_CSR_TINFO, ABSTRACT_TINFO_MCONTROL_ONLY,
                     "tinfo mcontrol support read");

      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b1, ABSTRACT_CSR_TDATA2);
      pulse_command(command_value, 32'h0000_0040);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready || (trigger_execute_addr[0] !== 32'h0000_0040)) begin
        $error("slot0 tdata2 write mismatch addr=0x%08x", trigger_execute_addr[0]);
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("tdata2 write idle");

      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b1, ABSTRACT_CSR_TDATA1);
      pulse_command(command_value, valid_tdata1);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready || !trigger_execute_valid[0] ||
          (trigger_execute_addr[0] !== 32'h0000_0040)) begin
        $error("slot0 valid tdata1 write mismatch valid=%0b addr=0x%08x",
               trigger_execute_valid[0], trigger_execute_addr[0]);
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("valid tdata1 write idle");
      check_csr_read(ABSTRACT_CSR_TDATA1, valid_tdata1,
                     "valid tdata1 readback");
      check_csr_read(ABSTRACT_CSR_TDATA2, 32'h0000_0040,
                     "slot0 tdata2 readback");

      pulse_command(tselect_command, 32'h0000_0001);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready) begin
        $error("tselect slot1 write mismatch");
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("tselect slot1 write idle");
      check_csr_read(ABSTRACT_CSR_TSELECT, 32'h0000_0001,
                     "tselect slot1 read");
      check_csr_read(ABSTRACT_CSR_TDATA1, ABSTRACT_TDATA1_TYPE_MCONTROL,
                     "slot1 tdata1 reset mcontrol read");

      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b1, ABSTRACT_CSR_TDATA2);
      pulse_command(command_value, 32'h0000_0080);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready || (trigger_execute_addr[1] !== 32'h0000_0080)) begin
        $error("slot1 tdata2 write mismatch addr=0x%08x", trigger_execute_addr[1]);
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("slot1 tdata2 write idle");

      command_value = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b1, ABSTRACT_CSR_TDATA1);
      pulse_command(command_value, valid_tdata1);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready || (trigger_execute_valid !== 2'b11) ||
          (trigger_execute_addr[0] !== 32'h0000_0040) ||
          (trigger_execute_addr[1] !== 32'h0000_0080)) begin
        $error("dual trigger enable mismatch valid=%0b addr0=0x%08x addr1=0x%08x",
               trigger_execute_valid, trigger_execute_addr[0],
               trigger_execute_addr[1]);
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("slot1 valid tdata1 write idle");
      check_csr_read(ABSTRACT_CSR_TDATA1, valid_tdata1,
                     "slot1 valid tdata1 readback");
      check_csr_read(ABSTRACT_CSR_TDATA2, 32'h0000_0080,
                     "slot1 tdata2 readback");

      pulse_command(tselect_command, 32'h0000_0002);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready) begin
        $error("tselect out-of-range write mismatch");
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("tselect out-of-range write idle");
      check_csr_read(ABSTRACT_CSR_TSELECT, 32'h0000_0001,
                     "tselect clamps to last slot read");

      pulse_command(command_value, bad_action_tdata1);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready || !trigger_execute_valid[0] ||
          trigger_execute_valid[1]) begin
        $error("bad-action slot1 should only disable slot1 valid=%0b",
               trigger_execute_valid);
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("bad-action tdata1 write idle");
      check_csr_read(ABSTRACT_CSR_TDATA1,
                     ABSTRACT_TDATA1_TYPE_MCONTROL |
                     ABSTRACT_MCONTROL_M |
                     ABSTRACT_MCONTROL_EXECUTE,
                     "slot1 bad-action tdata1 readback");

      pulse_command(command_value, bad_type_tdata1);
      if (!busy || command_error_valid || data0_we || reg_cmd_valid ||
          reg_rsp_ready || !trigger_execute_valid[0] ||
          trigger_execute_valid[1]) begin
        $error("bad-type slot1 should return disabled mcontrol valid=%0b",
               trigger_execute_valid);
        $fatal(1);
      end
      csr_write_count++;
      trigger_count++;
      pass_count++;
      step_clock();
      expect_idle("bad-type tdata1 write idle");
      check_csr_read(ABSTRACT_CSR_TDATA1, ABSTRACT_TDATA1_TYPE_MCONTROL,
                     "slot1 bad-type tdata1 readback");
    end
  endtask

  // Verify halted-state loss in ISSUE and WAIT maps to halt/resume error.
  task automatic check_hart_abort;
    begin
      start_gpr_transfer(1'b0, 5'd6, '0, "issue hart abort");
      hart_halted = 1'b0;
      #1ns;
      if (!reg_flush || reg_cmd_valid) begin
        $error("issue hart abort did not flush/gate request");
        $fatal(1);
      end
      step_clock();
      if (!command_error_valid || (command_error != CMDERR_HALT_RESUME)) begin
        $error("issue hart abort error mismatch");
        $fatal(1);
      end
      halt_error_count++;
      flush_count++;
      pass_count++;
      hart_halted = 1'b1;
      step_clock();
      expect_idle("issue hart abort idle");

      start_gpr_transfer(1'b0, 5'd7, '0, "wait hart abort");
      accept_reg_command("wait hart abort accepted");
      hart_halted = 1'b0;
      #1ns;
      if (!reg_flush) begin
        $error("wait hart abort did not flush downstream");
        $fatal(1);
      end
      step_clock();
      if (!command_error_valid || (command_error != CMDERR_HALT_RESUME)) begin
        $error("wait hart abort error mismatch");
        $fatal(1);
      end
      halt_error_count++;
      flush_count++;
      pass_count++;
      hart_halted = 1'b1;
      step_clock();
      expect_idle("wait hart abort idle");
    end
  endtask

  // DM deactivation aborts silently and holds downstream flush asserted.
  task automatic check_dm_abort;
    begin
      start_gpr_transfer(1'b1, 5'd8, 32'h8888_8888, "issue dm abort");
      dmactive = 1'b0;
      #1ns;
      if (!reg_flush || reg_cmd_valid) begin
        $error("issue DM abort did not gate/flush");
        $fatal(1);
      end
      step_clock();
      if (busy || command_error_valid || data0_we) begin
        $error("DM deactivation did not silently return idle");
        $fatal(1);
      end
      dmactive = 1'b1;
      #1ns;
      expect_idle("issue DM abort idle");
      flush_count++;

      start_gpr_transfer(1'b0, 5'd9, '0, "wait dm abort");
      accept_reg_command("wait dm abort accepted");
      dmactive = 1'b0;
      #1ns;
      if (!reg_flush) begin
        $error("wait DM abort did not flush downstream");
        $fatal(1);
      end
      step_clock();
      dmactive = 1'b1;
      #1ns;
      expect_idle("wait DM abort idle");
      flush_count++;
    end
  endtask

  // A command pulse while busy is ignored; original captured fields remain.
  task automatic check_busy_command_ignored;
    logic [31:0] second_command;
    begin
      start_gpr_transfer(1'b1, 5'd11, 32'h1111_1111, "busy original");
      second_command = make_access_command(
          ABSTRACT_AARSIZE_32, 1'b0, 1'b0, 1'b1, 1'b0, 16'h1012);
      command = second_command;
      data0 = 32'h2222_2222;
      command_valid = 1'b1;
      step_clock();
      command_valid = 1'b0;
      if (!reg_cmd_valid || !reg_cmd_write || (reg_cmd_addr != 5'd11) ||
          (reg_cmd_wdata != 32'h1111_1111)) begin
        $error("busy command overwrote captured request");
        $fatal(1);
      end
      busy_ignore_count++;
      pass_count++;
      accept_reg_command("busy original accepted");
      send_reg_response('0, 1'b0, 1'b1, "busy original complete");
    end
  endtask

  // Asynchronous reset while issuing immediately restores idle outputs.
  task automatic check_reset_abort;
    begin
      start_gpr_transfer(1'b0, 5'd13, '0, "reset abort");
      rst_n = 1'b0;
      #1ns;
      if (busy || reg_cmd_valid || command_error_valid || data0_we) begin
        $error("reset did not abort active abstract command");
        $fatal(1);
      end
      repeat (2) @(posedge clk);
      rst_n = 1'b1;
      step_clock();
      expect_idle("reset abort idle");
      reset_abort_count++;
    end
  endtask

  task automatic check_memory_paths;
    begin
      start_mem_transfer(1'b0, ABSTRACT_AAMSIZE_32, 1'b1,
                         32'h2000_0100, 32'h0000_0000,
                         32'h0000_0000, 4'b1111, "memory word read");
      accept_mem_command("memory word read accepted");
      send_mem_response(32'h89AB_CDEF, 1'b0, 1'b0, 1'b1,
                        32'h89AB_CDEF, 32'h2000_0104,
                        "memory word read complete");

      start_mem_transfer(1'b1, ABSTRACT_AAMSIZE_8, 1'b0,
                         32'h2000_0103, 32'h0000_005A,
                         32'h5A00_0000, 4'b1000, "memory byte write");
      accept_mem_command("memory byte write accepted");
      send_mem_response(32'h0000_0000, 1'b0, 1'b1, 1'b0,
                        32'h0000_0000, 32'h0000_0000,
                        "memory byte write complete");

      start_mem_transfer(1'b0, ABSTRACT_AAMSIZE_16, 1'b0,
                         32'h2000_0102, 32'h0000_0000,
                         32'h0000_0000, 4'b1100, "memory half read");
      accept_mem_command("memory half read accepted");
      send_mem_response(32'hCAFE_1234, 1'b0, 1'b0, 1'b0,
                        32'h0000_CAFE, 32'h0000_0000,
                        "memory half read complete");

      start_mem_transfer(1'b0, ABSTRACT_AAMSIZE_32, 1'b0,
                         32'hFFFF_FFFC, 32'h0000_0000,
                         32'h0000_0000, 4'b1111, "memory bus error");
      accept_mem_command("memory bus error accepted");
      send_mem_response(32'h0000_0000, 1'b1, 1'b0, 1'b0,
                        32'h0000_0000, 32'h0000_0000,
                        "memory bus error complete");
    end
  endtask

  // Randomized valid GPR operations exercise timing and error combinations.
  task automatic check_random_commands(input int unsigned iterations);
    logic write_value;
    logic [4:0] addr_value;
    logic [31:0] write_data;
    logic [31:0] read_data;
    logic error_value;
    int unsigned issue_delay;
    int unsigned response_delay;
    begin
      void'($urandom(32'h4142_434D));
      for (int unsigned idx = 0; idx < iterations; idx++) begin
        write_value = 1'($urandom_range(0, 1));
        addr_value = 5'($urandom_range(0, 31));
        write_data = $urandom();
        read_data = $urandom();
        error_value = ((idx % 6) == 5);
        issue_delay = $urandom_range(0, 3);
        response_delay = $urandom_range(0, 3);

        start_gpr_transfer(write_value, addr_value, write_data, "random command");
        hold_reg_command(issue_delay, "random issue hold");
        accept_reg_command("random accepted");
        repeat (response_delay) begin
          step_clock();
          if (!reg_rsp_ready || command_error_valid || data0_we) begin
            $error("random response wait mismatch");
            $fatal(1);
          end
          wait_count++;
          pass_count++;
        end
        send_reg_response(read_data, error_value, write_value, "random complete");
        random_count++;
      end
    end
  endtask

  initial begin
    pass_count = 0;
    read_count = 0;
    write_count = 0;
    csr_read_count = 0;
    csr_write_count = 0;
    trigger_count = 0;
    mem_read_count = 0;
    mem_write_count = 0;
    noop_count = 0;
    unsupported_count = 0;
    halt_error_count = 0;
    downstream_error_count = 0;
    issue_hold_count = 0;
    wait_count = 0;
    flush_count = 0;
    busy_ignore_count = 0;
    reset_abort_count = 0;
    random_count = 0;
    rst_n = 1'b1;

    $display("phase reset start=%0t", $time);
    apply_reset();
    $display("phase normal start=%0t", $time);
    check_normal_paths();
    $display("phase csr start=%0t", $time);
    check_csr_read(ABSTRACT_CSR_MISA, ABSTRACT_CSR_MISA_RV32I, "misa CSR read");
    check_csr_read(ABSTRACT_CSR_MSTATUS, ABSTRACT_CSR_MSTATUS_RV32_M,
                   "mstatus CSR read");
    check_csr_read(ABSTRACT_CSR_DCSR, ABSTRACT_CSR_DCSR_HALTED_M, "dcsr CSR read");
    hart_dpc = 32'h1000_0044;
    check_csr_read(ABSTRACT_CSR_DPC, 32'h1000_0044, "dpc CSR read");
    check_dcsr_write(ABSTRACT_CSR_DCSR_HALTED_M | ABSTRACT_CSR_DCSR_STEP_MASK,
                     1'b1, "dcsr step set");
    check_csr_read(ABSTRACT_CSR_DCSR,
                   ABSTRACT_CSR_DCSR_HALTED_M | ABSTRACT_CSR_DCSR_STEP_MASK,
                   "dcsr step read");
    check_dcsr_write(ABSTRACT_CSR_DCSR_HALTED_M, 1'b0, "dcsr step clear");
    check_csr_read(ABSTRACT_CSR_DCSR, ABSTRACT_CSR_DCSR_HALTED_M,
                   "dcsr step clear read");
    hart_dcsr_cause = ABSTRACT_DCSR_CAUSE_TRIGGER;
    check_csr_read(ABSTRACT_CSR_DCSR,
                   ABSTRACT_CSR_DCSR_BASE_RV32_M |
                   ({29'h0000_0000, ABSTRACT_DCSR_CAUSE_TRIGGER} << 6),
                   "dcsr trigger cause read");
    hart_dcsr_cause = ABSTRACT_DCSR_CAUSE_HALTREQ;
    check_csr_write_noop(ABSTRACT_CSR_TCONTROL, "tcontrol write no-op");
    check_trigger_csrs();
    $display("phase memory start=%0t", $time);
    check_memory_paths();
    $display("phase decode start=%0t", $time);
    check_decode_errors_and_noop();
    $display("phase abort start=%0t", $time);
    check_hart_abort();
    check_dm_abort();
    check_busy_command_ignored();
    check_reset_abort();
    $display("phase random start=%0t", $time);
    check_random_commands(20);
    $display("phase complete=%0t", $time);

    $display("tb_debug_abstract_cmd coverage: pass=%0d read=%0d write=%0d csr_read=%0d csr_write=%0d trigger=%0d mem_read=%0d mem_write=%0d noop=%0d unsupported=%0d halt_error=%0d downstream_error=%0d issue_hold=%0d wait=%0d flush=%0d busy_ignore=%0d reset_abort=%0d random=%0d",
             pass_count, read_count, write_count, csr_read_count,
             csr_write_count, trigger_count, mem_read_count, mem_write_count, noop_count,
             unsupported_count, halt_error_count, downstream_error_count,
             issue_hold_count, wait_count, flush_count, busy_ignore_count,
             reset_abort_count, random_count);
    $display("tb_debug_abstract_cmd PASS");
    $finish;
  end
endmodule
