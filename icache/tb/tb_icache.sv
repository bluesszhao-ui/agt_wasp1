`timescale 1ns/1ps

// tb_icache verifies the integrated instruction cache using real tag, data,
// control, and refill leaves. The downstream memory model is cycle-steered by
// the testbench so each miss can be checked beat by beat.
module tb_icache;
  localparam int LINE_COUNT = 16;
  localparam int LINE_BYTES = 16;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);

  logic clk;          // 100 MHz verification clock.
  logic rst_n;        // Active-low reset stimulus.
  logic flush;        // Cache flush/abort stimulus.
  logic invalidate;   // Tag-valid invalidate stimulus.

  integer pass_count;        // Total passing checks.
  integer miss_count;        // Integrated miss/refill checks.
  integer hit_count;         // Integrated hit checks.
  integer conflict_count;    // Conflict replacement checks.
  integer invalidate_count;  // Invalidate checks.
  integer error_count;       // Refill/error checks.
  integer flush_count;       // Flush abort checks.
  integer backpressure_count;// Backpressure checks.
  integer req_count;         // Downstream request beat checks.
  integer rsp_count;         // Downstream response beat checks.
  integer random_count;      // Deterministic-random transaction checks.
  logic [31:0] lfsr;         // Deterministic pseudo-random state.

  mem_req_rsp_if front_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  mem_req_rsp_if mem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  icache #(
    .LINE_COUNT(LINE_COUNT),
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .invalidate_i(invalidate),
    .front_if(front_if),
    .mem_if(mem_if)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] line_base(input logic [ADDR_WIDTH-1:0] addr);
    line_base = {addr[ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
  endfunction

  function automatic logic [DATA_WIDTH-1:0] word_for_addr(input logic [ADDR_WIDTH-1:0] addr);
    word_for_addr = 32'ha500_0000 ^ addr ^ {addr[15:0], addr[31:16]};
  endfunction

  task automatic reset_front_defaults;
    begin
      front_if.req_valid = 1'b0;
      front_if.req_addr = '0;
      front_if.req_write = 1'b0;
      front_if.req_size = 2'd2;
      front_if.req_wdata = '0;
      front_if.req_wstrb = '0;
      front_if.req_instr = 1'b1;
      front_if.rsp_ready = 1'b0;
    end
  endtask

  task automatic reset_mem_defaults;
    begin
      mem_if.req_ready = 1'b0;
      mem_if.rsp_valid = 1'b0;
      mem_if.rsp_rdata = '0;
      mem_if.rsp_err = 1'b0;
    end
  endtask

  task automatic issue_front_req(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic req_write,
    input logic [1:0] req_size,
    input logic req_instr
  );
    begin
      @(negedge clk);
      front_if.req_valid = 1'b1;
      front_if.req_addr = addr;
      front_if.req_write = req_write;
      front_if.req_size = req_size;
      front_if.req_instr = req_instr;
      #1;
      if (!front_if.req_ready) begin
        $fatal(1, "%s frontend request not ready", name);
      end
      @(posedge clk);
      #1;
      front_if.req_valid = 1'b0;
      front_if.req_write = 1'b0;
      front_if.req_size = 2'd2;
      front_if.req_instr = 1'b1;
      pass_count++;
    end
  endtask

  task automatic expect_front_rsp(
    input string name,
    input logic [DATA_WIDTH-1:0] exp_data,
    input logic exp_err,
    input int stalls
  );
    int wait_cycles;
    begin
      wait_cycles = 0;
      while (!front_if.rsp_valid && (wait_cycles < 8)) begin
        @(negedge clk);
        #1;
        wait_cycles++;
      end
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        front_if.rsp_ready = 1'b0;
        #1;
        if (!front_if.rsp_valid || (front_if.rsp_rdata !== exp_data) ||
            (front_if.rsp_err !== exp_err)) begin
          $fatal(1, "%s held response mismatch valid=%0b data=%08x exp=%08x err=%0b exp=%0b",
                 name, front_if.rsp_valid, front_if.rsp_rdata, exp_data,
                 front_if.rsp_err, exp_err);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      front_if.rsp_ready = 1'b1;
      #1;
      if (!front_if.rsp_valid || (front_if.rsp_rdata !== exp_data) ||
          (front_if.rsp_err !== exp_err)) begin
        $fatal(1, "%s response mismatch valid=%0b data=%08x exp=%08x err=%0b exp=%0b",
               name, front_if.rsp_valid, front_if.rsp_rdata, exp_data,
               front_if.rsp_err, exp_err);
      end
      @(posedge clk);
      #1;
      front_if.rsp_ready = 1'b0;
      pass_count++;
    end
  endtask

  task automatic accept_mem_req(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input int stalls
  );
    int wait_cycles;
    begin
      wait_cycles = 0;
      while (!mem_if.req_valid && (wait_cycles < 8)) begin
        @(negedge clk);
        #1;
        wait_cycles++;
      end
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.req_ready = 1'b0;
        #1;
        if (!mem_if.req_valid || (mem_if.req_addr !== exp_addr)) begin
          $fatal(1, "%s held memory request mismatch valid=%0b addr=%08x exp=%08x",
                 name, mem_if.req_valid, mem_if.req_addr, exp_addr);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      mem_if.req_ready = 1'b1;
      #1;
      if (!mem_if.req_valid || (mem_if.req_addr !== exp_addr) ||
          mem_if.req_write || (mem_if.req_size !== 2'd2) ||
          (mem_if.req_wstrb !== 4'b0000) || !mem_if.req_instr) begin
        $fatal(1, "%s memory request mismatch valid=%0b addr=%08x exp=%08x write=%0b size=%0d instr=%0b",
               name, mem_if.req_valid, mem_if.req_addr, exp_addr,
               mem_if.req_write, mem_if.req_size, mem_if.req_instr);
      end
      @(posedge clk);
      #1;
      mem_if.req_ready = 1'b0;
      req_count++;
      pass_count++;
    end
  endtask

  task automatic deliver_mem_rsp(
    input string name,
    input logic [DATA_WIDTH-1:0] data,
    input logic err,
    input int stalls
  );
    begin
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.rsp_valid = 1'b0;
        #1;
        if (front_if.rsp_valid) begin
          $fatal(1, "%s frontend response appeared before memory response", name);
        end
        pass_count++;
      end
      @(negedge clk);
      mem_if.rsp_valid = 1'b1;
      mem_if.rsp_rdata = data;
      mem_if.rsp_err = err;
      #1;
      if (!mem_if.rsp_ready) begin
        $fatal(1, "%s memory response not ready", name);
      end
      @(posedge clk);
      #1;
      mem_if.rsp_valid = 1'b0;
      mem_if.rsp_err = 1'b0;
      rsp_count++;
      pass_count++;
    end
  endtask

  task automatic drive_refill(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input int req_stalls,
    input int rsp_stalls,
    input int err_beat
  );
    logic [ADDR_WIDTH-1:0] base;
    logic [ADDR_WIDTH-1:0] beat_addr;
    begin
      base = line_base(addr);
      for (int beat = 0; beat < WORDS_PER_LINE; beat++) begin
        beat_addr = base + ADDR_WIDTH'(beat) * ADDR_WIDTH'(DATA_BYTES);
        accept_mem_req({name, " req"}, beat_addr, req_stalls);
        deliver_mem_rsp({name, " rsp"}, word_for_addr(beat_addr),
                        (err_beat == beat), rsp_stalls);
      end
    end
  endtask

  task automatic fetch_miss(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input int req_stalls,
    input int rsp_stalls,
    input int front_rsp_stalls,
    input int err_beat
  );
    begin
      issue_front_req({name, " front"}, addr, 1'b0, 2'd2, 1'b1);
      drive_refill({name, " refill"}, addr, req_stalls, rsp_stalls, err_beat);
      expect_front_rsp({name, " rsp"}, word_for_addr(addr), (err_beat >= 0),
                       front_rsp_stalls);
      miss_count++;
      if (err_beat >= 0) begin
        error_count++;
      end
    end
  endtask

  task automatic fetch_hit(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input int front_rsp_stalls
  );
    begin
      issue_front_req({name, " front"}, addr, 1'b0, 2'd2, 1'b1);
      @(negedge clk);
      #1;
      if (mem_if.req_valid) begin
        $fatal(1, "%s expected cache hit but saw memory request addr=%08x",
               name, mem_if.req_addr);
      end
      expect_front_rsp({name, " rsp"}, word_for_addr(addr), 1'b0,
                       front_rsp_stalls);
      hit_count++;
    end
  endtask

  task automatic invalid_request_check(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic req_write,
    input logic [1:0] req_size,
    input logic req_instr
  );
    begin
      issue_front_req({name, " front"}, addr, req_write, req_size, req_instr);
      @(negedge clk);
      #1;
      if (mem_if.req_valid) begin
        $fatal(1, "%s invalid request issued downstream memory request", name);
      end
      expect_front_rsp({name, " rsp"}, '0, 1'b1, 0);
      error_count++;
    end
  endtask

  task automatic invalidate_check;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_2208;
      fetch_miss("invalidate fill", addr, 0, 0, 0, -1);
      fetch_hit("invalidate pre-hit", addr, 0);
      @(negedge clk);
      invalidate = 1'b1;
      @(posedge clk);
      #1;
      invalidate = 1'b0;
      fetch_miss("invalidate refetch", addr, 1, 0, 0, -1);
      invalidate_count++;
    end
  endtask

  task automatic flush_abort_check;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_2300;
      issue_front_req("flush miss front", addr, 1'b0, 2'd2, 1'b1);
      accept_mem_req("flush first req", line_base(addr), 0);
      @(negedge clk);
      flush = 1'b1;
      #1;
      if (front_if.rsp_valid) begin
        $fatal(1, "flush abort produced frontend response");
      end
      @(posedge clk);
      #1;
      flush = 1'b0;
      mem_if.rsp_valid = 1'b0;
      mem_if.rsp_err = 1'b0;
      repeat (2) @(posedge clk);
      if (front_if.rsp_valid || mem_if.req_valid) begin
        $fatal(1, "flush abort left cache active rsp=%0b mem_req=%0b",
               front_if.rsp_valid, mem_if.req_valid);
      end
      fetch_miss("post-flush miss", addr, 0, 0, 0, -1);
      flush_count++;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    flush = 1'b0;
    invalidate = 1'b0;
    pass_count = 0;
    miss_count = 0;
    hit_count = 0;
    conflict_count = 0;
    invalidate_count = 0;
    error_count = 0;
    flush_count = 0;
    backpressure_count = 0;
    req_count = 0;
    rsp_count = 0;
    random_count = 0;
    lfsr = 32'hc001_cafe;
    reset_front_defaults();
    reset_mem_defaults();

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    fetch_miss("basic miss", 32'h0000_1008, 0, 0, 0, -1);
    fetch_hit("same word hit", 32'h0000_1008, 0);
    fetch_hit("same line hit", 32'h0000_100c, 2);

    fetch_miss("backpressure miss", 32'h0000_1114, 2, 1, 3, -1);
    fetch_hit("backpressure hit", 32'h0000_1110, 1);

    fetch_miss("conflict first fill", 32'h0000_1200, 0, 0, 0, -1);
    fetch_hit("conflict first hit", 32'h0000_1200, 0);
    fetch_miss("conflict replacement", 32'h0000_1300, 1, 0, 0, -1);
    fetch_hit("conflict replacement hit", 32'h0000_1300, 0);
    fetch_miss("conflict old line miss", 32'h0000_1200, 0, 1, 0, -1);
    conflict_count++;

    invalid_request_check("invalid write", 32'h0000_2000, 1'b1, 2'd2, 1'b1);
    invalid_request_check("invalid size", 32'h0000_2004, 1'b0, 2'd1, 1'b1);
    invalid_request_check("invalid misalign", 32'h0000_2002, 1'b0, 2'd2, 1'b1);
    invalid_request_check("invalid instr flag", 32'h0000_2008, 1'b0, 2'd2, 1'b0);

    fetch_miss("refill error miss", 32'h0000_2104, 0, 0, 0, 2);
    fetch_miss("refill error refetch", 32'h0000_2104, 0, 0, 0, -1);
    fetch_hit("refill error recovery hit", 32'h0000_2104, 0);

    invalidate_check();
    flush_abort_check();

    for (int i = 0; i < 16; i++) begin
      lfsr = next_lfsr(lfsr);
      fetch_miss("random fill", {18'h0, lfsr[15:4], 2'b00}, int'(lfsr[1]),
                 int'(lfsr[2]), int'(lfsr[4:3]), -1);
      fetch_hit("random hit", {18'h0, lfsr[15:4], 2'b00}, int'(lfsr[6:5]));
      random_count++;
    end

    $display("TB_ICACHE PASS pass=%0d miss=%0d hit=%0d conflict=%0d invalidate=%0d error=%0d flush=%0d backpressure=%0d mem_req=%0d mem_rsp=%0d random=%0d",
             pass_count, miss_count, hit_count, conflict_count,
             invalidate_count, error_count, flush_count, backpressure_count,
             req_count, rsp_count, random_count);
    $finish;
  end
endmodule
