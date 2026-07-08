`timescale 1ns/1ps

module tb_core_debug_ctrl;
  logic clk;          // 100 MHz verification clock.
  logic rst_n;        // Active-low reset.
  logic halt_req;     // Debug halt request stimulus.
  logic trigger_req;  // Execute-address trigger request stimulus.
  logic resume_req;   // Debug resume request stimulus.
  logic step_req;     // Debug single-step request stimulus.
  logic pipe_idle;    // Pipeline-drained stimulus.
  logic retire_valid; // One-instruction retirement stimulus.
  logic debug_busy;   // Pending GPR response stimulus.
  logic stop_fetch;   // DUT fetch-stop output.
  logic freeze_pipe;  // DUT halted pipe-freeze output.
  logic halted;       // DUT halted status output.
  logic running;      // DUT running status output.

  integer pass_count;   // Total passing self-checks.
  integer halt_count;   // Halt-entry coverage.
  integer resume_count; // Resume coverage.
  integer step_count;   // Single-step coverage.
  integer busy_count;   // Busy-response blocking coverage.
  integer cancel_count; // Halt-pending cancel coverage.
  integer priority_count;// Halt-priority coverage.
  integer trigger_count;// Trigger-entry coverage.

  core_debug_ctrl dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .halt_req_i(halt_req),
    .trigger_req_i(trigger_req),
    .resume_req_i(resume_req),
    .step_req_i(step_req),
    .pipe_idle_i(pipe_idle),
    .retire_valid_i(retire_valid),
    .debug_busy_i(debug_busy),
    .stop_fetch_o(stop_fetch),
    .freeze_pipe_o(freeze_pipe),
    .halted_o(halted),
    .running_o(running)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  task automatic drive_idle_running;
    begin
      rst_n = 1'b0;
      halt_req = 1'b0;
      trigger_req = 1'b0;
      resume_req = 1'b0;
      step_req = 1'b0;
      pipe_idle = 1'b1;
      retire_valid = 1'b0;
      debug_busy = 1'b0;
      repeat (2) @(posedge clk);
      rst_n = 1'b1;
      @(posedge clk);
      #1;
      if (!running || halted || stop_fetch || freeze_pipe) begin
        $fatal(1, "running baseline mismatch run=%0b halt=%0b stop=%0b freeze=%0b",
               running, halted, stop_fetch, freeze_pipe);
      end
      pass_count++;
    end
  endtask

  task automatic check_immediate_halt;
    begin
      drive_idle_running();
      @(negedge clk);
      halt_req = 1'b1;
      #1;
      if (!stop_fetch || halted) begin
        $fatal(1, "immediate halt pre-edge mismatch stop=%0b halted=%0b",
               stop_fetch, halted);
      end
      @(posedge clk);
      #1;
      if (!halted || running || !freeze_pipe || !stop_fetch) begin
        $fatal(1, "immediate halt mismatch halt=%0b run=%0b freeze=%0b stop=%0b",
               halted, running, freeze_pipe, stop_fetch);
      end
      pass_count++;
      halt_count++;
    end
  endtask

  task automatic check_drain_halt;
    begin
      drive_idle_running();
      @(negedge clk);
      pipe_idle = 1'b0;
      halt_req = 1'b1;
      @(posedge clk);
      #1;
      if (halted || running || !stop_fetch || freeze_pipe) begin
        $fatal(1, "halt-pending mismatch halt=%0b run=%0b stop=%0b freeze=%0b",
               halted, running, stop_fetch, freeze_pipe);
      end
      @(negedge clk);
      pipe_idle = 1'b1;
      @(posedge clk);
      #1;
      if (!halted || running || !freeze_pipe) begin
        $fatal(1, "drain halt completion mismatch");
      end
      pass_count++;
      halt_count++;
    end
  endtask

  task automatic check_trigger_halt;
    begin
      drive_idle_running();
      @(negedge clk);
      pipe_idle = 1'b0;
      trigger_req = 1'b1;
      #1;
      if (!stop_fetch || halted) begin
        $fatal(1, "trigger pre-edge mismatch stop=%0b halted=%0b",
               stop_fetch, halted);
      end
      @(posedge clk);
      #1;
      if (halted || running || !stop_fetch || freeze_pipe) begin
        $fatal(1, "trigger pending mismatch halt=%0b run=%0b stop=%0b freeze=%0b",
               halted, running, stop_fetch, freeze_pipe);
      end
      @(negedge clk);
      pipe_idle = 1'b1;
      trigger_req = 1'b0;
      @(posedge clk);
      #1;
      if (!halted || running || !freeze_pipe || !stop_fetch) begin
        $fatal(1, "trigger halt completion mismatch");
      end
      pass_count++;
      halt_count++;
      trigger_count++;
    end
  endtask

  task automatic check_cancel_pending;
    begin
      drive_idle_running();
      @(negedge clk);
      pipe_idle = 1'b0;
      halt_req = 1'b1;
      @(posedge clk);
      @(negedge clk);
      halt_req = 1'b0;
      resume_req = 1'b1;
      @(posedge clk);
      #1;
      if (!running || halted || stop_fetch) begin
        $fatal(1, "halt cancel mismatch run=%0b halt=%0b stop=%0b",
               running, halted, stop_fetch);
      end
      pass_count++;
      cancel_count++;
    end
  endtask

  task automatic check_resume_and_busy;
    begin
      check_immediate_halt();
      @(negedge clk);
      halt_req = 1'b0;
      debug_busy = 1'b1;
      resume_req = 1'b1;
      @(posedge clk);
      #1;
      if (!halted || !freeze_pipe) begin
        $fatal(1, "busy resume should remain halted");
      end
      busy_count++;
      @(negedge clk);
      debug_busy = 1'b0;
      @(posedge clk);
      #1;
      if (!running || halted || stop_fetch) begin
        $fatal(1, "resume after busy mismatch run=%0b halt=%0b stop=%0b",
               running, halted, stop_fetch);
      end
      pass_count++;
      resume_count++;
    end
  endtask

  task automatic check_step;
    begin
      check_immediate_halt();
      @(negedge clk);
      halt_req = 1'b0;
      step_req = 1'b1;
      @(posedge clk);
      #1;
      if (!running || halted || stop_fetch) begin
        $fatal(1, "step release mismatch");
      end
      @(negedge clk);
      step_req = 1'b0;
      pipe_idle = 1'b0;
      retire_valid = 1'b1;
      @(posedge clk);
      #1;
      if (halted || running || !stop_fetch) begin
        $fatal(1, "step retire should enter halt-pending");
      end
      @(negedge clk);
      retire_valid = 1'b0;
      pipe_idle = 1'b1;
      @(posedge clk);
      #1;
      if (!halted || running || !freeze_pipe) begin
        $fatal(1, "step rehalt mismatch");
      end
      pass_count++;
      step_count++;
    end
  endtask

  task automatic check_halt_priority;
    begin
      check_immediate_halt();
      @(negedge clk);
      resume_req = 1'b1;
      step_req = 1'b1;
      halt_req = 1'b1;
      @(posedge clk);
      #1;
      if (!halted || !freeze_pipe || running) begin
        $fatal(1, "halt priority mismatch");
      end
      pass_count++;
      priority_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    halt_count = 0;
    resume_count = 0;
    step_count = 0;
    busy_count = 0;
    cancel_count = 0;
    priority_count = 0;
    trigger_count = 0;

    halt_req = 1'b0;
    trigger_req = 1'b0;
    resume_req = 1'b0;
    step_req = 1'b0;
    pipe_idle = 1'b1;
    retire_valid = 1'b0;
    debug_busy = 1'b0;
    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    #1;
    rst_n = 1'b1;

    drive_idle_running();
    check_immediate_halt();
    check_drain_halt();
    check_trigger_halt();
    check_cancel_pending();
    check_resume_and_busy();
    check_step();
    check_halt_priority();

    if (pass_count < 10 || halt_count < 4 || resume_count < 1 ||
        step_count < 1 || busy_count < 1 || cancel_count < 1 ||
        priority_count < 1 || trigger_count < 1) begin
      $fatal(1, "core_debug_ctrl coverage goal missed");
    end

    $display("tb_core_debug_ctrl coverage: pass=%0d halt=%0d resume=%0d step=%0d busy=%0d cancel=%0d priority=%0d trigger=%0d",
             pass_count, halt_count, resume_count, step_count, busy_count,
             cancel_count, priority_count, trigger_count);
    $display("tb_core_debug_ctrl PASS");
    $finish;
  end
endmodule
