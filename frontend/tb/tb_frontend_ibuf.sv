`timescale 1ns/1ps

// tb_frontend_ibuf is the self-checking verification environment for the
// frontend instruction buffer. It uses a SystemVerilog queue as the reference
// model and checks reset, full/empty, simultaneous push/pop, flush, metadata,
// and deterministic-random ready/valid behavior.
module tb_frontend_ibuf;
  localparam int DEPTH = 2;

  typedef struct packed {
    logic [31:0] pc;
    logic [31:0] instr;
    logic        fault;
    logic        misaligned;
  } instr_item_t;

  logic        clk;              // 100 MHz verification clock.
  logic        rst_n;            // Active-low reset driven by the testbench.
  logic        flush;            // Flush stimulus.
  logic        push_valid;       // Push valid stimulus.
  logic        push_ready;       // DUT push ready.
  logic [31:0] push_pc;          // Push PC stimulus.
  logic [31:0] push_instr;       // Push instruction stimulus.
  logic        push_fault;       // Push fault stimulus.
  logic        push_misaligned;  // Push misalignment stimulus.
  logic        pop_valid;        // DUT pop valid.
  logic        pop_ready;        // Pop ready stimulus.
  logic [31:0] pop_pc;           // DUT pop PC.
  logic [31:0] pop_instr;        // DUT pop instruction.
  logic        pop_fault;        // DUT pop fault.
  logic        pop_misaligned;   // DUT pop misalignment.
  logic        empty;            // DUT empty indication.
  logic        full;             // DUT full indication.

  instr_item_t model_q[$];       // Reference FIFO queue.
  integer pass_count;            // Total passing checks.
  integer push_count;            // Accepted pushes.
  integer pop_count;             // Accepted pops.
  integer full_count;            // Full behavior checks.
  integer empty_count;           // Empty behavior checks.
  integer flush_count;           // Flush behavior checks.
  integer simultaneous_count;    // Simultaneous push/pop checks.
  integer fault_count;           // Fault metadata checks.
  integer random_count;          // Deterministic-random checks.
  logic [31:0] lfsr;             // Deterministic pseudo-random stimulus.

  frontend_ibuf #(
    .DEPTH(DEPTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .push_valid_i(push_valid),
    .push_ready_o(push_ready),
    .push_pc_i(push_pc),
    .push_instr_i(push_instr),
    .push_fault_i(push_fault),
    .push_misaligned_i(push_misaligned),
    .pop_valid_o(pop_valid),
    .pop_ready_i(pop_ready),
    .pop_pc_o(pop_pc),
    .pop_instr_o(pop_instr),
    .pop_fault_o(pop_fault),
    .pop_misaligned_o(pop_misaligned),
    .empty_o(empty),
    .full_o(full)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  function automatic instr_item_t make_item(input logic [31:0] tag);
    instr_item_t item;
    begin
      item.pc = 32'h0001_0000 + {tag[29:0], 2'b00};
      item.instr = 32'h5000_0000 ^ tag;
      item.fault = tag[0];
      item.misaligned = tag[1];
      make_item = item;
    end
  endfunction

  task automatic drive_item(input instr_item_t item);
    begin
      push_pc = item.pc;
      push_instr = item.instr;
      push_fault = item.fault;
      push_misaligned = item.misaligned;
    end
  endtask

  // Compare visible ready/valid/status and, when non-empty, front item data.
  task automatic expect_model(input string name);
    begin
      #1;
      if (empty !== (model_q.size() == 0) ||
          full !== (model_q.size() == DEPTH) ||
          push_ready !== ((model_q.size() < DEPTH) && !flush) ||
          pop_valid !== ((model_q.size() > 0) && !flush)) begin
        $fatal(1, "%s status mismatch size=%0d empty=%0b full=%0b push_ready=%0b pop_valid=%0b flush=%0b",
               name, model_q.size(), empty, full, push_ready, pop_valid, flush);
      end
      if (model_q.size() > 0 && !flush) begin
        if (pop_pc !== model_q[0].pc || pop_instr !== model_q[0].instr ||
            pop_fault !== model_q[0].fault ||
            pop_misaligned !== model_q[0].misaligned) begin
          $fatal(1, "%s front mismatch pc=%08x exp=%08x instr=%08x exp=%08x fault=%0b exp=%0b mis=%0b exp=%0b",
                 name, pop_pc, model_q[0].pc, pop_instr, model_q[0].instr,
                 pop_fault, model_q[0].fault, pop_misaligned, model_q[0].misaligned);
        end
      end
      pass_count++;
    end
  endtask

  // Apply one cycle and update the reference model with the same flush/push/pop
  // priority contract as the DUT.
  task automatic step_model(input string name);
    bit push_fire;
    bit pop_fire;
    instr_item_t item;
    begin
      push_fire = push_valid && push_ready;
      pop_fire = pop_valid && pop_ready;
      item.pc = push_pc;
      item.instr = push_instr;
      item.fault = push_fault;
      item.misaligned = push_misaligned;
      @(posedge clk);
      #1;
      if (flush) begin
        model_q.delete();
      end else begin
        if (pop_fire && model_q.size() > 0) begin
          void'(model_q.pop_front());
        end
        if (push_fire && model_q.size() < DEPTH) begin
          model_q.push_back(item);
        end
      end
      expect_model(name);
    end
  endtask

  task automatic push_one(input instr_item_t item, input string name);
    begin
      @(negedge clk);
      drive_item(item);
      push_valid = 1'b1;
      pop_ready = 1'b0;
      step_model(name);
      push_valid = 1'b0;
      push_count++;
    end
  endtask

  task automatic pop_one(input instr_item_t exp_item, input string name);
    begin
      @(negedge clk);
      push_valid = 1'b0;
      pop_ready = 1'b1;
      #1;
      if (!pop_valid || pop_pc !== exp_item.pc || pop_instr !== exp_item.instr ||
          pop_fault !== exp_item.fault || pop_misaligned !== exp_item.misaligned) begin
        $fatal(1, "%s pop precheck mismatch", name);
      end
      if (exp_item.fault || exp_item.misaligned) begin
        fault_count++;
      end
      step_model(name);
      pop_ready = 1'b0;
      pop_count++;
    end
  endtask

  initial begin
    instr_item_t item0;
    instr_item_t item1;
    instr_item_t item2;
    instr_item_t rand_item;

    pass_count = 0;
    push_count = 0;
    pop_count = 0;
    full_count = 0;
    empty_count = 0;
    flush_count = 0;
    simultaneous_count = 0;
    fault_count = 0;
    random_count = 0;
    lfsr = 32'h2468_ACED;
    model_q.delete();

    flush = 1'b0;
    push_valid = 1'b0;
    push_pc = 32'h0000_0000;
    push_instr = 32'h0000_0013;
    push_fault = 1'b0;
    push_misaligned = 1'b0;
    pop_ready = 1'b0;
    rst_n = 1'b0;

    repeat (2) @(posedge clk);
    expect_model("reset");
    empty_count++;
    rst_n = 1'b1;
    @(posedge clk);
    expect_model("reset release");

    item0 = make_item(32'h0000_0000);
    item1 = make_item(32'h0000_0001);
    item2 = make_item(32'h0000_0002);

    push_one(item0, "push item0");
    push_one(item1, "push item1 full");
    if (!full || push_ready) begin
      $fatal(1, "full check mismatch full=%0b push_ready=%0b", full, push_ready);
    end
    full_count++;

    @(negedge clk);
    drive_item(item2);
    push_valid = 1'b1;
    pop_ready = 1'b0;
    step_model("push blocked when full");
    push_valid = 1'b0;

    pop_one(item0, "pop item0");

    @(negedge clk);
    drive_item(item2);
    push_valid = 1'b1;
    pop_ready = 1'b1;
    #1;
    if (!pop_valid || pop_pc !== item1.pc || pop_instr !== item1.instr ||
        pop_fault !== item1.fault || pop_misaligned !== item1.misaligned) begin
      $fatal(1, "simultaneous push/pop precheck mismatch");
    end
    step_model("simultaneous push pop");
    push_valid = 1'b0;
    pop_ready = 1'b0;
    push_count++;
    pop_count++;
    simultaneous_count++;
    fault_count++;

    pop_one(item2, "pop item2 misalign");
    if (!empty || pop_valid) begin
      $fatal(1, "empty check mismatch empty=%0b pop_valid=%0b", empty, pop_valid);
    end
    empty_count++;

    push_one(make_item(32'h0000_0010), "push before flush 0");
    push_one(make_item(32'h0000_0011), "push before flush 1");
    @(negedge clk);
    flush = 1'b1;
    push_valid = 1'b1;
    pop_ready = 1'b1;
    drive_item(make_item(32'h0000_0012));
    step_model("flush clears all");
    flush = 1'b0;
    push_valid = 1'b0;
    pop_ready = 1'b0;
    flush_count++;
    empty_count++;

    repeat (80) begin
      @(negedge clk);
      lfsr = next_lfsr(lfsr);
      flush = lfsr[7] && (model_q.size() != 0);
      push_valid = lfsr[0];
      pop_ready = lfsr[1];
      rand_item = make_item(lfsr);
      drive_item(rand_item);
      if (push_valid && push_ready && !flush) begin
        push_count++;
      end
      if (pop_ready && pop_valid && !flush) begin
        pop_count++;
      end
      if (push_valid && push_ready && pop_ready && pop_valid && !flush) begin
        simultaneous_count++;
      end
      if (flush) begin
        flush_count++;
      end
      step_model("random push pop flush");
      random_count++;
      flush = 1'b0;
    end

    if (pass_count < 90 || push_count < 8 || pop_count < 8 ||
        full_count < 1 || empty_count < 3 || flush_count < 1 ||
        simultaneous_count < 1 || fault_count < 2 || random_count < 80) begin
      $fatal(1, "frontend_ibuf coverage goal missed pass=%0d push=%0d pop=%0d full=%0d empty=%0d flush=%0d sim=%0d fault=%0d random=%0d",
             pass_count, push_count, pop_count, full_count, empty_count,
             flush_count, simultaneous_count, fault_count, random_count);
    end

    $display("tb_frontend_ibuf coverage: pass_count=%0d push=%0d pop=%0d full=%0d empty=%0d flush=%0d simultaneous=%0d fault=%0d random=%0d",
             pass_count, push_count, pop_count, full_count, empty_count,
             flush_count, simultaneous_count, fault_count, random_count);
    $display("tb_frontend_ibuf PASS");
    $finish;
  end
endmodule
