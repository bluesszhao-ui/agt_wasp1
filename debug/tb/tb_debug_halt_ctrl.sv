`timescale 1ns/1ps

// Self-checking verification environment for single-hart halt/resume control.
module tb_debug_halt_ctrl;
  localparam time CLK_PERIOD = 10ns;

  // DUT clock/reset and Debug Module control intent.
  logic clk;
  logic rst_n;
  logic dmactive;
  logic haltreq;
  logic resumereq;
  logic ackhavereset;
  logic hart_reset_event;

  // Mock core status and DUT request/status outputs.
  logic core_halted;
  logic core_running;
  logic core_halt_req;
  logic core_resume_req;
  logic hart_halted;
  logic hart_running;
  logic hart_resumeack;
  logic hart_havereset;

  // Functional coverage counters are printed in the final PASS line.
  int unsigned pass_count;
  int unsigned halt_count;
  int unsigned resume_count;
  int unsigned cancel_count;
  int unsigned priority_count;
  int unsigned reset_count;
  int unsigned inactive_count;
  int unsigned sticky_count;
  int unsigned held_cycle_count;
  int unsigned random_count;

  debug_halt_ctrl u_debug_halt_ctrl (
    .clk_i(clk),
    .rst_ni(rst_n),
    .dmactive_i(dmactive),
    .haltreq_i(haltreq),
    .resumereq_i(resumereq),
    .ackhavereset_i(ackhavereset),
    .hart_reset_event_i(hart_reset_event),
    .core_halted_i(core_halted),
    .core_running_i(core_running),
    .core_halt_req_o(core_halt_req),
    .core_resume_req_o(core_resume_req),
    .hart_halted_o(hart_halted),
    .hart_running_o(hart_running),
    .hart_resumeack_o(hart_resumeack),
    .hart_havereset_o(hart_havereset)
  );

  // Project-default 100 MHz verification clock.
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Advance one active edge and allow sequential/combinational settling.
  task automatic step_clock;
    begin
      @(posedge clk);
      #1ns;
    end
  endtask

  // Compare every externally visible result for a named verification point.
  task automatic expect_outputs(
    input logic expected_halt_req,
    input logic expected_resume_req,
    input logic expected_halted,
    input logic expected_running,
    input logic expected_resumeack,
    input logic expected_havereset,
    input string label
  );
    begin
      if ((core_halt_req !== expected_halt_req) ||
          (core_resume_req !== expected_resume_req) ||
          (hart_halted !== expected_halted) ||
          (hart_running !== expected_running) ||
          (hart_resumeack !== expected_resumeack) ||
          (hart_havereset !== expected_havereset)) begin
        $error("%s: halt_req=%0b resume_req=%0b halted=%0b running=%0b ack=%0b reset=%0b",
               label, core_halt_req, core_resume_req, hart_halted,
               hart_running, hart_resumeack, hart_havereset);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Drive a known running-core baseline before each independent case.
  task automatic drive_running_baseline;
    begin
      haltreq = 1'b0;
      resumereq = 1'b0;
      ackhavereset = 1'b0;
      hart_reset_event = 1'b0;
      core_halted = 1'b0;
      core_running = 1'b1;
    end
  endtask

  // Reset must set havereset while leaving requests and resume ack clear.
  task automatic apply_reset;
    begin
      dmactive = 1'b0;
      drive_running_baseline();
      rst_n = 1'b0;
      repeat (3) @(posedge clk);
      rst_n = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, "reset image");
      reset_count++;
    end
  endtask

  // Inactive DM requests must never escape toward the core.
  task automatic check_inactive;
    begin
      haltreq = 1'b1;
      resumereq = 1'b1;
      repeat (2) step_clock();
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, "inactive requests blocked");
      inactive_count++;
      drive_running_baseline();
    end
  endtask

  // Verify sticky reset acknowledgement and reset-event priority over clear.
  task automatic check_reset_status;
    begin
      dmactive = 1'b1;
      ackhavereset = 1'b1;
      step_clock();
      ackhavereset = 1'b0;
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "clear havereset");

      ackhavereset = 1'b1;
      hart_reset_event = 1'b1;
      step_clock();
      ackhavereset = 1'b0;
      hart_reset_event = 1'b0;
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b1, "reset event beats ack");

      ackhavereset = 1'b1;
      step_clock();
      ackhavereset = 1'b0;
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "clear event report");
      reset_count += 2;
    end
  endtask

  // Normal halt holds its request over arbitrary core response latency.
  task automatic check_halt(input int unsigned latency);
    logic expected_ack;
    begin
      drive_running_baseline();
      expected_ack = hart_resumeack;
      haltreq = 1'b1;
      step_clock();
      expect_outputs(1'b1, 1'b0, 1'b0, 1'b1, expected_ack,
                     hart_havereset, "halt starts");
      repeat (latency) begin
        step_clock();
        expect_outputs(1'b1, 1'b0, 1'b0, 1'b1, expected_ack,
                       hart_havereset, "halt held");
        held_cycle_count++;
      end
      core_running = 1'b0;
      core_halted = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, expected_ack,
                     hart_havereset, "halt completes");
      halt_count++;
    end
  endtask

  // Clearing haltreq before core acknowledgement cancels the transaction.
  task automatic check_halt_cancel;
    logic expected_ack;
    begin
      drive_running_baseline();
      expected_ack = hart_resumeack;
      haltreq = 1'b1;
      step_clock();
      expect_outputs(1'b1, 1'b0, 1'b0, 1'b1, expected_ack,
                     hart_havereset, "cancel halt starts");
      haltreq = 1'b0;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, expected_ack,
                     hart_havereset, "halt cancelled");
      cancel_count++;
    end
  endtask

  // An already halted hart requires no additional halt request.
  task automatic check_already_halted;
    begin
      haltreq = 1'b1;
      resumereq = 1'b0;
      core_running = 1'b0;
      core_halted = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, hart_resumeack,
                     hart_havereset, "already halted");
      haltreq = 1'b0;
      halt_count++;
    end
  endtask

  // Normal resume holds until running, then leaves a sticky polling result.
  task automatic check_resume(input int unsigned latency);
    begin
      haltreq = 1'b0;
      resumereq = 1'b1;
      core_running = 1'b0;
      core_halted = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, hart_havereset, "resume starts");
      repeat (latency) begin
        step_clock();
        expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, hart_havereset, "resume held");
        held_cycle_count++;
      end
      core_halted = 1'b0;
      core_running = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b1, hart_havereset, "resume completes");
      resumereq = 1'b0;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b1, hart_havereset, "resume ack sticky");
      resume_count++;
      sticky_count++;
    end
  endtask

  // A new resume clears the previous ack; halt can then preempt the wait.
  task automatic check_new_resume_and_priority;
    begin
      core_running = 1'b0;
      core_halted = 1'b1;
      resumereq = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, hart_havereset, "new resume clears ack");
      haltreq = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, hart_havereset, "halt preempts resume");
      haltreq = 1'b0;
      resumereq = 1'b0;
      priority_count++;
      sticky_count++;
    end
  endtask

  // A running hart acknowledges resume without an unnecessary core request.
  task automatic check_already_running;
    begin
      core_halted = 1'b0;
      core_running = 1'b1;
      resumereq = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b1, hart_havereset, "already running resume");
      resumereq = 1'b0;
      resume_count++;
    end
  endtask

  // Simultaneous halt/resume in IDLE must select the halt transaction.
  task automatic check_simultaneous_priority;
    begin
      core_halted = 1'b0;
      core_running = 1'b1;
      haltreq = 1'b1;
      resumereq = 1'b1;
      step_clock();
      expect_outputs(1'b1, 1'b0, 1'b0, 1'b1, 1'b0, hart_havereset, "halt priority in idle");
      core_halted = 1'b1;
      core_running = 1'b0;
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, hart_havereset, "priority halt completes");
      haltreq = 1'b0;
      resumereq = 1'b0;
      priority_count++;
    end
  endtask

  // DM deactivation immediately gates a pending request and clears resume ack.
  task automatic check_deactivate_abort;
    begin
      drive_running_baseline();
      haltreq = 1'b1;
      step_clock();
      expect_outputs(1'b1, 1'b0, 1'b0, 1'b1, hart_resumeack, hart_havereset,
                     "deactivate halt starts");
      dmactive = 1'b0;
      #1ns;
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, hart_resumeack, hart_havereset,
                     "deactivate gates request");
      step_clock();
      expect_outputs(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, hart_havereset,
                     "deactivate clears state");
      dmactive = 1'b1;
      haltreq = 1'b0;
      inactive_count++;
      cancel_count++;
    end
  endtask

  // A hart reset aborts an active resume and restores sticky reset status.
  task automatic check_reset_abort;
    begin
      core_halted = 1'b1;
      core_running = 1'b0;
      resumereq = 1'b1;
      step_clock();
      expect_outputs(1'b0, 1'b1, 1'b1, 1'b0, 1'b0, hart_havereset, "reset abort starts");
      hart_reset_event = 1'b1;
      step_clock();
      hart_reset_event = 1'b0;
      resumereq = 1'b0;
      expect_outputs(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 1'b1, "reset aborts resume");
      ackhavereset = 1'b1;
      step_clock();
      ackhavereset = 1'b0;
      reset_count++;
      cancel_count++;
    end
  endtask

  // Repeat complete halt/resume pairs with deterministic random response delay.
  task automatic check_random_sequences(input int unsigned iterations);
    int unsigned halt_latency;
    int unsigned resume_latency;
    begin
      void'($urandom(32'h4841_5254));
      for (int unsigned idx = 0; idx < iterations; idx++) begin
        halt_latency = $urandom_range(1, 4);
        resume_latency = $urandom_range(1, 4);
        check_halt(halt_latency);
        haltreq = 1'b0;
        check_resume(resume_latency);
        random_count++;
      end
    end
  endtask

  initial begin
    pass_count = 0;
    halt_count = 0;
    resume_count = 0;
    cancel_count = 0;
    priority_count = 0;
    reset_count = 0;
    inactive_count = 0;
    sticky_count = 0;
    held_cycle_count = 0;
    random_count = 0;
    rst_n = 1'b1;

    $display("phase reset start=%0t", $time);
    apply_reset();
    $display("phase inactive start=%0t", $time);
    check_inactive();
    $display("phase reset_status start=%0t", $time);
    check_reset_status();
    $display("phase directed_halt start=%0t", $time);
    check_halt(3);
    check_already_halted();
    check_halt_cancel();
    $display("phase directed_resume start=%0t", $time);
    check_resume(3);
    check_new_resume_and_priority();
    check_already_running();
    check_simultaneous_priority();
    $display("phase aborts start=%0t", $time);
    check_deactivate_abort();
    check_reset_abort();
    $display("phase random start=%0t", $time);
    check_random_sequences(8);
    $display("phase complete=%0t", $time);

    $display("tb_debug_halt_ctrl coverage: pass=%0d halt=%0d resume=%0d cancel=%0d priority=%0d reset=%0d inactive=%0d sticky=%0d held_cycles=%0d random=%0d",
             pass_count, halt_count, resume_count, cancel_count, priority_count,
             reset_count, inactive_count, sticky_count, held_cycle_count, random_count);
    $display("tb_debug_halt_ctrl PASS");
    $finish;
  end
endmodule
