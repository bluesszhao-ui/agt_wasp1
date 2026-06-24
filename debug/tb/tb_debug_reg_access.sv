`timescale 1ns/1ps

// Self-checking environment for Debug Module to core GPR access sequencing.
module tb_debug_reg_access;
  localparam time CLK_PERIOD = 10ns;

  // Sequencer clock/reset and upstream command/response channel.
  logic        clk;
  logic        rst_n;
  logic        flush;
  logic        cmd_valid;
  logic        cmd_ready;
  logic        cmd_write;
  logic [4:0]  cmd_addr;
  logic [31:0] cmd_wdata;
  logic        rsp_valid;
  logic        rsp_ready;
  logic [31:0] rsp_rdata;
  logic        rsp_error;

  // Structured core debug interface; unrelated control fields are TB-idle.
  debug_if core_debug (.clk(clk), .rst_n(rst_n));

  // Reference GPR image supports deterministic-random read/write checking.
  logic [31:0] model_gpr [32];

  // Explicit functional coverage counters.
  int unsigned pass_count;
  int unsigned read_count;
  int unsigned write_count;
  int unsigned req_hold_count;
  int unsigned rsp_hold_count;
  int unsigned same_cycle_count;
  int unsigned core_error_count;
  int unsigned flush_count;
  int unsigned drain_count;
  int unsigned reset_abort_count;
  int unsigned random_count;

  debug_reg_access u_debug_reg_access (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .cmd_valid_i(cmd_valid),
    .cmd_ready_o(cmd_ready),
    .cmd_write_i(cmd_write),
    .cmd_addr_i(cmd_addr),
    .cmd_wdata_i(cmd_wdata),
    .rsp_valid_o(rsp_valid),
    .rsp_ready_i(rsp_ready),
    .rsp_rdata_o(rsp_rdata),
    .rsp_error_o(rsp_error),
    .core_debug(core_debug)
  );

  // Project-default 100 MHz verification clock.
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Advance one rising edge and permit registered outputs to settle.
  task automatic step_clock;
    begin
      @(posedge clk);
      #1ns;
    end
  endtask

  // Drive every TB-owned input to an inactive value.
  task automatic drive_idle;
    begin
      flush = 1'b0;
      cmd_valid = 1'b0;
      cmd_write = 1'b0;
      cmd_addr = '0;
      cmd_wdata = '0;
      rsp_ready = 1'b0;
      core_debug.halt_req = 1'b0;
      core_debug.resume_req = 1'b0;
      core_debug.step_req = 1'b0;
      core_debug.halted = 1'b1;
      core_debug.running = 1'b0;
      core_debug.gpr_req_ready = 1'b0;
      core_debug.gpr_rsp_valid = 1'b0;
      core_debug.gpr_rsp_rdata = '0;
      core_debug.gpr_rsp_err = 1'b0;
    end
  endtask

  // Idle contract is reused after reset, response acceptance, and flush drain.
  task automatic expect_idle(input string label);
    begin
      if (!cmd_ready || rsp_valid || core_debug.gpr_req_valid ||
          core_debug.gpr_rsp_ready) begin
        $error("%s: ready=%0b rsp_valid=%0b core_req=%0b core_rsp_ready=%0b",
               label, cmd_ready, rsp_valid, core_debug.gpr_req_valid,
               core_debug.gpr_rsp_ready);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Apply reset and verify the one-command sequencer returns idle.
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

  // Capture one upstream command and verify the core request fields.
  task automatic start_command(
    input logic write_value,
    input logic [4:0] addr_value,
    input logic [31:0] data_value,
    input string label
  );
    begin
      @(negedge clk);
      if (!cmd_ready) begin
        $error("%s: command unexpectedly not ready", label);
        $fatal(1);
      end
      cmd_valid = 1'b1;
      cmd_write = write_value;
      cmd_addr = addr_value;
      cmd_wdata = data_value;
      step_clock();
      cmd_valid = 1'b0;
      if (!core_debug.gpr_req_valid ||
          (core_debug.gpr_req_write !== write_value) ||
          (core_debug.gpr_req_addr !== addr_value) ||
          (core_debug.gpr_req_wdata !== data_value) || cmd_ready) begin
        $error("%s: captured core request mismatch", label);
        $fatal(1);
      end
      if (write_value) write_count++;
      else read_count++;
      pass_count++;
    end
  endtask

  // Hold core request backpressure and check every field remains unchanged.
  task automatic hold_core_request(input int unsigned cycles, input string label);
    logic        held_write;
    logic [4:0]  held_addr;
    logic [31:0] held_data;
    begin
      held_write = core_debug.gpr_req_write;
      held_addr = core_debug.gpr_req_addr;
      held_data = core_debug.gpr_req_wdata;
      core_debug.gpr_req_ready = 1'b0;
      repeat (cycles) begin
        step_clock();
        if (!core_debug.gpr_req_valid ||
            (core_debug.gpr_req_write !== held_write) ||
            (core_debug.gpr_req_addr !== held_addr) ||
            (core_debug.gpr_req_wdata !== held_data)) begin
          $error("%s: request changed under backpressure", label);
          $fatal(1);
        end
        req_hold_count++;
        pass_count++;
      end
    end
  endtask

  // Accept a request without returning a same-cycle response.
  task automatic accept_core_request(input string label);
    begin
      @(negedge clk);
      core_debug.gpr_req_ready = 1'b1;
      core_debug.gpr_rsp_valid = 1'b0;
      step_clock();
      core_debug.gpr_req_ready = 1'b0;
      if (core_debug.gpr_req_valid || !core_debug.gpr_rsp_ready || rsp_valid) begin
        $error("%s: did not enter response wait", label);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Return a core response and verify it becomes the held upstream response.
  task automatic send_core_response(
    input logic [31:0] data_value,
    input logic error_value,
    input string label
  );
    begin
      @(negedge clk);
      if (!core_debug.gpr_rsp_ready) begin
        $error("%s: core response unexpectedly not ready", label);
        $fatal(1);
      end
      core_debug.gpr_rsp_valid = 1'b1;
      core_debug.gpr_rsp_rdata = data_value;
      core_debug.gpr_rsp_err = error_value;
      step_clock();
      core_debug.gpr_rsp_valid = 1'b0;
      if (!rsp_valid || (rsp_rdata !== data_value) || (rsp_error !== error_value)) begin
        $error("%s: local response mismatch data=0x%08h err=%0b",
               label, rsp_rdata, rsp_error);
        $fatal(1);
      end
      if (error_value) core_error_count++;
      pass_count++;
    end
  endtask

  // Accept request and response on one edge to cover zero-latency core access.
  task automatic accept_same_cycle_response(
    input logic [31:0] data_value,
    input logic error_value,
    input string label
  );
    begin
      @(negedge clk);
      core_debug.gpr_req_ready = 1'b1;
      core_debug.gpr_rsp_valid = 1'b1;
      core_debug.gpr_rsp_rdata = data_value;
      core_debug.gpr_rsp_err = error_value;
      #1ns;
      if (!core_debug.gpr_rsp_ready) begin
        $error("%s: same-cycle response was not ready", label);
        $fatal(1);
      end
      step_clock();
      core_debug.gpr_req_ready = 1'b0;
      core_debug.gpr_rsp_valid = 1'b0;
      if (!rsp_valid || (rsp_rdata !== data_value) || (rsp_error !== error_value)) begin
        $error("%s: same-cycle response mismatch", label);
        $fatal(1);
      end
      same_cycle_count++;
      if (error_value) core_error_count++;
      pass_count++;
    end
  endtask

  // Hold upstream backpressure and verify response storage is stable.
  task automatic hold_local_response(input int unsigned cycles, input string label);
    logic [31:0] held_data;
    logic held_error;
    begin
      held_data = rsp_rdata;
      held_error = rsp_error;
      rsp_ready = 1'b0;
      repeat (cycles) begin
        step_clock();
        if (!rsp_valid || (rsp_rdata !== held_data) || (rsp_error !== held_error)) begin
          $error("%s: response changed under backpressure", label);
          $fatal(1);
        end
        rsp_hold_count++;
        pass_count++;
      end
    end
  endtask

  // Complete the upstream handshake and return to idle.
  task automatic accept_local_response(input string label);
    begin
      @(negedge clk);
      rsp_ready = 1'b1;
      step_clock();
      rsp_ready = 1'b0;
      expect_idle(label);
    end
  endtask

  // Directed read/write/backpressure/same-cycle/error behavior.
  task automatic check_normal_paths;
    begin
      start_command(1'b0, 5'd7, 32'h0000_0000, "read x7");
      hold_core_request(3, "read request hold");
      accept_core_request("read request accept");
      repeat (2) begin
        step_clock();
        if (!core_debug.gpr_rsp_ready || rsp_valid) begin
          $error("read delayed response wait mismatch");
          $fatal(1);
        end
        pass_count++;
      end
      send_core_response(32'h1234_5678, 1'b0, "read response");
      hold_local_response(2, "read response hold");
      accept_local_response("read response accept");

      start_command(1'b1, 5'd12, 32'hCAFE_BABE, "write x12");
      accept_same_cycle_response(32'h0000_0000, 1'b0, "write same cycle");
      accept_local_response("write response accept");

      start_command(1'b0, 5'd31, 32'h0000_0000, "error read");
      accept_core_request("error request accept");
      send_core_response(32'hDEAD_BEEF, 1'b1, "core error response");
      accept_local_response("error response accept");
    end
  endtask

  // Flush before request acceptance suppresses the core transaction.
  task automatic check_flush_core_request;
    begin
      start_command(1'b0, 5'd3, '0, "flush core request");
      @(negedge clk);
      flush = 1'b1;
      #1ns;
      if (core_debug.gpr_req_valid || cmd_ready) begin
        $error("flush did not gate unaccepted request");
        $fatal(1);
      end
      step_clock();
      flush = 1'b0;
      #1ns;
      expect_idle("flush unaccepted returns idle");
      flush_count++;
    end
  endtask

  // Flush an accepted request, block new commands, and drain stale response.
  task automatic check_flush_wait_and_drain;
    begin
      start_command(1'b0, 5'd9, '0, "flush wait request");
      accept_core_request("flush wait accepted");
      flush = 1'b1;
      step_clock();
      flush = 1'b0;
      cmd_valid = 1'b1;
      #1ns;
      if (cmd_ready || !core_debug.gpr_rsp_ready || rsp_valid) begin
        $error("drain state did not block command or ready stale response");
        $fatal(1);
      end
      cmd_valid = 1'b0;
      @(negedge clk);
      core_debug.gpr_rsp_valid = 1'b1;
      core_debug.gpr_rsp_rdata = 32'hAAAA_5555;
      core_debug.gpr_rsp_err = 1'b0;
      step_clock();
      core_debug.gpr_rsp_valid = 1'b0;
      if (rsp_valid) begin
        $error("stale drained response escaped upstream");
        $fatal(1);
      end
      expect_idle("stale response drained");
      flush_count++;
      drain_count++;
    end
  endtask

  // A response coincident with flush is consumed and discarded immediately.
  task automatic check_flush_with_response;
    begin
      start_command(1'b0, 5'd10, '0, "flush response request");
      accept_core_request("flush response accepted");
      @(negedge clk);
      flush = 1'b1;
      core_debug.gpr_rsp_valid = 1'b1;
      core_debug.gpr_rsp_rdata = 32'h1111_2222;
      core_debug.gpr_rsp_err = 1'b0;
      step_clock();
      flush = 1'b0;
      core_debug.gpr_rsp_valid = 1'b0;
      #1ns;
      if (rsp_valid) begin
        $error("flush-coincident core response escaped upstream");
        $fatal(1);
      end
      expect_idle("flush with response idle");
      flush_count++;
    end
  endtask

  // Flush discards a response already buffered for the upstream consumer.
  task automatic check_flush_local_response;
    begin
      start_command(1'b0, 5'd11, '0, "flush local response request");
      accept_core_request("flush local accepted");
      send_core_response(32'h3333_4444, 1'b0, "flush local captured");
      flush = 1'b1;
      step_clock();
      flush = 1'b0;
      #1ns;
      if (rsp_valid) begin
        $error("flush did not discard local response");
        $fatal(1);
      end
      expect_idle("flush local response idle");
      flush_count++;
    end
  endtask

  // Asynchronous reset while busy must immediately restore the reset contract.
  task automatic check_reset_abort;
    begin
      start_command(1'b1, 5'd5, 32'h5555_AAAA, "reset abort request");
      rst_n = 1'b0;
      #1ns;
      if (!cmd_ready || core_debug.gpr_req_valid || rsp_valid) begin
        $error("asynchronous reset did not restore idle outputs");
        $fatal(1);
      end
      repeat (2) @(posedge clk);
      rst_n = 1'b1;
      step_clock();
      expect_idle("reset abort idle");
      reset_abort_count++;
    end
  endtask

  // Execute deterministic-random transactions against the local GPR model.
  task automatic check_random_transactions(input int unsigned iterations);
    logic write_value;
    logic [4:0] addr_value;
    logic [31:0] write_data;
    logic [31:0] response_data;
    logic error_value;
    int unsigned request_delay;
    int unsigned response_delay;
    int unsigned local_delay;
    begin
      void'($urandom(32'h5245_4741));
      for (int unsigned idx = 0; idx < 32; idx++) begin
        model_gpr[idx] = 32'h1000_0000 + 32'(idx);
      end
      model_gpr[0] = 32'h0000_0000;

      for (int unsigned idx = 0; idx < iterations; idx++) begin
        write_value = 1'($urandom_range(0, 1));
        addr_value = 5'($urandom_range(0, 31));
        write_data = $urandom();
        error_value = ((idx % 7) == 6);
        response_data = write_value ? 32'h0000_0000 : model_gpr[addr_value];
        request_delay = $urandom_range(0, 3);
        response_delay = $urandom_range(0, 3);
        local_delay = $urandom_range(0, 2);

        start_command(write_value, addr_value, write_data, "random command");
        hold_core_request(request_delay, "random request hold");
        if ((idx % 5) == 0) begin
          accept_same_cycle_response(response_data, error_value, "random same cycle");
        end else begin
          accept_core_request("random request accept");
          repeat (response_delay) begin
            step_clock();
            if (!core_debug.gpr_rsp_ready || rsp_valid) begin
              $error("random delayed response wait mismatch");
              $fatal(1);
            end
            pass_count++;
          end
          send_core_response(response_data, error_value, "random core response");
        end
        hold_local_response(local_delay, "random local response hold");
        accept_local_response("random response accepted");

        if (write_value && !error_value && (addr_value != 5'd0)) begin
          model_gpr[addr_value] = write_data;
        end
        model_gpr[0] = 32'h0000_0000;
        random_count++;
      end
    end
  endtask

  initial begin
    pass_count = 0;
    read_count = 0;
    write_count = 0;
    req_hold_count = 0;
    rsp_hold_count = 0;
    same_cycle_count = 0;
    core_error_count = 0;
    flush_count = 0;
    drain_count = 0;
    reset_abort_count = 0;
    random_count = 0;
    rst_n = 1'b1;

    $display("phase reset start=%0t", $time);
    apply_reset();
    $display("phase normal start=%0t", $time);
    check_normal_paths();
    $display("phase flush start=%0t", $time);
    check_flush_core_request();
    check_flush_wait_and_drain();
    check_flush_with_response();
    check_flush_local_response();
    $display("phase reset_abort start=%0t", $time);
    check_reset_abort();
    $display("phase random start=%0t", $time);
    check_random_transactions(20);
    $display("phase complete=%0t", $time);

    $display("tb_debug_reg_access coverage: pass=%0d read=%0d write=%0d req_hold=%0d rsp_hold=%0d same_cycle=%0d core_error=%0d flush=%0d drain=%0d reset_abort=%0d random=%0d",
             pass_count, read_count, write_count, req_hold_count, rsp_hold_count,
             same_cycle_count, core_error_count, flush_count, drain_count,
             reset_abort_count, random_count);
    $display("tb_debug_reg_access PASS");
    $finish;
  end
endmodule
