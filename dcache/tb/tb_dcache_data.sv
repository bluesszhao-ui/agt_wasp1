`timescale 1ns/1ps

// tb_dcache_data verifies D-cache line storage, load word selection, and
// store-hit byte merging. A reference line array checks directed and
// deterministic-random refill/store/lookup behavior.
module tb_dcache_data;
  localparam int LINE_COUNT = 8;
  localparam int LINE_BYTES = 16;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int LINE_BITS = LINE_BYTES * 8;
  localparam int INDEX_BITS = $clog2(LINE_COUNT);
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);
  localparam int DATA_BYTES = DATA_WIDTH / 8;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;
  localparam int WORDS_PER_LINE = LINE_BYTES / DATA_BYTES;
  localparam int WORD_INDEX_BITS = $clog2(WORDS_PER_LINE);
  localparam int BYTE_OFFSET_BITS = $clog2(DATA_BYTES);
  localparam int TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;

  logic                   clk;            // 100 MHz verification clock.
  logic                   rst_n;          // Active-low reset stimulus; data RAM ignores contents.
  logic [ADDR_WIDTH-1:0]  lookup_addr;    // Lookup address stimulus.
  logic [INDEX_BITS-1:0]  lookup_index;   // DUT decoded index.
  logic [DATA_WIDTH-1:0]  lookup_word;    // DUT selected word.
  logic [LINE_BITS-1:0]   lookup_line;    // DUT selected line.
  logic                   refill_valid;   // Refill write qualifier.
  logic [ADDR_WIDTH-1:0]  refill_addr;    // Refill address stimulus.
  logic [LINE_BITS-1:0]   refill_line;    // Refill line stimulus.
  logic                   store_valid;    // Store-hit update qualifier.
  logic [ADDR_WIDTH-1:0]  store_addr;     // Store update address stimulus.
  logic [DATA_WIDTH-1:0]  store_wdata;    // Store write data stimulus.
  logic [STRB_WIDTH-1:0]  store_wstrb;    // Store byte lane mask stimulus.

  logic [LINE_BITS-1:0]   model_line [LINE_COUNT]; // Reference line storage.
  integer pass_count;             // Total passing checks.
  integer refill_count;           // Refill write coverage.
  integer lookup_count;           // Lookup coverage.
  integer store_count;            // Store merge coverage.
  integer byte_lane_count;        // Individual byte lane coverage.
  integer word_count;             // Word-offset coverage.
  integer conflict_count;         // Same-index replacement coverage.
  integer priority_count;         // Refill-over-store priority coverage.
  integer random_count;           // Deterministic-random checks.
  logic [31:0] lfsr;              // Deterministic pseudo-random state.

  dcache_data #(
    .LINE_COUNT(LINE_COUNT),
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .lookup_addr_i(lookup_addr),
    .lookup_index_o(lookup_index),
    .lookup_word_o(lookup_word),
    .lookup_line_o(lookup_line),
    .refill_valid_i(refill_valid),
    .refill_addr_i(refill_addr),
    .refill_line_i(refill_line),
    .store_valid_i(store_valid),
    .store_addr_i(store_addr),
    .store_wdata_i(store_wdata),
    .store_wstrb_i(store_wstrb)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] make_addr(
    input logic [TAG_BITS-1:0] tag,
    input logic [INDEX_BITS-1:0] index,
    input logic [OFFSET_BITS-1:0] offset
  );
    make_addr = {tag, index, offset};
  endfunction

  function automatic logic [INDEX_BITS-1:0] addr_index(input logic [ADDR_WIDTH-1:0] addr);
    addr_index = addr[OFFSET_BITS +: INDEX_BITS];
  endfunction

  function automatic logic [WORD_INDEX_BITS-1:0] addr_word_index(input logic [ADDR_WIDTH-1:0] addr);
    addr_word_index = addr[BYTE_OFFSET_BITS +: WORD_INDEX_BITS];
  endfunction

  function automatic logic [LINE_BITS-1:0] make_line(input logic [31:0] seed);
    logic [LINE_BITS-1:0] line;
    begin
      for (int word = 0; word < WORDS_PER_LINE; word++) begin
        line[word * DATA_WIDTH +: DATA_WIDTH] = seed ^ (32'h2211_0000 + 32'(word));
      end
      make_line = line;
    end
  endfunction

  function automatic logic [LINE_BITS-1:0] merge_store(
    input logic [LINE_BITS-1:0] line,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb
  );
    logic [LINE_BITS-1:0] merged;
    logic [WORD_INDEX_BITS-1:0] word_index;
    begin
      merged = line;
      word_index = addr_word_index(addr);
      for (int word = 0; word < WORDS_PER_LINE; word++) begin
        if (word_index == WORD_INDEX_BITS'(word)) begin
          for (int lane = 0; lane < STRB_WIDTH; lane++) begin
            if (wstrb[lane]) begin
              merged[word * DATA_WIDTH + lane * 8 +: 8] = wdata[lane * 8 +: 8];
            end
          end
        end
      end
      merge_store = merged;
    end
  endfunction

  task automatic model_clear;
    begin
      for (int i = 0; i < LINE_COUNT; i++) begin
        model_line[i] = '0;
      end
    end
  endtask

  task automatic expect_lookup(input string name, input logic [ADDR_WIDTH-1:0] addr);
    logic [INDEX_BITS-1:0] exp_index;
    logic [WORD_INDEX_BITS-1:0] exp_word_index;
    logic [DATA_WIDTH-1:0] exp_word;
    logic [LINE_BITS-1:0] exp_line;
    begin
      lookup_addr = addr;
      #1;
      exp_index = addr_index(addr);
      exp_word_index = addr_word_index(addr);
      exp_line = model_line[exp_index];
      exp_word = exp_line[DATA_WIDTH * exp_word_index +: DATA_WIDTH];
      if ((lookup_index !== exp_index) || (lookup_line !== exp_line) ||
          (lookup_word !== exp_word)) begin
        $fatal(1, "%s lookup mismatch idx=%0d exp=%0d word=%08x exp=%08x line=%032x exp=%032x",
               name, lookup_index, exp_index, lookup_word, exp_word,
               lookup_line, exp_line);
      end
      lookup_count++;
      pass_count++;
    end
  endtask

  task automatic do_refill(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [LINE_BITS-1:0] line
  );
    logic [INDEX_BITS-1:0] index;
    begin
      @(negedge clk);
      refill_valid = 1'b1;
      refill_addr = addr;
      refill_line = line;
      @(posedge clk);
      #1;
      refill_valid = 1'b0;
      index = addr_index(addr);
      model_line[index] = line;
      refill_count++;
      pass_count++;
      expect_lookup(name, addr);
    end
  endtask

  task automatic do_store(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb
  );
    logic [INDEX_BITS-1:0] index;
    logic [LINE_BITS-1:0] old_line;
    begin
      index = addr_index(addr);
      old_line = model_line[index];
      @(negedge clk);
      lookup_addr = addr;
      store_valid = 1'b1;
      store_addr = addr;
      store_wdata = wdata;
      store_wstrb = wstrb;
      #1;
      if (lookup_line !== old_line) begin
        $fatal(1, "%s store became visible before clock edge", name);
      end
      @(posedge clk);
      #1;
      store_valid = 1'b0;
      model_line[index] = merge_store(old_line, addr, wdata, wstrb);
      store_count++;
      for (int lane = 0; lane < STRB_WIDTH; lane++) begin
        if (wstrb[lane]) begin
          byte_lane_count++;
        end
      end
      expect_lookup(name, addr);
    end
  endtask

  initial begin
    logic [ADDR_WIDTH-1:0] addr_a;
    logic [ADDR_WIDTH-1:0] addr_b;
    logic [ADDR_WIDTH-1:0] addr_c;
    logic [ADDR_WIDTH-1:0] rand_addr;
    logic [LINE_BITS-1:0] line_a;
    logic [LINE_BITS-1:0] line_b;
    logic [LINE_BITS-1:0] line_c;
    logic [LINE_BITS-1:0] rand_line;

    pass_count = 0;
    refill_count = 0;
    lookup_count = 0;
    store_count = 0;
    byte_lane_count = 0;
    word_count = 0;
    conflict_count = 0;
    priority_count = 0;
    random_count = 0;
    lfsr = 32'hdcac_1234;
    model_clear();

    lookup_addr = 32'h0000_0000;
    refill_valid = 1'b0;
    refill_addr = 32'h0000_0000;
    refill_line = '0;
    store_valid = 1'b0;
    store_addr = 32'h0000_0000;
    store_wdata = '0;
    store_wstrb = '0;
    rst_n = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    addr_a = make_addr(TAG_BITS'(9'h011), INDEX_BITS'(3'd2), OFFSET_BITS'(4'h0));
    addr_b = make_addr(TAG_BITS'(9'h012), INDEX_BITS'(3'd2), OFFSET_BITS'(4'h4));
    addr_c = make_addr(TAG_BITS'(9'h021), INDEX_BITS'(3'd5), OFFSET_BITS'(4'h8));
    line_a = make_line(32'hA0A0_0000);
    line_b = make_line(32'hB0B0_0000);
    line_c = make_line(32'hC0C0_0000);

    do_refill("refill addr_a", addr_a, line_a);
    for (int word = 0; word < WORDS_PER_LINE; word++) begin
      expect_lookup("word select addr_a",
                    make_addr(TAG_BITS'(9'h011), INDEX_BITS'(3'd2),
                              OFFSET_BITS'(word * DATA_BYTES)));
      word_count++;
    end

    do_store("store byte lane 0", addr_a, 32'h0000_00aa, 4'b0001);
    do_store("store byte lane 1", addr_a, 32'h0000_bb00, 4'b0010);
    do_store("store upper half", make_addr(TAG_BITS'(9'h011), INDEX_BITS'(3'd2), OFFSET_BITS'(4'h2)),
             32'hccdd_0000, 4'b1100);
    do_store("store full word", make_addr(TAG_BITS'(9'h011), INDEX_BITS'(3'd2), OFFSET_BITS'(4'hC)),
             32'h1234_5678, 4'b1111);
    do_store("store zero strobe hold", addr_a, 32'hffff_ffff, 4'b0000);

    do_refill("refill addr_c", addr_c, line_c);
    expect_lookup("addr_c line", addr_c);
    expect_lookup("addr_a still intact", addr_a);

    do_refill("conflict replace addr_b", addr_b, line_b);
    conflict_count++;
    expect_lookup("old index now line_b", addr_a);
    if (lookup_line !== line_b) begin
      $fatal(1, "conflict line did not replace old data");
    end

    @(negedge clk);
    lookup_addr = addr_b;
    refill_valid = 1'b1;
    refill_addr = addr_b;
    refill_line = line_a;
    store_valid = 1'b1;
    store_addr = addr_b;
    store_wdata = 32'hffff_ffff;
    store_wstrb = 4'b1111;
    @(posedge clk);
    #1;
    refill_valid = 1'b0;
    store_valid = 1'b0;
    model_line[addr_index(addr_b)] = line_a;
    priority_count++;
    refill_count++;
    expect_lookup("refill priority over store", addr_b);

    for (int i = 0; i < 160; i++) begin
      lfsr = next_lfsr(lfsr);
      rand_addr = {lfsr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
      rand_addr[BYTE_OFFSET_BITS +: WORD_INDEX_BITS] = lfsr[5:4];
      rand_line = make_line(lfsr ^ 32'h6b6b_0000);
      unique case (lfsr[2:0])
        3'd0,
        3'd1,
        3'd2: begin
          do_refill("random refill", rand_addr, rand_line);
        end
        3'd3,
        3'd4,
        3'd5: begin
          do_store("random store", rand_addr, lfsr ^ 32'hf00d_0000,
                   lfsr[6:3]);
        end
        default: begin
          expect_lookup("random lookup", rand_addr);
        end
      endcase
      random_count++;
    end

    if (pass_count < 170 || refill_count < 40 || lookup_count < 100 ||
        store_count < 40 || byte_lane_count < 60 ||
        word_count < WORDS_PER_LINE || conflict_count < 1 ||
        priority_count < 1 || random_count < 160) begin
      $fatal(1, "dcache_data coverage goal missed pass=%0d refill=%0d lookup=%0d store=%0d byte_lane=%0d word=%0d conflict=%0d priority=%0d random=%0d",
             pass_count, refill_count, lookup_count, store_count,
             byte_lane_count, word_count, conflict_count, priority_count,
             random_count);
    end

    $display("tb_dcache_data coverage: pass_count=%0d refill=%0d lookup=%0d store=%0d byte_lane=%0d word=%0d conflict=%0d priority=%0d random=%0d",
             pass_count, refill_count, lookup_count, store_count,
             byte_lane_count, word_count, conflict_count, priority_count,
             random_count);
    $display("tb_dcache_data PASS");
    $finish;
  end
endmodule
