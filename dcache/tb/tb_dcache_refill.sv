`timescale 1ns/1ps

// tb_dcache_refill verifies the D-cache load-miss line refill sequencer.
// It models the downstream memory path, checks every issued data read request,
// and compares completed line data/error outputs against a reference line
// builder.
module tb_dcache_refill;
  localparam int LINE_BYTES = 16;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);

  logic                   clk;          // 100 MHz verification clock.
  logic                   rst_n;        // Active-low reset stimulus.
  logic                   flush;        // Abort stimulus.
  logic                   start_valid;  // Start request stimulus.
  logic                   start_ready;  // DUT can accept start.
  logic [ADDR_WIDTH-1:0]  start_addr;   // Miss address stimulus.
  logic                   line_valid;   // DUT completed line valid.
  logic                   line_ready;   // Cache accepts completed line.
  logic [ADDR_WIDTH-1:0]  line_addr;    // DUT line-aligned address.
  logic [LINE_BITS-1:0]   line_data;    // DUT assembled line.
  logic                   line_error;   // DUT sticky refill error.

  integer pass_count;           // Total passing checks.
  integer start_count;          // Accepted start checks.
  integer req_count;            // Downstream request checks.
  integer rsp_count;            // Downstream response checks.
  integer done_count;           // Completed line checks.
  integer error_count;          // Error aggregation checks.
  integer flush_count;          // Flush abort checks.
  integer backpressure_count;   // Request/output backpressure checks.
  integer random_count;         // Deterministic-random refill checks.
  logic [31:0] lfsr;            // Deterministic pseudo-random state.

  mem_req_rsp_if mem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  dcache_refill #(
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .start_valid_i(start_valid),
    .start_ready_o(start_ready),
    .start_addr_i(start_addr),
    .line_valid_o(line_valid),
    .line_ready_i(line_ready),
    .line_addr_o(line_addr),
    .line_data_o(line_data),
    .line_error_o(line_error),
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
    word_for_addr = 32'hd000_0000 ^ addr;
  endfunction

  function automatic logic [LINE_BITS-1:0] line_for_base(input logic [ADDR_WIDTH-1:0] base);
    logic [LINE_BITS-1:0] line;
    begin
      for (int beat = 0; beat < WORDS_PER_LINE; beat++) begin
        line[beat * DATA_WIDTH +: DATA_WIDTH] =
          word_for_addr(base + ADDR_WIDTH'(beat) * ADDR_WIDTH'(DATA_BYTES));
      end
      line_for_base = line;
    end
  endfunction

  task automatic reset_mem_defaults;
    begin
      mem_if.req_ready = 1'b0;
      mem_if.rsp_valid = 1'b0;
      mem_if.rsp_rdata = '0;
      mem_if.rsp_err = 1'b0;
    end
  endtask

  task automatic accept_start(input string name, input logic [ADDR_WIDTH-1:0] addr);
    begin
      @(negedge clk);
      start_valid = 1'b1;
      start_addr = addr;
      #1;
      if (!start_ready) begin
        $fatal(1, "%s start not ready", name);
      end
      @(posedge clk);
      #1;
      start_valid = 1'b0;
      start_count++;
      pass_count++;
    end
  endtask

  task automatic accept_request(input string name, input logic [ADDR_WIDTH-1:0] exp_addr, input int stalls);
    begin
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.req_ready = 1'b0;
        #1;
        if (!mem_if.req_valid || (mem_if.req_addr !== exp_addr)) begin
          $fatal(1, "%s stalled request mismatch valid=%0b addr=%08x exp=%08x",
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
          (mem_if.req_wstrb !== 4'b0000) || mem_if.req_instr) begin
        $fatal(1, "%s request mismatch valid=%0b addr=%08x exp=%08x write=%0b size=%0d instr=%0b",
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

  task automatic deliver_response(input string name, input logic [DATA_WIDTH-1:0] data, input logic err, input int stalls);
    begin
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.rsp_valid = 1'b0;
        #1;
        if (line_valid) begin
          $fatal(1, "%s completed before response", name);
        end
        pass_count++;
      end
      @(negedge clk);
      mem_if.rsp_valid = 1'b1;
      mem_if.rsp_rdata = data;
      mem_if.rsp_err = err;
      #1;
      if (!mem_if.rsp_ready) begin
        $fatal(1, "%s response not ready", name);
      end
      @(posedge clk);
      #1;
      mem_if.rsp_valid = 1'b0;
      mem_if.rsp_err = 1'b0;
      rsp_count++;
      pass_count++;
    end
  endtask

  task automatic expect_done(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_base,
    input logic [LINE_BITS-1:0] exp_line,
    input logic exp_error,
    input int output_stalls
  );
    begin
      for (int i = 0; i < output_stalls; i++) begin
        @(negedge clk);
        line_ready = 1'b0;
        #1;
        if (!line_valid || (line_addr !== exp_base) ||
            (line_data !== exp_line) || (line_error !== exp_error)) begin
          $fatal(1, "%s held done mismatch valid=%0b addr=%08x exp=%08x error=%0b exp=%0b",
                 name, line_valid, line_addr, exp_base, line_error, exp_error);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      line_ready = 1'b1;
      #1;
      if (!line_valid || (line_addr !== exp_base) ||
          (line_data !== exp_line) || (line_error !== exp_error)) begin
        $fatal(1, "%s done mismatch valid=%0b addr=%08x exp=%08x line=%032x exp=%032x error=%0b exp=%0b",
               name, line_valid, line_addr, exp_base, line_data, exp_line,
               line_error, exp_error);
      end
      @(posedge clk);
      #1;
      line_ready = 1'b0;
      done_count++;
      if (exp_error) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic run_refill(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input int req_stalls,
    input int rsp_stalls,
    input int output_stalls,
    input int err_beat
  );
    logic [ADDR_WIDTH-1:0] base;
    logic [ADDR_WIDTH-1:0] beat_addr;
    logic [LINE_BITS-1:0] exp_line;
    logic exp_error;
    begin
      base = line_base(addr);
      exp_line = line_for_base(base);
      exp_error = 1'b0;
      accept_start({name, " start"}, addr);
      for (int beat = 0; beat < WORDS_PER_LINE; beat++) begin
        beat_addr = base + ADDR_WIDTH'(beat) * ADDR_WIDTH'(DATA_BYTES);
        accept_request({name, " request"}, beat_addr, req_stalls);
        exp_error = exp_error || (err_beat == beat);
        deliver_response({name, " response"}, word_for_addr(beat_addr),
                         (err_beat == beat), rsp_stalls);
      end
      expect_done({name, " done"}, base, exp_line, exp_error, output_stalls);
    end
  endtask

  initial begin
    logic [ADDR_WIDTH-1:0] flush_base;
    logic [ADDR_WIDTH-1:0] rand_addr;

    pass_count = 0;
    start_count = 0;
    req_count = 0;
    rsp_count = 0;
    done_count = 0;
    error_count = 0;
    flush_count = 0;
    backpressure_count = 0;
    random_count = 0;
    lfsr = 32'hdca5_f00d;

    flush = 1'b0;
    start_valid = 1'b0;
    start_addr = 32'h0000_0000;
    line_ready = 1'b0;
    reset_mem_defaults();
    rst_n = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    run_refill("normal", 32'h0000_1044, 0, 0, 0, -1);
    run_refill("backpressure", 32'h0000_2088, 2, 1, 3, -1);
    run_refill("error beat", 32'h0000_30CC, 0, 0, 0, 2);

    accept_start("flush start", 32'h0000_4004);
    flush_base = line_base(32'h0000_4004);
    accept_request("flush request0", flush_base, 0);
    @(negedge clk);
    flush = 1'b1;
    #1;
    if (line_valid || mem_if.req_valid || mem_if.rsp_ready) begin
      $fatal(1, "flush did not suppress outputs");
    end
    @(posedge clk);
    #1;
    flush = 1'b0;
    flush_count++;
    pass_count++;

    for (int i = 0; i < 20; i++) begin
      lfsr = next_lfsr(lfsr);
      rand_addr = {lfsr[31:OFFSET_BITS], lfsr[OFFSET_BITS-1:0]};
      run_refill("random", rand_addr, int'({30'b0, lfsr[1:0]}),
                 int'({30'b0, lfsr[3:2]}), int'({30'b0, lfsr[5:4]}),
                 lfsr[6] ? int'({30'b0, lfsr[8:7]}) : -1);
      random_count++;
    end

    if (pass_count < 200 || start_count < 20 || req_count < 80 ||
        rsp_count < 80 || done_count < 20 || error_count < 2 ||
        flush_count < 1 || backpressure_count < 20 || random_count < 20) begin
      $fatal(1, "dcache_refill coverage goal missed pass=%0d start=%0d req=%0d rsp=%0d done=%0d err=%0d flush=%0d bp=%0d random=%0d",
             pass_count, start_count, req_count, rsp_count, done_count,
             error_count, flush_count, backpressure_count, random_count);
    end

    $display("tb_dcache_refill coverage: pass_count=%0d start=%0d req=%0d rsp=%0d done=%0d err=%0d flush=%0d backpressure=%0d random=%0d",
             pass_count, start_count, req_count, rsp_count, done_count,
             error_count, flush_count, backpressure_count, random_count);
    $display("tb_dcache_refill PASS");
    $finish;
  end
endmodule
