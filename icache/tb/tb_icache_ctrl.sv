`timescale 1ns/1ps

// tb_icache_ctrl verifies the I-cache frontend/refill control FSM.
// The testbench models tag/data lookup results and refill completions while
// checking frontend responses, refill starts, cache updates, flush behavior,
// and backpressure handling.
module tb_icache_ctrl;
  localparam int LINE_BYTES = 16;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);
  localparam int WORD_INDEX_BITS = (WORDS_PER_LINE <= 1) ? 1 : $clog2(WORDS_PER_LINE);
  localparam int BYTE_OFFSET_BITS = $clog2(DATA_BYTES);

  logic                    clk;                 // 100 MHz verification clock.
  logic                    rst_n;               // Active-low reset stimulus.
  logic                    flush;               // Controller flush stimulus.
  logic                    lookup_valid;        // DUT lookup qualifier.
  logic [ADDR_WIDTH-1:0]   lookup_addr;         // DUT lookup address.
  logic                    tag_hit;             // Mock tag hit result.
  logic [DATA_WIDTH-1:0]   data_word;           // Mock data-array word result.
  logic                    refill_start_valid;  // DUT refill start request.
  logic                    refill_start_ready;  // Mock refill start ready.
  logic [ADDR_WIDTH-1:0]   refill_start_addr;   // DUT refill start address.
  logic                    refill_flush;        // DUT forwarded refill flush.
  logic                    refill_line_valid;   // Mock completed refill line.
  logic                    refill_line_ready;   // DUT accepts completed line.
  logic [ADDR_WIDTH-1:0]   refill_line_addr;    // Mock completed line address.
  logic [LINE_BITS-1:0]    refill_line_data;    // Mock completed line data.
  logic                    refill_line_error;   // Mock completed line error.
  logic                    tag_refill_valid;    // DUT tag update pulse.
  logic [ADDR_WIDTH-1:0]   tag_refill_addr;     // DUT tag update address.
  logic                    tag_refill_error;    // DUT tag update error flag.
  logic                    data_refill_valid;   // DUT data update pulse.
  logic [ADDR_WIDTH-1:0]   data_refill_addr;    // DUT data update address.
  logic [LINE_BITS-1:0]    data_refill_line;    // DUT data update line.

  integer pass_count;          // Total passing checks.
  integer hit_count;           // Hit response checks.
  integer miss_count;          // Miss/refill checks.
  integer invalid_count;       // Illegal request checks.
  integer refill_start_count;  // Refill start checks.
  integer update_count;        // Tag/data update checks.
  integer error_count;         // Error response checks.
  integer flush_count;         // Flush abort checks.
  integer backpressure_count;  // Backpressure checks.
  integer random_count;        // Deterministic-random checks.
  logic [31:0] lfsr;           // Deterministic pseudo-random state.

  mem_req_rsp_if front_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  icache_ctrl #(
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .front_if(front_if),
    .lookup_valid_o(lookup_valid),
    .lookup_addr_o(lookup_addr),
    .tag_hit_i(tag_hit),
    .data_word_i(data_word),
    .refill_start_valid_o(refill_start_valid),
    .refill_start_ready_i(refill_start_ready),
    .refill_start_addr_o(refill_start_addr),
    .refill_flush_o(refill_flush),
    .refill_line_valid_i(refill_line_valid),
    .refill_line_ready_o(refill_line_ready),
    .refill_line_addr_i(refill_line_addr),
    .refill_line_data_i(refill_line_data),
    .refill_line_error_i(refill_line_error),
    .tag_refill_valid_o(tag_refill_valid),
    .tag_refill_addr_o(tag_refill_addr),
    .tag_refill_error_o(tag_refill_error),
    .data_refill_valid_o(data_refill_valid),
    .data_refill_addr_o(data_refill_addr),
    .data_refill_line_o(data_refill_line)
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
    word_for_addr = 32'h7100_0000 ^ addr;
  endfunction

  function automatic logic [LINE_BITS-1:0] line_for_base(input logic [ADDR_WIDTH-1:0] base);
    logic [LINE_BITS-1:0] line;
    begin
      for (int word = 0; word < WORDS_PER_LINE; word++) begin
        line[word * DATA_WIDTH +: DATA_WIDTH] =
          word_for_addr(base + ADDR_WIDTH'(word) * ADDR_WIDTH'(DATA_BYTES));
      end
      line_for_base = line;
    end
  endfunction

  function automatic logic [DATA_WIDTH-1:0] word_from_line(
    input logic [LINE_BITS-1:0] line,
    input logic [ADDR_WIDTH-1:0] addr
  );
    logic [WORD_INDEX_BITS-1:0] word_index;
    begin
      word_from_line = '0;
      word_index = addr[BYTE_OFFSET_BITS +: WORD_INDEX_BITS];
      for (int word = 0; word < WORDS_PER_LINE; word++) begin
        if (word_index == WORD_INDEX_BITS'(word)) begin
          word_from_line = line[word * DATA_WIDTH +: DATA_WIDTH];
        end
      end
    end
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

  task automatic reset_refill_defaults;
    begin
      refill_start_ready = 1'b0;
      refill_line_valid = 1'b0;
      refill_line_addr = '0;
      refill_line_data = '0;
      refill_line_error = 1'b0;
    end
  endtask

  task automatic issue_fetch(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic req_write,
    input logic [1:0] req_size,
    input logic req_instr,
    input logic hit,
    input logic [DATA_WIDTH-1:0] hit_word
  );
    begin
      @(negedge clk);
      front_if.req_valid = 1'b1;
      front_if.req_addr = addr;
      front_if.req_write = req_write;
      front_if.req_size = req_size;
      front_if.req_instr = req_instr;
      tag_hit = hit;
      data_word = hit_word;
      #1;
      if (!front_if.req_ready || !lookup_valid || (lookup_addr !== addr)) begin
        $fatal(1, "%s request accept mismatch ready=%0b lookup_valid=%0b lookup_addr=%08x exp=%08x",
               name, front_if.req_ready, lookup_valid, lookup_addr, addr);
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

  task automatic expect_response(
    input string name,
    input logic [DATA_WIDTH-1:0] exp_data,
    input logic exp_err,
    input int stalls
  );
    begin
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
      if (exp_err) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic accept_refill_start(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input int stalls
  );
    begin
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        refill_start_ready = 1'b0;
        #1;
        if (!refill_start_valid || (refill_start_addr !== exp_addr)) begin
          $fatal(1, "%s held refill start mismatch valid=%0b addr=%08x exp=%08x",
                 name, refill_start_valid, refill_start_addr, exp_addr);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      refill_start_ready = 1'b1;
      #1;
      if (!refill_start_valid || (refill_start_addr !== exp_addr)) begin
        $fatal(1, "%s refill start mismatch valid=%0b addr=%08x exp=%08x",
               name, refill_start_valid, refill_start_addr, exp_addr);
      end
      @(posedge clk);
      #1;
      refill_start_ready = 1'b0;
      refill_start_count++;
      pass_count++;
    end
  endtask

  task automatic deliver_refill_line(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input logic [LINE_BITS-1:0] exp_line,
    input logic exp_err
  );
    begin
      @(negedge clk);
      refill_line_valid = 1'b1;
      refill_line_addr = line_base(exp_addr);
      refill_line_data = exp_line;
      refill_line_error = exp_err;
      #1;
      if (!refill_line_ready || !tag_refill_valid || !data_refill_valid ||
          (tag_refill_addr !== line_base(exp_addr)) ||
          (data_refill_addr !== line_base(exp_addr)) ||
          (tag_refill_error !== exp_err) ||
          (data_refill_line !== exp_line)) begin
        $fatal(1, "%s refill line/update mismatch ready=%0b tag_v=%0b data_v=%0b tag_addr=%08x data_addr=%08x exp_base=%08x err=%0b exp_err=%0b",
               name, refill_line_ready, tag_refill_valid, data_refill_valid,
               tag_refill_addr, data_refill_addr, line_base(exp_addr),
               tag_refill_error, exp_err);
      end
      @(posedge clk);
      #1;
      refill_line_valid = 1'b0;
      refill_line_error = 1'b0;
      update_count++;
      pass_count++;
    end
  endtask

  task automatic run_hit(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] hit_word,
    input int rsp_stalls
  );
    begin
      issue_fetch({name, " request"}, addr, 1'b0, 2'd2, 1'b1, 1'b1, hit_word);
      expect_response({name, " response"}, hit_word, 1'b0, rsp_stalls);
      hit_count++;
    end
  endtask

  task automatic run_invalid(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic req_write,
    input logic [1:0] req_size,
    input logic req_instr
  );
    begin
      issue_fetch({name, " request"}, addr, req_write, req_size, req_instr,
                  1'b1, 32'hdead_beef);
      #1;
      if (refill_start_valid || tag_refill_valid || data_refill_valid) begin
        $fatal(1, "%s invalid request touched refill/update path", name);
      end
      expect_response({name, " response"}, '0, 1'b1, 0);
      invalid_count++;
    end
  endtask

  task automatic run_miss(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input int start_stalls,
    input int rsp_stalls,
    input logic refill_err
  );
    logic [LINE_BITS-1:0] line;
    begin
      line = line_for_base(line_base(addr));
      issue_fetch({name, " request"}, addr, 1'b0, 2'd2, 1'b1, 1'b0, '0);
      accept_refill_start({name, " start"}, addr, start_stalls);
      deliver_refill_line({name, " line"}, addr, line, refill_err);
      expect_response({name, " response"}, word_from_line(line, addr),
                      refill_err, rsp_stalls);
      miss_count++;
    end
  endtask

  task automatic run_flush_abort;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_1240;
      issue_fetch("flush miss request", addr, 1'b0, 2'd2, 1'b1, 1'b0, '0);
      accept_refill_start("flush miss start", addr, 0);
      @(negedge clk);
      flush = 1'b1;
      #1;
      if (!refill_flush) begin
        $fatal(1, "flush was not forwarded to refill");
      end
      @(posedge clk);
      #1;
      flush = 1'b0;
      if (front_if.rsp_valid || refill_start_valid || refill_line_ready ||
          tag_refill_valid || data_refill_valid) begin
        $fatal(1, "flush abort left active response or refill/update outputs");
      end
      flush_count++;
      pass_count++;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    flush = 1'b0;
    tag_hit = 1'b0;
    data_word = '0;
    pass_count = 0;
    hit_count = 0;
    miss_count = 0;
    invalid_count = 0;
    refill_start_count = 0;
    update_count = 0;
    error_count = 0;
    flush_count = 0;
    backpressure_count = 0;
    random_count = 0;
    lfsr = 32'h1ace_b00c;
    reset_front_defaults();
    reset_refill_defaults();

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    run_hit("basic hit", 32'h0000_1000, 32'h1234_5678, 0);
    run_hit("hit response backpressure", 32'h0000_1004, 32'h5566_7788, 3);
    run_invalid("write invalid", 32'h0000_1100, 1'b1, 2'd2, 1'b1);
    run_invalid("size invalid", 32'h0000_1104, 1'b0, 2'd1, 1'b1);
    run_invalid("misaligned invalid", 32'h0000_1102, 1'b0, 2'd2, 1'b1);
    run_invalid("non-instruction invalid", 32'h0000_1108, 1'b0, 2'd2, 1'b0);
    run_miss("basic miss", 32'h0000_1208, 0, 0, 1'b0);
    run_miss("miss start and response backpressure", 32'h0000_121c, 3, 2, 1'b0);
    run_miss("miss refill error", 32'h0000_1224, 1, 1, 1'b1);
    run_flush_abort();
    run_hit("post-flush hit", 32'h0000_1300, 32'hca5e_0001, 0);

    for (int i = 0; i < 24; i++) begin
      lfsr = next_lfsr(lfsr);
      unique case (lfsr[2:0])
        3'd0, 3'd1, 3'd2: begin
          run_hit("random hit", {20'h0, lfsr[11:2], 2'b00},
                  word_for_addr({20'h0, lfsr[11:2], 2'b00}), int'(lfsr[4:3]));
        end
        3'd3, 3'd4, 3'd5: begin
          run_miss("random miss", {20'h0, lfsr[11:2], 2'b00},
                   int'(lfsr[4:3]), int'(lfsr[6:5]), lfsr[7]);
        end
        default: begin
          run_invalid("random invalid", {20'h0, lfsr[11:2], 2'b10},
                      1'b0, 2'd2, 1'b1);
        end
      endcase
      random_count++;
    end

    $display("TB_ICACHE_CTRL PASS pass=%0d hits=%0d misses=%0d invalid=%0d refill_starts=%0d updates=%0d errors=%0d flushes=%0d backpressure=%0d random=%0d",
             pass_count, hit_count, miss_count, invalid_count,
             refill_start_count, update_count, error_count, flush_count,
             backpressure_count, random_count);
    $finish;
  end
endmodule
