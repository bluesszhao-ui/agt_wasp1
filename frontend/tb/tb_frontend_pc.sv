`timescale 1ns/1ps

module tb_frontend_pc;
  logic        clk;             // 100 MHz verification clock.
  logic        rst_n;           // Active-low reset driven by the testbench.
  logic [31:0] boot_pc;         // Boot PC used by reset checks.
  logic        stall;           // Testbench stall stimulus.
  logic        fetch_ready;     // Testbench downstream ready stimulus.
  logic        redirect_valid;  // Testbench redirect valid stimulus.
  logic [31:0] redirect_pc;     // Testbench redirect target stimulus.
  logic        pc_valid;        // DUT PC request valid.
  logic [31:0] pc;              // DUT current PC.
  logic        pc_misaligned;   // DUT misaligned PC flag.

  integer pass_count;           // Total passing checks.
  integer reset_count;          // Reset behavior coverage.
  integer advance_count;        // Sequential advance coverage.
  integer hold_count;           // Hold/backpressure coverage.
  integer stall_count;          // Stall coverage.
  integer redirect_count;       // Redirect coverage.
  integer misalign_count;       // Misaligned PC coverage.
  integer random_count;         // Deterministic-random coverage.
  logic [31:0] model_pc;        // Reference PC model.
  logic        model_valid;     // Reference valid model.
  logic [31:0] lfsr;            // Deterministic pseudo-random stimulus state.

  frontend_pc dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .boot_pc_i(boot_pc),
    .stall_i(stall),
    .fetch_ready_i(fetch_ready),
    .redirect_valid_i(redirect_valid),
    .redirect_pc_i(redirect_pc),
    .pc_valid_o(pc_valid),
    .pc_o(pc),
    .pc_misaligned_o(pc_misaligned)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Compare DUT outputs to the reference model after a clock edge.
  task automatic expect_outputs(input string name);
    begin
      #1;
      if ((pc !== model_pc) || (pc_valid !== (model_valid && !stall)) ||
          (pc_misaligned !== |model_pc[1:0])) begin
        $fatal(1, "%s mismatch pc=%08x exp=%08x valid=%0b exp_valid=%0b mis=%0b exp_mis=%0b",
               name, pc, model_pc, pc_valid, model_valid && !stall,
               pc_misaligned, |model_pc[1:0]);
      end
      pass_count++;
    end
  endtask

  // Apply one active clock cycle and update the reference model with the same
  // priority contract as the DUT: redirect, accepted fetch, hold.
  task automatic step_active(input string name);
    logic model_fire;
    begin
      model_fire = model_valid && !stall && fetch_ready;
      @(posedge clk);
      if (redirect_valid) begin
        model_pc = redirect_pc;
      end else if (model_fire) begin
        model_pc = model_pc + 32'd4;
      end
      model_valid = 1'b1;
      expect_outputs(name);
    end
  endtask

  // Advance the deterministic LFSR used by the random priority test.
  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  initial begin
    pass_count = 0;
    reset_count = 0;
    advance_count = 0;
    hold_count = 0;
    stall_count = 0;
    redirect_count = 0;
    misalign_count = 0;
    random_count = 0;
    lfsr = 32'h1ACE_B00C;

    boot_pc = 32'h0001_0000;
    stall = 1'b0;
    fetch_ready = 1'b0;
    redirect_valid = 1'b0;
    redirect_pc = 32'h0000_0000;
    rst_n = 1'b0;
    model_pc = boot_pc;
    model_valid = 1'b0;

    repeat (2) @(posedge clk);
    expect_outputs("reset hold");
    reset_count++;

    rst_n = 1'b1;
    step_active("reset release");
    reset_count++;

    fetch_ready = 1'b1;
    step_active("advance 0");
    advance_count++;

    step_active("advance 1");
    advance_count++;

    fetch_ready = 1'b0;
    step_active("ready low hold");
    hold_count++;

    stall = 1'b1;
    fetch_ready = 1'b1;
    step_active("stall hold");
    stall_count++;

    redirect_valid = 1'b1;
    redirect_pc = 32'h0002_0040;
    step_active("redirect during stall");
    redirect_count++;

    stall = 1'b0;
    redirect_valid = 1'b0;
    fetch_ready = 1'b1;
    step_active("advance after redirect");
    advance_count++;

    redirect_valid = 1'b1;
    redirect_pc = 32'h0002_0003;
    step_active("misaligned redirect");
    redirect_count++;
    if (!pc_misaligned) begin
      $fatal(1, "misaligned redirect did not assert pc_misaligned");
    end
    misalign_count++;

    redirect_valid = 1'b1;
    redirect_pc = 32'h0003_0000;
    step_active("redirect priority over fetch");
    redirect_count++;

    redirect_valid = 1'b0;
    repeat (100) begin
      @(negedge clk);
      lfsr = next_lfsr(lfsr);
      stall = lfsr[0];
      fetch_ready = lfsr[1];
      redirect_valid = lfsr[5] && !lfsr[2];
      redirect_pc = {16'h0004, lfsr[15:2], 2'b00};
      step_active("random priority");
      random_count++;
    end

    if (pass_count < 110 || reset_count < 2 || advance_count < 3 ||
        hold_count < 1 || stall_count < 1 || redirect_count < 3 ||
        misalign_count < 1 || random_count < 100) begin
      $fatal(1, "frontend_pc coverage goal missed");
    end

    $display("tb_frontend_pc coverage: pass_count=%0d reset=%0d advance=%0d hold=%0d stall=%0d redirect=%0d misalign=%0d random=%0d",
             pass_count, reset_count, advance_count, hold_count, stall_count,
             redirect_count, misalign_count, random_count);
    $display("tb_frontend_pc PASS");
    $finish;
  end
endmodule
