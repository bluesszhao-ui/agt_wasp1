`timescale 1ns/1ps

// tb_dcache_ctrl verifies the D-cache hit/miss/store control FSM.
// The testbench models tag/data lookup results plus refill and store
// sequencers, then checks core responses and cache update pulses.
module tb_dcache_ctrl;
  localparam int LINE_BYTES = 16;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
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
  logic                    req_cacheable;       // Mock cacheability result for current request.
  logic                    refill_start_valid;  // DUT refill start request.
  logic                    refill_start_ready;  // Mock refill start ready.
  logic [ADDR_WIDTH-1:0]   refill_start_addr;   // DUT refill start address.
  logic                    refill_flush;        // DUT forwarded refill flush.
  logic                    refill_line_valid;   // Mock completed refill line.
  logic                    refill_line_ready;   // DUT accepts completed refill line.
  logic [ADDR_WIDTH-1:0]   refill_line_addr;    // Mock completed refill line address.
  logic [LINE_BITS-1:0]    refill_line_data;    // Mock completed refill line data.
  logic                    refill_line_error;   // Mock completed refill line error.
  logic                    store_start_valid;   // DUT store start request.
  logic                    store_start_ready;   // Mock store start ready.
  logic [ADDR_WIDTH-1:0]   store_start_addr;    // DUT store start address.
  logic [1:0]              store_start_size;    // DUT store start size.
  logic [DATA_WIDTH-1:0]   store_start_wdata;   // DUT store start data.
  logic [STRB_WIDTH-1:0]   store_start_wstrb;   // DUT store start strobes.
  logic                    store_flush;         // DUT forwarded store flush.
  logic                    store_done_valid;    // Mock store completion valid.
  logic                    store_done_ready;    // DUT accepts store completion.
  logic [ADDR_WIDTH-1:0]   store_done_addr;     // Mock store completion address.
  logic [1:0]              store_done_size;     // Mock store completion size.
  logic [DATA_WIDTH-1:0]   store_done_wdata;    // Mock store completion data.
  logic [STRB_WIDTH-1:0]   store_done_wstrb;    // Mock store completion strobes.
  logic                    store_done_error;    // Mock store completion error.
  logic                    uncached_start_valid;// DUT uncached transaction start request.
  logic                    uncached_start_ready;// Mock uncached sequencer start ready.
  logic [ADDR_WIDTH-1:0]   uncached_start_addr; // DUT uncached byte address.
  logic                    uncached_start_write;// DUT uncached write indicator.
  logic [1:0]              uncached_start_size; // DUT uncached access size.
  logic [DATA_WIDTH-1:0]   uncached_start_wdata;// DUT uncached write data.
  logic [STRB_WIDTH-1:0]   uncached_start_wstrb;// DUT uncached write strobes.
  logic                    uncached_flush;      // DUT forwarded uncached flush.
  logic                    uncached_done_valid; // Mock uncached completion valid.
  logic                    uncached_done_ready; // DUT accepts uncached completion.
  logic [DATA_WIDTH-1:0]   uncached_done_rdata; // Mock uncached read data.
  logic                    uncached_done_error; // Mock uncached response error.
  logic                    tag_refill_valid;    // DUT tag refill update pulse.
  logic [ADDR_WIDTH-1:0]   tag_refill_addr;     // DUT tag refill update address.
  logic                    tag_refill_error;    // DUT tag refill error flag.
  logic                    data_refill_valid;   // DUT data refill update pulse.
  logic [ADDR_WIDTH-1:0]   data_refill_addr;    // DUT data refill update address.
  logic [LINE_BITS-1:0]    data_refill_line;    // DUT data refill update line.
  logic                    data_store_valid;    // DUT store-hit data update pulse.
  logic [ADDR_WIDTH-1:0]   data_store_addr;     // DUT store-hit update address.
  logic [DATA_WIDTH-1:0]   data_store_wdata;    // DUT store-hit update data.
  logic [STRB_WIDTH-1:0]   data_store_wstrb;    // DUT store-hit update strobes.

  integer pass_count;          // Total passing checks.
  integer load_hit_count;      // Load-hit response checks.
  integer load_miss_count;     // Load-miss/refill checks.
  integer store_hit_count;     // Store-hit write-through checks.
  integer store_miss_count;    // Store-miss no-allocate checks.
  integer invalid_count;       // Illegal request checks.
  integer refill_start_count;  // Refill start checks.
  integer refill_update_count; // Tag/data refill update checks.
  integer store_start_count;   // Store start checks.
  integer store_update_count;  // Store-hit data update checks.
  integer error_count;         // Error response checks.
  integer flush_count;         // Flush abort checks.
  integer backpressure_count;  // Backpressure checks.
  integer random_count;        // Deterministic-random transaction checks.
  logic [31:0] lfsr;           // Deterministic pseudo-random state.

  mem_req_rsp_if core_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  dcache_ctrl #(
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .core_if(core_if),
    .req_cacheable_i(req_cacheable),
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
    .store_start_valid_o(store_start_valid),
    .store_start_ready_i(store_start_ready),
    .store_start_addr_o(store_start_addr),
    .store_start_size_o(store_start_size),
    .store_start_wdata_o(store_start_wdata),
    .store_start_wstrb_o(store_start_wstrb),
    .store_flush_o(store_flush),
    .store_done_valid_i(store_done_valid),
    .store_done_ready_o(store_done_ready),
    .store_done_addr_i(store_done_addr),
    .store_done_size_i(store_done_size),
    .store_done_wdata_i(store_done_wdata),
    .store_done_wstrb_i(store_done_wstrb),
    .store_done_error_i(store_done_error),
    .uncached_start_valid_o(uncached_start_valid),
    .uncached_start_ready_i(uncached_start_ready),
    .uncached_start_addr_o(uncached_start_addr),
    .uncached_start_write_o(uncached_start_write),
    .uncached_start_size_o(uncached_start_size),
    .uncached_start_wdata_o(uncached_start_wdata),
    .uncached_start_wstrb_o(uncached_start_wstrb),
    .uncached_flush_o(uncached_flush),
    .uncached_done_valid_i(uncached_done_valid),
    .uncached_done_ready_o(uncached_done_ready),
    .uncached_done_rdata_i(uncached_done_rdata),
    .uncached_done_error_i(uncached_done_error),
    .tag_refill_valid_o(tag_refill_valid),
    .tag_refill_addr_o(tag_refill_addr),
    .tag_refill_error_o(tag_refill_error),
    .data_refill_valid_o(data_refill_valid),
    .data_refill_addr_o(data_refill_addr),
    .data_refill_line_o(data_refill_line),
    .data_store_valid_o(data_store_valid),
    .data_store_addr_o(data_store_addr),
    .data_store_wdata_o(data_store_wdata),
    .data_store_wstrb_o(data_store_wstrb)
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
    word_for_addr = 32'hd100_0000 ^ addr;
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

  function automatic logic [STRB_WIDTH-1:0] strb_for_size(
    input logic [1:0] size,
    input logic [1:0] addr_low
  );
    logic [STRB_WIDTH-1:0] mask;
    begin
      unique case (size)
        2'd0:    mask = STRB_WIDTH'(4'b0001 << addr_low);
        2'd1:    mask = addr_low[1] ? STRB_WIDTH'(4'b1100) : STRB_WIDTH'(4'b0011);
        default: mask = STRB_WIDTH'(4'b1111);
      endcase
      strb_for_size = mask;
    end
  endfunction

  task automatic reset_core_defaults;
    begin
      core_if.req_valid = 1'b0;
      core_if.req_addr = '0;
      core_if.req_write = 1'b0;
      core_if.req_size = 2'd2;
      core_if.req_wdata = '0;
      core_if.req_wstrb = '0;
      core_if.req_instr = 1'b0;
      core_if.rsp_ready = 1'b0;
    end
  endtask

  task automatic reset_leaf_defaults;
    begin
      tag_hit = 1'b0;
      data_word = '0;
      req_cacheable = 1'b1;
      refill_start_ready = 1'b0;
      refill_line_valid = 1'b0;
      refill_line_addr = '0;
      refill_line_data = '0;
      refill_line_error = 1'b0;
      store_start_ready = 1'b0;
      store_done_valid = 1'b0;
      store_done_addr = '0;
      store_done_size = '0;
      store_done_wdata = '0;
      store_done_wstrb = '0;
      store_done_error = 1'b0;
      uncached_start_ready = 1'b0;
      uncached_done_valid = 1'b0;
      uncached_done_rdata = '0;
      uncached_done_error = 1'b0;
    end
  endtask

  task automatic issue_core_req(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [1:0] size,
    input logic instr,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb,
    input logic hit,
    input logic [DATA_WIDTH-1:0] hit_word
  );
    begin
      @(negedge clk);
      core_if.req_valid = 1'b1;
      core_if.req_addr = addr;
      core_if.req_write = write;
      core_if.req_size = size;
      core_if.req_instr = instr;
      core_if.req_wdata = wdata;
      core_if.req_wstrb = wstrb;
      tag_hit = hit;
      data_word = hit_word;
      #1;
      if (!core_if.req_ready || !lookup_valid || (lookup_addr !== addr)) begin
        $fatal(1, "%s request accept mismatch ready=%0b lookup_valid=%0b lookup_addr=%08x exp=%08x",
               name, core_if.req_ready, lookup_valid, lookup_addr, addr);
      end
      @(posedge clk);
      #1;
      core_if.req_valid = 1'b0;
      core_if.req_write = 1'b0;
      core_if.req_size = 2'd2;
      core_if.req_instr = 1'b0;
      core_if.req_wdata = '0;
      core_if.req_wstrb = '0;
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
        core_if.rsp_ready = 1'b0;
        #1;
        if (!core_if.rsp_valid || (core_if.rsp_rdata !== exp_data) ||
            (core_if.rsp_err !== exp_err)) begin
          $fatal(1, "%s held response mismatch valid=%0b data=%08x exp=%08x err=%0b exp=%0b",
                 name, core_if.rsp_valid, core_if.rsp_rdata, exp_data,
                 core_if.rsp_err, exp_err);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      core_if.rsp_ready = 1'b1;
      #1;
      if (!core_if.rsp_valid || (core_if.rsp_rdata !== exp_data) ||
          (core_if.rsp_err !== exp_err)) begin
        $fatal(1, "%s response mismatch valid=%0b data=%08x exp=%08x err=%0b exp=%0b",
               name, core_if.rsp_valid, core_if.rsp_rdata, exp_data,
               core_if.rsp_err, exp_err);
      end
      @(posedge clk);
      #1;
      core_if.rsp_ready = 1'b0;
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
        $fatal(1, "%s refill/update mismatch ready=%0b tag_v=%0b data_v=%0b base=%08x exp=%08x err=%0b exp=%0b",
               name, refill_line_ready, tag_refill_valid, data_refill_valid,
               tag_refill_addr, line_base(exp_addr), tag_refill_error, exp_err);
      end
      @(posedge clk);
      #1;
      refill_line_valid = 1'b0;
      refill_line_error = 1'b0;
      refill_update_count++;
      pass_count++;
    end
  endtask

  task automatic accept_store_start(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input logic [1:0] exp_size,
    input logic [DATA_WIDTH-1:0] exp_wdata,
    input logic [STRB_WIDTH-1:0] exp_wstrb,
    input int stalls
  );
    begin
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        store_start_ready = 1'b0;
        #1;
        if (!store_start_valid || (store_start_addr !== exp_addr) ||
            (store_start_size !== exp_size) || (store_start_wdata !== exp_wdata) ||
            (store_start_wstrb !== exp_wstrb)) begin
          $fatal(1, "%s held store start mismatch valid=%0b addr=%08x exp=%08x size=%0d exp=%0d data=%08x exp=%08x strb=%04b exp=%04b",
                 name, store_start_valid, store_start_addr, exp_addr,
                 store_start_size, exp_size, store_start_wdata, exp_wdata,
                 store_start_wstrb, exp_wstrb);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      store_start_ready = 1'b1;
      #1;
      if (!store_start_valid || (store_start_addr !== exp_addr) ||
          (store_start_size !== exp_size) || (store_start_wdata !== exp_wdata) ||
          (store_start_wstrb !== exp_wstrb)) begin
        $fatal(1, "%s store start mismatch valid=%0b addr=%08x exp=%08x size=%0d exp=%0d data=%08x exp=%08x strb=%04b exp=%04b",
               name, store_start_valid, store_start_addr, exp_addr,
               store_start_size, exp_size, store_start_wdata, exp_wdata,
               store_start_wstrb, exp_wstrb);
      end
      @(posedge clk);
      #1;
      store_start_ready = 1'b0;
      store_start_count++;
      pass_count++;
    end
  endtask

  task automatic deliver_store_done(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input logic [1:0] exp_size,
    input logic [DATA_WIDTH-1:0] exp_wdata,
    input logic [STRB_WIDTH-1:0] exp_wstrb,
    input logic exp_hit,
    input logic exp_err
  );
    logic exp_update;
    begin
      exp_update = exp_hit && !exp_err;
      @(negedge clk);
      store_done_valid = 1'b1;
      store_done_addr = exp_addr;
      store_done_size = exp_size;
      store_done_wdata = exp_wdata;
      store_done_wstrb = exp_wstrb;
      store_done_error = exp_err;
      #1;
      if (!store_done_ready) begin
        $fatal(1, "%s store done not ready", name);
      end
      if ((data_store_valid !== exp_update) ||
          (exp_update && ((data_store_addr !== exp_addr) ||
                          (data_store_wdata !== exp_wdata) ||
                          (data_store_wstrb !== exp_wstrb)))) begin
        $fatal(1, "%s store update mismatch update=%0b exp=%0b addr=%08x exp=%08x data=%08x exp=%08x strb=%04b exp=%04b",
               name, data_store_valid, exp_update, data_store_addr, exp_addr,
               data_store_wdata, exp_wdata, data_store_wstrb, exp_wstrb);
      end
      @(posedge clk);
      #1;
      store_done_valid = 1'b0;
      store_done_error = 1'b0;
      if (exp_update) begin
        store_update_count++;
      end
      pass_count++;
    end
  endtask

  task automatic run_load_hit(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [1:0] size,
    input logic [DATA_WIDTH-1:0] hit_word,
    input int rsp_stalls
  );
    begin
      issue_core_req({name, " request"}, addr, 1'b0, size, 1'b0, '0, '0, 1'b1, hit_word);
      expect_response({name, " response"}, hit_word, 1'b0, rsp_stalls);
      load_hit_count++;
    end
  endtask

  task automatic run_load_miss(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input int start_stalls,
    input int rsp_stalls,
    input logic refill_err
  );
    logic [LINE_BITS-1:0] line;
    begin
      line = line_for_base(line_base(addr));
      issue_core_req({name, " request"}, addr, 1'b0, 2'd2, 1'b0, '0, '0, 1'b0, '0);
      accept_refill_start({name, " start"}, addr, start_stalls);
      deliver_refill_line({name, " line"}, addr, line, refill_err);
      expect_response({name, " response"}, word_from_line(line, addr), refill_err, rsp_stalls);
      load_miss_count++;
    end
  endtask

  task automatic run_store(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [1:0] size,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb,
    input logic hit,
    input int start_stalls,
    input int rsp_stalls,
    input logic store_err
  );
    begin
      issue_core_req({name, " request"}, addr, 1'b1, size, 1'b0, wdata, wstrb, hit, '0);
      accept_store_start({name, " start"}, addr, size, wdata, wstrb, start_stalls);
      deliver_store_done({name, " done"}, addr, size, wdata, wstrb, hit, store_err);
      expect_response({name, " response"}, '0, store_err, rsp_stalls);
      if (hit) begin
        store_hit_count++;
      end else begin
        store_miss_count++;
      end
    end
  endtask

  task automatic run_invalid(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [1:0] size,
    input logic instr
  );
    begin
      issue_core_req({name, " request"}, addr, write, size, instr,
                     32'hfeed_cafe, 4'b1111, 1'b1, 32'h1234_5678);
      #1;
      if (refill_start_valid || store_start_valid ||
          tag_refill_valid || data_refill_valid || data_store_valid) begin
        $fatal(1, "%s invalid request touched refill/store/update path", name);
      end
      expect_response({name, " response"}, '0, 1'b1, 0);
      invalid_count++;
    end
  endtask

  task automatic run_flush_load_abort;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_5000;
      issue_core_req("flush load request", addr, 1'b0, 2'd2, 1'b0, '0, '0, 1'b0, '0);
      accept_refill_start("flush load start", addr, 0);
      @(negedge clk);
      flush = 1'b1;
      #1;
      if (!refill_flush || core_if.rsp_valid || refill_start_valid ||
          refill_line_ready || tag_refill_valid || data_refill_valid) begin
        $fatal(1, "load flush did not abort cleanly");
      end
      @(posedge clk);
      #1;
      flush = 1'b0;
      flush_count++;
      pass_count++;
    end
  endtask

  task automatic run_flush_store_abort;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_6000;
      issue_core_req("flush store request", addr, 1'b1, 2'd2, 1'b0,
                     32'h600d_f00d, 4'b1111, 1'b1, '0);
      accept_store_start("flush store start", addr, 2'd2, 32'h600d_f00d, 4'b1111, 0);
      @(negedge clk);
      flush = 1'b1;
      #1;
      if (!store_flush || core_if.rsp_valid || store_start_valid ||
          store_done_ready || data_store_valid) begin
        $fatal(1, "store flush did not abort cleanly");
      end
      @(posedge clk);
      #1;
      flush = 1'b0;
      flush_count++;
      pass_count++;
    end
  endtask

  initial begin
    logic [ADDR_WIDTH-1:0] rand_addr;
    logic [1:0] rand_size;
    logic [DATA_WIDTH-1:0] rand_data;
    logic [STRB_WIDTH-1:0] rand_strb;

    rst_n = 1'b0;
    flush = 1'b0;
    pass_count = 0;
    load_hit_count = 0;
    load_miss_count = 0;
    store_hit_count = 0;
    store_miss_count = 0;
    invalid_count = 0;
    refill_start_count = 0;
    refill_update_count = 0;
    store_start_count = 0;
    store_update_count = 0;
    error_count = 0;
    flush_count = 0;
    backpressure_count = 0;
    random_count = 0;
    lfsr = 32'hdcac_7001;
    reset_core_defaults();
    reset_leaf_defaults();

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    run_load_hit("load word hit", 32'h0000_1000, 2'd2, 32'h1111_0000, 0);
    run_load_hit("load byte hit bp", 32'h0000_1001, 2'd0, 32'h2222_1111, 3);
    run_load_hit("load half hit", 32'h0000_1002, 2'd1, 32'h3333_2222, 1);
    run_load_miss("load miss", 32'h0000_2008, 0, 0, 1'b0);
    run_load_miss("load miss bp", 32'h0000_201c, 3, 2, 1'b0);
    run_load_miss("load miss error", 32'h0000_2024, 1, 1, 1'b1);
    run_store("store hit", 32'h0000_3000, 2'd2, 32'haaaa_5555, 4'b1111, 1'b1, 0, 0, 1'b0);
    run_store("store hit bp", 32'h0000_3002, 2'd1, 32'hbbbb_6666, 4'b1100, 1'b1, 2, 2, 1'b0);
    run_store("store miss", 32'h0000_4001, 2'd0, 32'h0000_7700, 4'b0010, 1'b0, 1, 0, 1'b0);
    run_store("store hit error", 32'h0000_4004, 2'd2, 32'hcccc_7777, 4'b1111, 1'b1, 0, 1, 1'b1);
    run_invalid("instr invalid", 32'h0000_4100, 1'b0, 2'd2, 1'b1);
    run_invalid("size invalid", 32'h0000_4100, 1'b0, 2'd3, 1'b0);
    run_invalid("half align invalid", 32'h0000_4101, 1'b0, 2'd1, 1'b0);
    run_invalid("word align invalid", 32'h0000_4102, 1'b1, 2'd2, 1'b0);
    run_flush_load_abort();
    run_flush_store_abort();
    run_load_hit("post-flush hit", 32'h0000_7000, 2'd2, 32'hca5e_0002, 0);

    for (int i = 0; i < 32; i++) begin
      lfsr = next_lfsr(lfsr);
      rand_size = lfsr[1:0];
      if (rand_size == 2'd3) begin
        rand_size = 2'd2;
      end
      rand_addr = {20'h0, lfsr[11:2], 2'b00};
      rand_data = lfsr ^ 32'h5a5a_0f0f;
      rand_strb = strb_for_size(rand_size, rand_addr[1:0]);
      unique case (lfsr[3:0])
        4'd0, 4'd1, 4'd2, 4'd3: begin
          run_load_hit("random load hit", rand_addr, rand_size,
                       word_for_addr(rand_addr), int'({30'b0, lfsr[5:4]}));
        end
        4'd4, 4'd5, 4'd6, 4'd7: begin
          run_load_miss("random load miss", rand_addr,
                        int'({30'b0, lfsr[5:4]}), int'({30'b0, lfsr[7:6]}),
                        lfsr[8]);
        end
        4'd8, 4'd9, 4'd10: begin
          run_store("random store hit", rand_addr, rand_size, rand_data, rand_strb,
                    1'b1, int'({30'b0, lfsr[5:4]}), int'({30'b0, lfsr[7:6]}),
                    lfsr[8]);
        end
        4'd11, 4'd12, 4'd13: begin
          run_store("random store miss", rand_addr, rand_size, rand_data, rand_strb,
                    1'b0, int'({30'b0, lfsr[5:4]}), int'({30'b0, lfsr[7:6]}),
                    lfsr[8]);
        end
        default: begin
          run_invalid("random invalid", rand_addr | 32'h0000_0002, 1'b0, 2'd2, 1'b0);
        end
      endcase
      random_count++;
    end

    if (pass_count < 200 || load_hit_count < 8 || load_miss_count < 8 ||
        store_hit_count < 5 || store_miss_count < 5 || invalid_count < 5 ||
        refill_start_count < 8 || refill_update_count < 8 ||
        store_start_count < 10 || store_update_count < 3 ||
        error_count < 6 || flush_count < 2 || backpressure_count < 40 ||
        random_count < 32) begin
      $fatal(1, "dcache_ctrl coverage goal missed pass=%0d lh=%0d lm=%0d sh=%0d sm=%0d inv=%0d rs=%0d ru=%0d ss=%0d su=%0d err=%0d flush=%0d bp=%0d random=%0d",
             pass_count, load_hit_count, load_miss_count, store_hit_count,
             store_miss_count, invalid_count, refill_start_count,
             refill_update_count, store_start_count, store_update_count,
             error_count, flush_count, backpressure_count, random_count);
    end

    $display("tb_dcache_ctrl coverage: pass_count=%0d load_hit=%0d load_miss=%0d store_hit=%0d store_miss=%0d invalid=%0d refill_start=%0d refill_update=%0d store_start=%0d store_update=%0d err=%0d flush=%0d backpressure=%0d random=%0d",
             pass_count, load_hit_count, load_miss_count, store_hit_count,
             store_miss_count, invalid_count, refill_start_count,
             refill_update_count, store_start_count, store_update_count,
             error_count, flush_count, backpressure_count, random_count);
    $display("tb_dcache_ctrl PASS");
    $finish;
  end
endmodule
