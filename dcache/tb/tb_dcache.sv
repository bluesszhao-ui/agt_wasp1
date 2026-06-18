`timescale 1ns/1ps

// tb_dcache verifies the integrated data cache using real tag, data, control,
// refill, and store leaves. The downstream memory model is cycle-steered by
// the testbench so refill beats and write-through stores can be checked.
module tb_dcache;
  localparam int LINE_COUNT = 16;
  localparam int LINE_BYTES = 16;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);
  localparam int MEM_OVERRIDES = 64;

  logic clk;          // 100 MHz verification clock.
  logic rst_n;        // Active-low reset stimulus.
  logic flush;        // Cache flush/abort stimulus.
  logic invalidate;   // Tag-valid invalidate stimulus.

  logic [ADDR_WIDTH-1:0] override_addr [MEM_OVERRIDES]; // Word-aligned memory override addresses.
  logic [DATA_WIDTH-1:0] override_data [MEM_OVERRIDES]; // Data after accepted write-through stores.
  logic [MEM_OVERRIDES-1:0] override_valid;             // Valid bits for override entries.
  integer override_wr_ptr;                              // Round-robin override write pointer.

  integer pass_count;         // Total passing checks.
  integer load_miss_count;    // Integrated load miss/refill checks.
  integer load_hit_count;     // Integrated load hit checks.
  integer store_hit_count;    // Integrated store-hit checks.
  integer store_miss_count;   // Integrated store-miss checks.
  integer store_update_count; // Store-hit cache-update checks.
  integer conflict_count;     // Conflict replacement checks.
  integer invalidate_count;   // Invalidate checks.
  integer error_count;        // Error checks.
  integer flush_count;        // Flush abort checks.
  integer backpressure_count; // Backpressure checks.
  integer mem_req_count;      // Downstream request checks.
  integer mem_rsp_count;      // Downstream response checks.
  integer random_count;       // Deterministic-random transaction checks.
  logic [31:0] lfsr;          // Deterministic pseudo-random state.

  mem_req_rsp_if core_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  mem_req_rsp_if mem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  dcache #(
    .LINE_COUNT(LINE_COUNT),
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .invalidate_i(invalidate),
    .core_if(core_if),
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

  function automatic logic [ADDR_WIDTH-1:0] word_base(input logic [ADDR_WIDTH-1:0] addr);
    word_base = {addr[ADDR_WIDTH-1:2], 2'b00};
  endfunction

  function automatic logic [DATA_WIDTH-1:0] default_word_for_addr(input logic [ADDR_WIDTH-1:0] addr);
    default_word_for_addr = 32'hd500_0000 ^ word_base(addr) ^ {word_base(addr)[15:0], word_base(addr)[31:16]};
  endfunction

  function automatic logic [DATA_WIDTH-1:0] mem_word_ref(input logic [ADDR_WIDTH-1:0] addr);
    logic [DATA_WIDTH-1:0] data;
    begin
      data = default_word_for_addr(addr);
      for (int i = 0; i < MEM_OVERRIDES; i++) begin
        if (override_valid[i] && (override_addr[i] == word_base(addr))) begin
          data = override_data[i];
        end
      end
      mem_word_ref = data;
    end
  endfunction

  function automatic logic [DATA_WIDTH-1:0] merge_store(
    input logic [DATA_WIDTH-1:0] old_word,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb
  );
    logic [DATA_WIDTH-1:0] merged;
    begin
      merged = old_word;
      for (int lane = 0; lane < STRB_WIDTH; lane++) begin
        if (wstrb[lane]) begin
          merged[lane * 8 +: 8] = wdata[lane * 8 +: 8];
        end
      end
      merge_store = merged;
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

  task automatic record_store(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb
  );
    logic [DATA_WIDTH-1:0] merged;
    int found;
    begin
      merged = merge_store(mem_word_ref(addr), wdata, wstrb);
      found = -1;
      for (int i = 0; i < MEM_OVERRIDES; i++) begin
        if (override_valid[i] && (override_addr[i] == word_base(addr))) begin
          found = i;
        end
      end
      if (found >= 0) begin
        override_data[found] = merged;
      end else begin
        override_addr[override_wr_ptr] = word_base(addr);
        override_data[override_wr_ptr] = merged;
        override_valid[override_wr_ptr] = 1'b1;
        override_wr_ptr = (override_wr_ptr + 1) % MEM_OVERRIDES;
      end
    end
  endtask

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

  task automatic reset_mem_defaults;
    begin
      mem_if.req_ready = 1'b0;
      mem_if.rsp_valid = 1'b0;
      mem_if.rsp_rdata = '0;
      mem_if.rsp_err = 1'b0;
    end
  endtask

  task automatic issue_core_req(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic write,
    input logic [1:0] size,
    input logic instr,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb
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
      #1;
      if (!core_if.req_ready) begin
        $fatal(1, "%s core request not ready", name);
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

  task automatic expect_core_rsp(
    input string name,
    input logic [DATA_WIDTH-1:0] exp_data,
    input logic exp_err,
    input int stalls
  );
    int wait_cycles;
    begin
      wait_cycles = 0;
      while (!core_if.rsp_valid && (wait_cycles < 12)) begin
        @(negedge clk);
        #1;
        wait_cycles++;
      end
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
      pass_count++;
    end
  endtask

  task automatic accept_mem_read_req(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input int stalls
  );
    int wait_cycles;
    begin
      wait_cycles = 0;
      while (!mem_if.req_valid && (wait_cycles < 12)) begin
        @(negedge clk);
        #1;
        wait_cycles++;
      end
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.req_ready = 1'b0;
        #1;
        if (!mem_if.req_valid || (mem_if.req_addr !== exp_addr) || mem_if.req_write) begin
          $fatal(1, "%s held read request mismatch valid=%0b addr=%08x exp=%08x write=%0b",
                 name, mem_if.req_valid, mem_if.req_addr, exp_addr, mem_if.req_write);
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
        $fatal(1, "%s read request mismatch valid=%0b addr=%08x exp=%08x write=%0b size=%0d instr=%0b",
               name, mem_if.req_valid, mem_if.req_addr, exp_addr,
               mem_if.req_write, mem_if.req_size, mem_if.req_instr);
      end
      @(posedge clk);
      #1;
      mem_if.req_ready = 1'b0;
      mem_req_count++;
      pass_count++;
    end
  endtask

  task automatic accept_mem_write_req(
    input string name,
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input logic [1:0] exp_size,
    input logic [DATA_WIDTH-1:0] exp_wdata,
    input logic [STRB_WIDTH-1:0] exp_wstrb,
    input int stalls
  );
    int wait_cycles;
    begin
      wait_cycles = 0;
      while (!mem_if.req_valid && (wait_cycles < 12)) begin
        @(negedge clk);
        #1;
        wait_cycles++;
      end
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.req_ready = 1'b0;
        #1;
        if (!mem_if.req_valid || (mem_if.req_addr !== exp_addr) ||
            !mem_if.req_write || (mem_if.req_size !== exp_size) ||
            (mem_if.req_wdata !== exp_wdata) || (mem_if.req_wstrb !== exp_wstrb) ||
            mem_if.req_instr) begin
          $fatal(1, "%s held write request mismatch", name);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      mem_if.req_ready = 1'b1;
      #1;
      if (!mem_if.req_valid || (mem_if.req_addr !== exp_addr) ||
          !mem_if.req_write || (mem_if.req_size !== exp_size) ||
          (mem_if.req_wdata !== exp_wdata) || (mem_if.req_wstrb !== exp_wstrb) ||
          mem_if.req_instr) begin
        $fatal(1, "%s write request mismatch valid=%0b addr=%08x exp=%08x size=%0d exp=%0d data=%08x exp=%08x strb=%04b exp=%04b write=%0b instr=%0b",
               name, mem_if.req_valid, mem_if.req_addr, exp_addr,
               mem_if.req_size, exp_size, mem_if.req_wdata, exp_wdata,
               mem_if.req_wstrb, exp_wstrb, mem_if.req_write, mem_if.req_instr);
      end
      @(posedge clk);
      #1;
      mem_if.req_ready = 1'b0;
      mem_req_count++;
      pass_count++;
    end
  endtask

  task automatic deliver_mem_rsp(input string name, input logic [DATA_WIDTH-1:0] data, input logic err, input int stalls);
    begin
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.rsp_valid = 1'b0;
        #1;
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
      mem_rsp_count++;
      pass_count++;
    end
  endtask

  task automatic drive_refill(input string name, input logic [ADDR_WIDTH-1:0] addr, input int req_stalls, input int rsp_stalls, input int err_beat);
    logic [ADDR_WIDTH-1:0] beat_addr;
    begin
      for (int beat = 0; beat < WORDS_PER_LINE; beat++) begin
        beat_addr = line_base(addr) + ADDR_WIDTH'(beat) * ADDR_WIDTH'(DATA_BYTES);
        accept_mem_read_req({name, " read"}, beat_addr, req_stalls);
        deliver_mem_rsp({name, " rsp"}, mem_word_ref(beat_addr), (err_beat == beat), rsp_stalls);
      end
    end
  endtask

  task automatic load_miss(input string name, input logic [ADDR_WIDTH-1:0] addr, int req_stalls, int rsp_stalls, int core_stalls, int err_beat);
    begin
      issue_core_req({name, " core"}, addr, 1'b0, 2'd2, 1'b0, '0, '0);
      drive_refill({name, " refill"}, addr, req_stalls, rsp_stalls, err_beat);
      expect_core_rsp({name, " rsp"}, mem_word_ref(addr), (err_beat >= 0), core_stalls);
      load_miss_count++;
      if (err_beat >= 0) begin
        error_count++;
      end
    end
  endtask

  task automatic load_hit(input string name, input logic [ADDR_WIDTH-1:0] addr, logic [DATA_WIDTH-1:0] exp_data, int core_stalls);
    begin
      issue_core_req({name, " core"}, addr, 1'b0, 2'd2, 1'b0, '0, '0);
      @(negedge clk);
      #1;
      if (mem_if.req_valid) begin
        $fatal(1, "%s expected hit but saw downstream request addr=%08x", name, mem_if.req_addr);
      end
      expect_core_rsp({name, " rsp"}, exp_data, 1'b0, core_stalls);
      load_hit_count++;
    end
  endtask

  task automatic store_access(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [1:0] size,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb,
    input bit exp_hit,
    input int req_stalls,
    input int rsp_stalls,
    input int core_stalls,
    input logic err
  );
    begin
      issue_core_req({name, " core"}, addr, 1'b1, size, 1'b0, wdata, wstrb);
      accept_mem_write_req({name, " write"}, addr, size, wdata, wstrb, req_stalls);
      deliver_mem_rsp({name, " rsp"}, '0, err, rsp_stalls);
      if (!err) begin
        record_store(addr, wdata, wstrb);
      end
      expect_core_rsp({name, " core rsp"}, '0, err, core_stalls);
      if (exp_hit) begin
        store_hit_count++;
        if (!err) begin
          store_update_count++;
        end
      end else begin
        store_miss_count++;
      end
      if (err) begin
        error_count++;
      end
    end
  endtask

  task automatic invalid_request(input string name, input logic [ADDR_WIDTH-1:0] addr, logic write, logic [1:0] size, logic instr);
    begin
      issue_core_req({name, " core"}, addr, write, size, instr, 32'hfeed_cafe, 4'b1111);
      @(negedge clk);
      #1;
      if (mem_if.req_valid) begin
        $fatal(1, "%s invalid request issued downstream request", name);
      end
      expect_core_rsp({name, " rsp"}, '0, 1'b1, 0);
      error_count++;
    end
  endtask

  task automatic invalidate_check;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_7008;
      load_miss("invalidate fill", addr, 0, 0, 0, -1);
      load_hit("invalidate pre-hit", addr, mem_word_ref(addr), 0);
      @(negedge clk);
      invalidate = 1'b1;
      @(posedge clk);
      #1;
      invalidate = 1'b0;
      load_miss("invalidate refetch", addr, 1, 0, 0, -1);
      invalidate_count++;
    end
  endtask

  task automatic flush_load_abort;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_7100;
      issue_core_req("flush load core", addr, 1'b0, 2'd2, 1'b0, '0, '0);
      accept_mem_read_req("flush load read", line_base(addr), 0);
      @(negedge clk);
      flush = 1'b1;
      #1;
      if (core_if.rsp_valid) begin
        $fatal(1, "flush load produced core response");
      end
      @(posedge clk);
      #1;
      flush = 1'b0;
      repeat (2) @(posedge clk);
      if (core_if.rsp_valid || mem_if.req_valid) begin
        $fatal(1, "flush load left active response/request");
      end
      flush_count++;
      pass_count++;
    end
  endtask

  task automatic flush_store_abort;
    logic [ADDR_WIDTH-1:0] addr;
    begin
      addr = 32'h0000_7200;
      issue_core_req("flush store core", addr, 1'b1, 2'd2, 1'b0, 32'h7200_1111, 4'b1111);
      accept_mem_write_req("flush store write", addr, 2'd2, 32'h7200_1111, 4'b1111, 0);
      @(negedge clk);
      flush = 1'b1;
      #1;
      if (core_if.rsp_valid) begin
        $fatal(1, "flush store produced core response");
      end
      @(posedge clk);
      #1;
      flush = 1'b0;
      repeat (2) @(posedge clk);
      if (core_if.rsp_valid || mem_if.req_valid) begin
        $fatal(1, "flush store left active response/request");
      end
      flush_count++;
      pass_count++;
    end
  endtask

  initial begin
    rst_n = 1'b0;
    flush = 1'b0;
    invalidate = 1'b0;
    override_valid = '0;
    override_wr_ptr = 0;
    pass_count = 0;
    load_miss_count = 0;
    load_hit_count = 0;
    store_hit_count = 0;
    store_miss_count = 0;
    store_update_count = 0;
    conflict_count = 0;
    invalidate_count = 0;
    error_count = 0;
    flush_count = 0;
    backpressure_count = 0;
    mem_req_count = 0;
    mem_rsp_count = 0;
    random_count = 0;
    lfsr = 32'hdc01_cafe;
    reset_core_defaults();
    reset_mem_defaults();

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    load_miss("basic miss", 32'h0000_1008, 0, 0, 0, -1);
    load_hit("same word hit", 32'h0000_1008, mem_word_ref(32'h0000_1008), 0);
    load_hit("same line hit", 32'h0000_100c, mem_word_ref(32'h0000_100c), 2);

    store_access("store hit word", 32'h0000_1008, 2'd2, 32'habcd_1234, 4'b1111, 1, 0, 0, 0, 1'b0);
    load_hit("post store hit load", 32'h0000_1008, mem_word_ref(32'h0000_1008), 0);
    store_access("store hit byte", 32'h0000_1009, 2'd0, 32'h0000_ee00, 4'b0010, 1, 1, 1, 1, 1'b0);
    load_hit("post byte store hit load", 32'h0000_1008, mem_word_ref(32'h0000_1008), 0);

    store_access("store miss", 32'h0000_3004, 2'd2, 32'h3004_beef, 4'b1111, 0, 0, 0, 0, 1'b0);
    load_miss("store miss later load allocates", 32'h0000_3004, 0, 0, 0, -1);
    load_hit("store miss loaded value hit", 32'h0000_3004, mem_word_ref(32'h0000_3004), 0);

    load_miss("store error fill", 32'h0000_4000, 0, 0, 0, -1);
    store_access("store hit error", 32'h0000_4000, 2'd2, 32'h4000_bad0, 4'b1111, 1, 0, 0, 0, 1'b1);
    load_hit("store error old value", 32'h0000_4000, default_word_for_addr(32'h0000_4000), 0);

    load_miss("conflict first", 32'h0000_5000, 0, 0, 0, -1);
    load_hit("conflict first hit", 32'h0000_5000, mem_word_ref(32'h0000_5000), 0);
    load_miss("conflict replace", 32'h0000_5100, 1, 0, 0, -1);
    load_hit("conflict replace hit", 32'h0000_5100, mem_word_ref(32'h0000_5100), 0);
    load_miss("conflict old miss", 32'h0000_5000, 0, 1, 0, -1);
    conflict_count++;

    invalid_request("invalid instr", 32'h0000_6000, 1'b0, 2'd2, 1'b1);
    invalid_request("invalid size", 32'h0000_6000, 1'b0, 2'd3, 1'b0);
    invalid_request("invalid half align", 32'h0000_6001, 1'b0, 2'd1, 1'b0);
    invalid_request("invalid word align", 32'h0000_6002, 1'b1, 2'd2, 1'b0);

    load_miss("refill error", 32'h0000_6104, 0, 0, 0, 2);
    load_miss("refill error recovery", 32'h0000_6104, 0, 0, 0, -1);
    load_hit("refill recovery hit", 32'h0000_6104, mem_word_ref(32'h0000_6104), 0);

    invalidate_check();
    flush_load_abort();
    flush_store_abort();

    for (int i = 0; i < 12; i++) begin
      logic [ADDR_WIDTH-1:0] addr;
      logic [DATA_WIDTH-1:0] wdata;
      addr = {18'h0, lfsr[15:4], 2'b00};
      wdata = lfsr ^ 32'h55aa_1234;
      load_miss("random fill", addr, int'({31'b0, lfsr[0]}), int'({31'b0, lfsr[1]}), int'({31'b0, lfsr[3:2]}), -1);
      load_hit("random hit", addr, mem_word_ref(addr), int'({31'b0, lfsr[5:4]}));
      store_access("random store hit", addr, 2'd2, wdata, 4'b1111, 1, int'({31'b0, lfsr[6]}), int'({31'b0, lfsr[7]}), 0, 1'b0);
      load_hit("random post store hit", addr, mem_word_ref(addr), 0);
      random_count++;
      lfsr = next_lfsr(lfsr);
    end

    if (pass_count < 250 || load_miss_count < 20 || load_hit_count < 25 ||
        store_hit_count < 10 || store_miss_count < 1 || store_update_count < 10 ||
        conflict_count < 1 || invalidate_count < 1 || error_count < 6 ||
        flush_count < 2 || backpressure_count < 20 || mem_req_count < 80 ||
        mem_rsp_count < 75 || random_count < 12) begin
      $fatal(1, "dcache coverage goal missed pass=%0d lm=%0d lh=%0d sh=%0d sm=%0d su=%0d conflict=%0d inv=%0d err=%0d flush=%0d bp=%0d mem_req=%0d mem_rsp=%0d random=%0d",
             pass_count, load_miss_count, load_hit_count, store_hit_count,
             store_miss_count, store_update_count, conflict_count,
             invalidate_count, error_count, flush_count, backpressure_count,
             mem_req_count, mem_rsp_count, random_count);
    end

    $display("tb_dcache coverage: pass_count=%0d load_miss=%0d load_hit=%0d store_hit=%0d store_miss=%0d store_update=%0d conflict=%0d invalidate=%0d err=%0d flush=%0d backpressure=%0d mem_req=%0d mem_rsp=%0d random=%0d",
             pass_count, load_miss_count, load_hit_count, store_hit_count,
             store_miss_count, store_update_count, conflict_count,
             invalidate_count, error_count, flush_count, backpressure_count,
             mem_req_count, mem_rsp_count, random_count);
    $display("tb_dcache PASS");
    $finish;
  end
endmodule
