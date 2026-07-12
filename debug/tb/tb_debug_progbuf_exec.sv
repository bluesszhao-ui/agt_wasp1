`timescale 1ns/1ps

// Self-checking protocol, error, abort, and deterministic-random testbench for
// the Program Buffer execution sequencer.
module tb_debug_progbuf_exec;
  import debug_dmi_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int INDEX_WIDTH = $clog2(PROGBUF_WORD_COUNT);

  logic clk;                                      // 100 MHz verification clock.
  logic rst_n;                                    // Active-low asynchronous reset stimulus.
  logic dmactive;                                 // Debug Module activation stimulus.
  logic hart_halted;                              // Mock halted-hart status.
  logic start;                                    // One-cycle execution start pulse.
  logic [PROGBUF_WORD_COUNT-1:0][31:0] words;     // Program Buffer test image.
  logic busy;                                     // DUT operation-active indication.
  logic done;                                     // DUT one-cycle completion pulse.
  logic [2:0] error;                              // DUT abstract-command completion error.
  logic instr_valid;                              // DUT instruction request valid.
  logic instr_ready;                              // Mock core request acceptance.
  logic [31:0] instr;                             // DUT current instruction payload.
  logic [INDEX_WIDTH-1:0] instr_index;            // DUT current word index.
  logic instr_rsp_valid;                          // Mock core completion valid.
  logic instr_rsp_ready;                          // DUT completion acceptance.
  logic instr_rsp_error;                          // Mock core execution-fault injection.

  int unsigned pass_count;                        // Completed self-checking scenarios.
  int unsigned request_count;                     // Accepted core instruction requests.
  int unsigned response_count;                    // Accepted core completion responses.
  int unsigned backpressure_count;                // Cycles checking stable stalled requests.
  int unsigned exception_count;                   // Core/missing-EBREAK exception completions.
  int unsigned halt_loss_count;                   // Halt-loss completion points covered.
  int unsigned dm_abort_count;                    // DM-abort points covered.
  int unsigned inactive_start_count;              // Start ignored while DM is inactive.
  int unsigned reset_abort_count;                 // Reset-abort path coverage.
  int unsigned busy_start_count;                  // Ignored start while busy coverage.
  int unsigned random_count;                      // Seeded random legal sequences.
  logic [PROGBUF_WORD_COUNT-1:0] index_seen;      // Physical word request coverage.

  debug_progbuf_exec u_debug_progbuf_exec (
    .clk_i(clk),
    .rst_ni(rst_n),
    .dmactive_i(dmactive),
    .hart_halted_i(hart_halted),
    .start_i(start),
    .words_i(words),
    .busy_o(busy),
    .done_o(done),
    .error_o(error),
    .instr_valid_o(instr_valid),
    .instr_ready_i(instr_ready),
    .instr_o(instr),
    .instr_index_o(instr_index),
    .instr_rsp_valid_i(instr_rsp_valid),
    .instr_rsp_ready_o(instr_rsp_ready),
    .instr_rsp_error_i(instr_rsp_error)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Start one operation on a clean rising edge.
  task automatic pulse_start;
    begin
      @(negedge clk);
      start = 1'b1;
      @(posedge clk);
      #1ns;
      start = 1'b0;
    end
  endtask

  // Accept one expected instruction after an optional request stall. Every
  // stalled cycle checks ready/valid stability explicitly.
  task automatic accept_instruction(
    input int unsigned expected_index,
    input int unsigned stall_cycles,
    input logic inject_busy_start
  );
    logic [31:0] held_instr;
    begin
      while (!instr_valid) begin
        @(posedge clk);
        #1ns;
      end
      held_instr = words[expected_index];
      if ((instr_index !== INDEX_WIDTH'(expected_index)) ||
          (instr !== held_instr)) begin
        $fatal(1, "request mismatch index=%0d instr=0x%08x expected_index=%0d expected=0x%08x",
               instr_index, instr, expected_index, held_instr);
      end

      for (int unsigned wait_cycle = 0; wait_cycle < stall_cycles; wait_cycle++) begin
        @(posedge clk);
        #1ns;
        if (!instr_valid || (instr_index !== INDEX_WIDTH'(expected_index)) ||
            (instr !== held_instr)) begin
          $fatal(1, "request changed under backpressure");
        end
        backpressure_count++;
      end

      if (inject_busy_start) begin
        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
        #1ns;
        start = 1'b0;
        if (!instr_valid || (instr_index !== INDEX_WIDTH'(expected_index))) begin
          $fatal(1, "busy start disturbed outstanding request");
        end
        busy_start_count++;
      end

      @(negedge clk);
      instr_ready = 1'b1;
      @(posedge clk);
      #1ns;
      instr_ready = 1'b0;
      request_count++;
      index_seen[expected_index] = 1'b1;
    end
  endtask

  // Return one mock core response after checking WAIT-state stability for the
  // requested number of cycles.
  task automatic return_response(
    input logic response_error,
    input int unsigned latency_cycles
  );
    begin
      for (int unsigned wait_cycle = 0; wait_cycle < latency_cycles; wait_cycle++) begin
        @(posedge clk);
        #1ns;
        if (!busy || !instr_rsp_ready) begin
          $fatal(1, "executor left WAIT before response");
        end
      end

      @(negedge clk);
      instr_rsp_valid = 1'b1;
      instr_rsp_error = response_error;
      @(posedge clk);
      #1ns;
      instr_rsp_valid = 1'b0;
      instr_rsp_error = 1'b0;
      response_count++;
    end
  endtask

  // Wait for the registered completion cycle and verify the abstract error.
  task automatic expect_done(input logic [2:0] expected_error, input string label);
    int unsigned timeout;
    begin
      timeout = 0;
      while (!done && (timeout < 40)) begin
        @(posedge clk);
        #1ns;
        timeout++;
      end
      if (!done || (error !== expected_error)) begin
        $fatal(1, "%s completion mismatch done=%0b error=%0d expected=%0d",
               label, done, error, expected_error);
      end
      @(posedge clk);
      #1ns;
      if (busy || done) $fatal(1, "%s did not return idle", label);
      pass_count++;
    end
  endtask

  // Populate ordinary ADDI instructions and place EBREAK at terminator_index.
  task automatic load_terminated_program(input int unsigned terminator_index);
    begin
      for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
        words[idx] = 32'h0010_0093 + (idx << 7);
      end
      words[terminator_index] = PROGBUF_EBREAK_INSN;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    dmactive = 1'b1;
    hart_halted = 1'b1;
    start = 1'b0;
    words = '0;
    instr_ready = 1'b0;
    instr_rsp_valid = 1'b0;
    instr_rsp_error = 1'b0;
    pass_count = 0;
    request_count = 0;
    response_count = 0;
    backpressure_count = 0;
    exception_count = 0;
    halt_loss_count = 0;
    dm_abort_count = 0;
    inactive_start_count = 0;
    reset_abort_count = 0;
    busy_start_count = 0;
    random_count = 0;
    index_seen = '0;

    $display("phase reset start=%0t", $time);
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1ns;
    if (busy || done || instr_valid || instr_rsp_ready) $fatal(1, "reset state mismatch");

    $display("phase inactive-start start=%0t", $time);
    dmactive = 1'b0;
    pulse_start();
    repeat (2) begin
      @(posedge clk);
      #1ns;
      if (busy || done || instr_valid || instr_rsp_ready || (error != CMDERR_NONE)) begin
        $fatal(1, "inactive DM accepted or retained a start request");
      end
    end
    dmactive = 1'b1;
    inactive_start_count++;

    $display("phase immediate-ebreak start=%0t", $time);
    load_terminated_program(0);
    pulse_start();
    expect_done(CMDERR_NONE, "immediate ebreak");
    if (request_count != 0) $fatal(1, "EBREAK was incorrectly issued to core");

    $display("phase ordered-backpressure start=%0t", $time);
    load_terminated_program(3);
    pulse_start();
    accept_instruction(0, 3, 1'b1);
    return_response(1'b0, 2);
    accept_instruction(1, 1, 1'b0);
    return_response(1'b0, 3);
    accept_instruction(2, 2, 1'b0);
    return_response(1'b0, 1);
    expect_done(CMDERR_NONE, "ordered execution");

    $display("phase core-exception start=%0t", $time);
    load_terminated_program(2);
    pulse_start();
    accept_instruction(0, 0, 1'b0);
    return_response(1'b1, 0);
    expect_done(CMDERR_EXCEPTION, "core exception");
    exception_count++;

    $display("phase missing-ebreak start=%0t", $time);
    for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
      words[idx] = 32'h0010_0093 + (idx << 7);
    end
    pulse_start();
    for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
      accept_instruction(idx, idx & 1, 1'b0);
      return_response(1'b0, (idx + 1) & 1);
    end
    expect_done(CMDERR_EXCEPTION, "missing ebreak");
    exception_count++;

    $display("phase halt-loss start=%0t", $time);
    load_terminated_program(2);
    pulse_start();
    while (!instr_valid) begin @(posedge clk); #1ns; end
    @(negedge clk);
    hart_halted = 1'b0;
    expect_done(CMDERR_HALT_RESUME, "halt loss in issue");
    hart_halted = 1'b1;
    halt_loss_count++;

    pulse_start();
    accept_instruction(0, 0, 1'b0);
    @(negedge clk);
    hart_halted = 1'b0;
    expect_done(CMDERR_HALT_RESUME, "halt loss in wait");
    hart_halted = 1'b1;
    halt_loss_count++;

    $display("phase dm-abort start=%0t", $time);
    pulse_start();
    while (!instr_valid) begin @(posedge clk); #1ns; end
    @(negedge clk);
    dmactive = 1'b0;
    @(posedge clk);
    #1ns;
    if (busy || done) $fatal(1, "DM abort in ISSUE was not silent");
    dmactive = 1'b1;
    dm_abort_count++;

    pulse_start();
    accept_instruction(0, 0, 1'b0);
    @(negedge clk);
    dmactive = 1'b0;
    @(posedge clk);
    #1ns;
    if (busy || done || (error != CMDERR_NONE)) $fatal(1, "DM abort in WAIT was not scrubbed");
    dmactive = 1'b1;
    dm_abort_count++;

    $display("phase reset-abort start=%0t", $time);
    pulse_start();
    accept_instruction(0, 0, 1'b0);
    @(negedge clk);
    rst_n = 1'b0;
    #1ns;
    if (busy || done || instr_rsp_ready) $fatal(1, "asynchronous reset did not abort WAIT");
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1ns;
    reset_abort_count++;

    $display("phase start-not-halted start=%0t", $time);
    hart_halted = 1'b0;
    pulse_start();
    expect_done(CMDERR_HALT_RESUME, "start while not halted");
    hart_halted = 1'b1;
    halt_loss_count++;

    $display("phase random start=%0t", $time);
    void'($urandom(32'h4558_4543));
    for (int unsigned iter = 0; iter < 64; iter++) begin
      int unsigned terminator;
      terminator = $urandom_range(PROGBUF_WORD_COUNT - 1, 0);
      load_terminated_program(terminator);
      pulse_start();
      for (int unsigned idx = 0; idx < terminator; idx++) begin
        accept_instruction(idx, $urandom_range(3, 0), 1'b0);
        return_response(1'b0, $urandom_range(3, 0));
      end
      expect_done(CMDERR_NONE, "random terminated program");
      random_count++;
    end

    if ((index_seen != '1) || (exception_count != 2) ||
        (halt_loss_count != 3) || (dm_abort_count != 2) ||
        (inactive_start_count != 1) || (reset_abort_count != 1) ||
        (busy_start_count != 1) ||
        (random_count != 64)) begin
      $fatal(1, "coverage goal missed");
    end

    $display("phase complete=%0t", $time);
    $display("tb_debug_progbuf_exec coverage: pass=%0d req=%0d rsp=%0d backpressure=%0d exception=%0d halt_loss=%0d dm_abort=%0d inactive_start=%0d reset_abort=%0d busy_start=%0d random=%0d index_seen=0x%0x",
             pass_count, request_count, response_count, backpressure_count,
             exception_count, halt_loss_count, dm_abort_count,
             inactive_start_count, reset_abort_count, busy_start_count,
             random_count, index_seen);
    $display("tb_debug_progbuf_exec PASS");
    $finish;
  end
endmodule
