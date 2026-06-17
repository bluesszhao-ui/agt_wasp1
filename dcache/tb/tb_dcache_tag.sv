`timescale 1ns/1ps

// tb_dcache_tag is a self-checking testbench for the direct-mapped dcache tag
// store. It mirrors valid/tag state in a reference model and checks directed
// and deterministic-random lookup/refill/invalidate behavior.
module tb_dcache_tag;
  localparam int LINE_COUNT = 8;
  localparam int LINE_BYTES = 16;
  localparam int ADDR_WIDTH = 32;
  localparam int INDEX_BITS = $clog2(LINE_COUNT);
  localparam int OFFSET_BITS = $clog2(LINE_BYTES);
  localparam int TAG_BITS = ADDR_WIDTH - OFFSET_BITS - INDEX_BITS;

  logic                  clk;            // 100 MHz verification clock.
  logic                  rst_n;          // Active-low reset stimulus.
  logic                  invalidate;     // Invalidate-all stimulus.
  logic                  lookup_valid;   // Lookup valid stimulus.
  logic [ADDR_WIDTH-1:0] lookup_addr;    // Lookup address stimulus.
  logic                  lookup_hit;     // DUT lookup hit.
  logic [INDEX_BITS-1:0] lookup_index;   // DUT lookup index.
  logic                  refill_valid;   // Refill update stimulus.
  logic [ADDR_WIDTH-1:0] refill_addr;    // Refill address stimulus.
  logic                  refill_error;   // Refill error stimulus.

  logic [TAG_BITS-1:0]   model_tag [LINE_COUNT]; // Reference tags.
  logic [LINE_COUNT-1:0] model_valid;            // Reference valid bits.
  integer pass_count;             // Total passing checks.
  integer lookup_count;           // Lookup checks.
  integer hit_count;              // Hit coverage counter.
  integer miss_count;             // Miss coverage counter.
  integer refill_count;           // Successful refill checks.
  integer error_count;            // Failed refill checks.
  integer conflict_count;         // Same-index different-tag replacement checks.
  integer invalidate_count;       // Invalidate checks.
  integer random_count;           // Deterministic-random operation checks.
  logic [31:0] lfsr;              // Deterministic pseudo-random state.

  dcache_tag #(
    .LINE_COUNT(LINE_COUNT),
    .LINE_BYTES(LINE_BYTES),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .invalidate_i(invalidate),
    .lookup_valid_i(lookup_valid),
    .lookup_addr_i(lookup_addr),
    .lookup_hit_o(lookup_hit),
    .lookup_index_o(lookup_index),
    .refill_valid_i(refill_valid),
    .refill_addr_i(refill_addr),
    .refill_error_i(refill_error)
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

  function automatic logic [TAG_BITS-1:0] addr_tag(input logic [ADDR_WIDTH-1:0] addr);
    addr_tag = addr[ADDR_WIDTH-1 -: TAG_BITS];
  endfunction

  task automatic model_clear;
    integer i;
    begin
      model_valid = '0;
      for (i = 0; i < LINE_COUNT; i++) begin
        model_tag[i] = '0;
      end
    end
  endtask

  task automatic expect_lookup(input string name, input logic [ADDR_WIDTH-1:0] addr);
    logic exp_hit;
    logic [INDEX_BITS-1:0] exp_index;
    begin
      lookup_valid = 1'b1;
      lookup_addr = addr;
      #1;
      exp_index = addr_index(addr);
      exp_hit = model_valid[exp_index] && (model_tag[exp_index] == addr_tag(addr));
      if ((lookup_index !== exp_index) || (lookup_hit !== exp_hit)) begin
        $fatal(1, "%s lookup mismatch idx=%0d exp=%0d hit=%0b exp=%0b addr=%08x",
               name, lookup_index, exp_index, lookup_hit, exp_hit, addr);
      end
      lookup_count++;
      if (exp_hit) begin
        hit_count++;
      end else begin
        miss_count++;
      end
      pass_count++;
      lookup_valid = 1'b0;
    end
  endtask

  task automatic do_refill(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic err
  );
    logic [INDEX_BITS-1:0] index;
    begin
      @(negedge clk);
      refill_valid = 1'b1;
      refill_addr = addr;
      refill_error = err;
      @(posedge clk);
      #1;
      refill_valid = 1'b0;
      refill_error = 1'b0;
      index = addr_index(addr);
      model_tag[index] = addr_tag(addr);
      model_valid[index] = !err;
      if (err) begin
        error_count++;
      end else begin
        refill_count++;
      end
      expect_lookup(name, addr);
    end
  endtask

  task automatic do_invalidate(input string name);
    begin
      @(negedge clk);
      invalidate = 1'b1;
      @(posedge clk);
      #1;
      invalidate = 1'b0;
      model_clear();
      invalidate_count++;
      pass_count++;
      expect_lookup(name, lookup_addr);
    end
  endtask

  initial begin
    logic [ADDR_WIDTH-1:0] addr_a;
    logic [ADDR_WIDTH-1:0] addr_b;
    logic [ADDR_WIDTH-1:0] addr_c;
    logic [ADDR_WIDTH-1:0] rand_addr;
    integer i;

    pass_count = 0;
    lookup_count = 0;
    hit_count = 0;
    miss_count = 0;
    refill_count = 0;
    error_count = 0;
    conflict_count = 0;
    invalidate_count = 0;
    random_count = 0;
    lfsr = 32'h2468_ace1;
    model_clear();

    invalidate = 1'b0;
    lookup_valid = 1'b0;
    lookup_addr = 32'h0000_0000;
    refill_valid = 1'b0;
    refill_addr = 32'h0000_0000;
    refill_error = 1'b0;
    rst_n = 1'b0;

    repeat (2) @(posedge clk);
    expect_lookup("reset miss", make_addr(TAG_BITS'(9'h001), INDEX_BITS'(3'd2), '0));
    rst_n = 1'b1;
    @(posedge clk);
    expect_lookup("reset release miss", make_addr(TAG_BITS'(9'h001), INDEX_BITS'(3'd2), '0));

    addr_a = make_addr(TAG_BITS'(9'h012), INDEX_BITS'(3'd2), OFFSET_BITS'(4'h0));
    addr_b = make_addr(TAG_BITS'(9'h013), INDEX_BITS'(3'd2), OFFSET_BITS'(4'h4));
    addr_c = make_addr(TAG_BITS'(9'h022), INDEX_BITS'(3'd5), OFFSET_BITS'(4'h8));

    do_refill("refill addr_a hit", addr_a, 1'b0);
    expect_lookup("same line offset hit", make_addr(TAG_BITS'(9'h012), INDEX_BITS'(3'd2), OFFSET_BITS'(4'hC)));
    expect_lookup("different index miss", addr_c);
    do_refill("refill error stays miss", addr_c, 1'b1);
    do_refill("refill addr_c hit", addr_c, 1'b0);

    do_refill("conflict replace", addr_b, 1'b0);
    conflict_count++;
    expect_lookup("old tag conflict miss", addr_a);
    expect_lookup("new tag conflict hit", addr_b);

    lookup_addr = addr_b;
    do_invalidate("invalidate clears hit");

    for (i = 0; i < 120; i++) begin
      lfsr = next_lfsr(lfsr);
      rand_addr = {lfsr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
      unique case (lfsr[2:0])
        3'b000: begin
          do_invalidate("random invalidate");
        end
        3'b001: begin
          do_refill("random error refill", rand_addr, 1'b1);
        end
        3'b010,
        3'b011,
        3'b100: begin
          do_refill("random refill", rand_addr, 1'b0);
        end
        default: begin
          expect_lookup("random lookup", rand_addr);
        end
      endcase
      random_count++;
    end

    if (pass_count < 130 || lookup_count < 100 || hit_count < 20 ||
        miss_count < 20 || refill_count < 30 || error_count < 5 ||
        conflict_count < 1 || invalidate_count < 2 || random_count < 120) begin
      $fatal(1, "dcache_tag coverage goal missed pass=%0d lookup=%0d hit=%0d miss=%0d refill=%0d err=%0d conflict=%0d invalidate=%0d random=%0d",
             pass_count, lookup_count, hit_count, miss_count, refill_count,
             error_count, conflict_count, invalidate_count, random_count);
    end

    $display("tb_dcache_tag coverage: pass_count=%0d lookup=%0d hit=%0d miss=%0d refill=%0d err=%0d conflict=%0d invalidate=%0d random=%0d",
             pass_count, lookup_count, hit_count, miss_count, refill_count,
             error_count, conflict_count, invalidate_count, random_count);
    $display("tb_dcache_tag PASS");
    $finish;
  end
endmodule
