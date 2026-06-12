`timescale 1ns/1ps

module tb_core_pipe;
  logic        clk;              // Testbench clock.
  logic        rst_n;            // Testbench active-low reset.
  logic [31:0] boot_pc;          // Reset PC driven into the DUT.
  logic        if_req_valid;     // DUT fetch request valid.
  logic [31:0] if_req_pc;        // DUT fetch request PC.
  logic        if_rsp_valid;     // Testbench fetch response valid.
  logic        if_rsp_ready;     // DUT fetch response ready.
  logic [31:0] if_rsp_instr;     // Testbench fetch response instruction.
  logic        if_rsp_fault;     // Testbench fetch response fault flag.
  logic        fetch_stall;      // Testbench fetch stall control.
  logic        decode_stall;     // Testbench decode stall control.
  logic        execute_bubble;   // Testbench execute bubble control.
  logic        redirect_valid;   // Testbench redirect control.
  logic [31:0] redirect_pc;      // Testbench redirect target.
  logic        id_valid;         // DUT IF/ID valid.
  logic [31:0] id_pc;            // DUT IF/ID PC.
  logic [31:0] id_instr;         // DUT IF/ID instruction.
  logic        id_fetch_fault;   // DUT IF/ID fetch fault.
  logic        ex_valid;         // DUT EX/WB valid.
  logic [31:0] ex_pc;            // DUT EX/WB PC.
  logic [31:0] ex_instr;         // DUT EX/WB instruction.
  logic        ex_fetch_fault;   // DUT EX/WB fetch fault.

  logic [31:0] ref_fetch_pc;     // Reference fetch PC.
  logic        ref_id_valid;     // Reference IF/ID valid.
  logic [31:0] ref_id_pc;        // Reference IF/ID PC.
  logic [31:0] ref_id_instr;     // Reference IF/ID instruction.
  logic        ref_id_fault;     // Reference IF/ID fault flag.
  logic        ref_ex_valid;     // Reference EX/WB valid.
  logic [31:0] ref_ex_pc;        // Reference EX/WB PC.
  logic [31:0] ref_ex_instr;     // Reference EX/WB instruction.
  logic        ref_ex_fault;     // Reference EX/WB fault flag.

  integer pass_count;            // Total passing cycle checks.
  integer fetch_count;           // Fetch accept coverage counter.
  integer advance_count;         // Decode advance coverage counter.
  integer stall_count;           // Stall hold coverage counter.
  integer bubble_count;          // Execute bubble coverage counter.
  integer redirect_count;        // Redirect flush coverage counter.
  integer fault_count;           // Fetch fault propagation counter.
  integer random_count;          // Deterministic random control counter.
  integer i;                     // Random loop index.

  core_pipe dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .boot_pc_i(boot_pc),
    .if_req_valid_o(if_req_valid),
    .if_req_pc_o(if_req_pc),
    .if_rsp_valid_i(if_rsp_valid),
    .if_rsp_ready_o(if_rsp_ready),
    .if_rsp_instr_i(if_rsp_instr),
    .if_rsp_fault_i(if_rsp_fault),
    .fetch_stall_i(fetch_stall),
    .decode_stall_i(decode_stall),
    .execute_bubble_i(execute_bubble),
    .redirect_valid_i(redirect_valid),
    .redirect_pc_i(redirect_pc),
    .id_valid_o(id_valid),
    .id_pc_o(id_pc),
    .id_instr_o(id_instr),
    .id_fetch_fault_o(id_fetch_fault),
    .ex_valid_o(ex_valid),
    .ex_pc_o(ex_pc),
    .ex_instr_o(ex_instr),
    .ex_fetch_fault_o(ex_fetch_fault)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // Reset the reference model to the same architectural defaults used by the
  // DUT: boot PC and invalid NOP-filled pipeline slots.
  task automatic reset_ref(input logic [31:0] pc);
    begin
      ref_fetch_pc = pc;
      ref_id_valid = 1'b0;
      ref_id_pc = 32'h0000_0000;
      ref_id_instr = 32'h0000_0013;
      ref_id_fault = 1'b0;
      ref_ex_valid = 1'b0;
      ref_ex_pc = 32'h0000_0000;
      ref_ex_instr = 32'h0000_0013;
      ref_ex_fault = 1'b0;
    end
  endtask

  // Compare every visible pipeline state output against the reference model.
  task automatic check_state(input string name);
    begin
      if ((if_req_pc !== ref_fetch_pc) ||
          (id_valid !== ref_id_valid) ||
          (id_pc !== ref_id_pc) ||
          (id_instr !== ref_id_instr) ||
          (id_fetch_fault !== ref_id_fault) ||
          (ex_valid !== ref_ex_valid) ||
          (ex_pc !== ref_ex_pc) ||
          (ex_instr !== ref_ex_instr) ||
          (ex_fetch_fault !== ref_ex_fault)) begin
        $fatal(1, "%s state mismatch", name);
      end
      pass_count++;
    end
  endtask

  // Apply one cycle of stimulus, check combinational handshake outputs, update
  // the reference model, and compare registered state after the active edge.
  task automatic step_cycle(
    input string       name,
    input logic        t_rsp_valid,
    input logic [31:0] t_instr,
    input logic        t_fault,
    input logic        t_fetch_stall,
    input logic        t_decode_stall,
    input logic        t_execute_bubble,
    input logic        t_redirect_valid,
    input logic [31:0] t_redirect_pc
  );
    logic old_id_valid;
    logic [31:0] old_id_pc;
    logic [31:0] old_id_instr;
    logic old_id_fault;
    logic [31:0] old_fetch_pc;
    logic exp_ready;
    logic fetch_fire;
    begin
      @(negedge clk);
      if_rsp_valid = t_rsp_valid;
      if_rsp_instr = t_instr;
      if_rsp_fault = t_fault;
      fetch_stall = t_fetch_stall;
      decode_stall = t_decode_stall;
      execute_bubble = t_execute_bubble;
      redirect_valid = t_redirect_valid;
      redirect_pc = t_redirect_pc;
      #1;

      exp_ready = !t_fetch_stall && !t_decode_stall && !t_redirect_valid;
      if ((if_req_valid !== !t_fetch_stall) || (if_rsp_ready !== exp_ready) ||
          (if_req_pc !== ref_fetch_pc)) begin
        $fatal(1, "%s handshake mismatch", name);
      end

      old_id_valid = ref_id_valid;
      old_id_pc = ref_id_pc;
      old_id_instr = ref_id_instr;
      old_id_fault = ref_id_fault;
      old_fetch_pc = ref_fetch_pc;
      fetch_fire = t_rsp_valid && exp_ready;

      @(posedge clk);
      #1;

      if (t_redirect_valid) begin
        ref_fetch_pc = t_redirect_pc;
        ref_id_valid = 1'b0;
        ref_id_pc = 32'h0000_0000;
        ref_id_instr = 32'h0000_0013;
        ref_id_fault = 1'b0;
        ref_ex_valid = 1'b0;
        ref_ex_pc = 32'h0000_0000;
        ref_ex_instr = 32'h0000_0013;
        ref_ex_fault = 1'b0;
        redirect_count++;
      end else begin
        if (fetch_fire) begin
          ref_fetch_pc = ref_fetch_pc + 32'd4;
          fetch_count++;
        end

        if (t_execute_bubble) begin
          ref_ex_valid = 1'b0;
          ref_ex_pc = 32'h0000_0000;
          ref_ex_instr = 32'h0000_0013;
          ref_ex_fault = 1'b0;
          bubble_count++;
        end else if (!t_decode_stall) begin
          ref_ex_valid = old_id_valid;
          ref_ex_pc = old_id_pc;
          ref_ex_instr = old_id_instr;
          ref_ex_fault = old_id_fault;
          advance_count++;
        end

        if (fetch_fire) begin
          ref_id_valid = 1'b1;
          ref_id_pc = old_fetch_pc;
          ref_id_instr = t_instr;
          ref_id_fault = t_fault;
          if (t_fault) begin
            fault_count++;
          end
        end else if (!t_decode_stall) begin
          ref_id_valid = 1'b0;
          ref_id_pc = 32'h0000_0000;
          ref_id_instr = 32'h0000_0013;
          ref_id_fault = 1'b0;
        end else begin
          stall_count++;
        end
      end

      check_state(name);
    end
  endtask

  initial begin
    pass_count = 0;
    fetch_count = 0;
    advance_count = 0;
    stall_count = 0;
    bubble_count = 0;
    redirect_count = 0;
    fault_count = 0;
    random_count = 0;

    boot_pc = 32'h0001_0000;
    rst_n = 1'b0;
    if_rsp_valid = 1'b0;
    if_rsp_instr = 32'h0000_0013;
    if_rsp_fault = 1'b0;
    fetch_stall = 1'b0;
    decode_stall = 1'b0;
    execute_bubble = 1'b0;
    redirect_valid = 1'b0;
    redirect_pc = 32'h0000_0000;
    reset_ref(boot_pc);

    repeat (2) @(posedge clk);
    #1;
    check_state("reset");
    rst_n = 1'b1;

    step_cycle("fetch A", 1'b1, 32'h0010_0093, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0);
    step_cycle("fetch B advance A", 1'b1, 32'h0020_0113, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0);
    step_cycle("stall hold", 1'b1, 32'h0030_0193, 1'b0, 1'b1, 1'b1, 1'b0, 1'b0, 32'h0);
    step_cycle("bubble hold id", 1'b1, 32'h0040_0213, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0, 32'h0);
    step_cycle("release advance", 1'b0, 32'h0000_0013, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0);
    step_cycle("fetch fault", 1'b1, 32'h0050_0293, 1'b1, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0);
    step_cycle("fault advance", 1'b0, 32'h0000_0013, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 32'h0);
    step_cycle("redirect flush", 1'b1, 32'h0060_0313, 1'b0, 1'b0, 1'b0, 1'b0, 1'b1, 32'h0002_0000);

    void'($urandom(32'hA2A0_000A));
    for (i = 0; i < 120; i++) begin
      step_cycle("random",
                 logic'($urandom_range(0, 1)),
                 $urandom(),
                 logic'($urandom_range(0, 1)),
                 logic'($urandom_range(0, 1)),
                 logic'($urandom_range(0, 1)),
                 logic'($urandom_range(0, 1)),
                 logic'($urandom_range(0, 1)),
                 {$urandom()[31:2], 2'b00});
      random_count++;
    end

    if (fetch_count < 5 || advance_count < 5 || stall_count < 2 ||
        bubble_count < 1 || redirect_count < 1 || fault_count < 1 ||
        random_count < 120) begin
      $fatal(1, "coverage goal missed");
    end

    $display("tb_core_pipe coverage: pass_count=%0d fetch=%0d advance=%0d stall=%0d bubble=%0d redirect=%0d fault=%0d random=%0d",
             pass_count, fetch_count, advance_count, stall_count,
             bubble_count, redirect_count, fault_count, random_count);
    $display("tb_core_pipe PASS");
    $finish;
  end
endmodule
