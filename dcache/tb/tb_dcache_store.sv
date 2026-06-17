`timescale 1ns/1ps

// tb_dcache_store verifies the D-cache write-through store sequencer.
// It models the downstream memory path, checks that request fields remain
// stable under backpressure, and verifies completion payload/error reporting.
module tb_dcache_store;
  localparam int ADDR_WIDTH = 32;
  localparam int DATA_WIDTH = 32;
  localparam int STRB_WIDTH = DATA_WIDTH / 8;

  logic                  clk;           // 100 MHz verification clock.
  logic                  rst_n;         // Active-low reset stimulus.
  logic                  flush;         // Abort stimulus.
  logic                  start_valid;   // Store start valid stimulus.
  logic                  start_ready;   // DUT accepts a store request.
  logic [ADDR_WIDTH-1:0] start_addr;    // Store request address stimulus.
  logic [1:0]            start_size;    // Store request size stimulus.
  logic [DATA_WIDTH-1:0] start_wdata;   // Store request write-data stimulus.
  logic [STRB_WIDTH-1:0] start_wstrb;   // Store request byte-strobe stimulus.
  logic                  done_valid;    // DUT completion valid.
  logic                  done_ready;    // Completion backpressure stimulus.
  logic [ADDR_WIDTH-1:0] done_addr;     // DUT completion address.
  logic [1:0]            done_size;     // DUT completion size.
  logic [DATA_WIDTH-1:0] done_wdata;    // DUT completion write data.
  logic [STRB_WIDTH-1:0] done_wstrb;    // DUT completion byte strobes.
  logic                  done_error;    // DUT completion error.

  integer pass_count;          // Total passing checks.
  integer start_count;         // Accepted start checks.
  integer req_count;           // Downstream request checks.
  integer rsp_count;           // Downstream response checks.
  integer done_count;          // Completion checks.
  integer error_count;         // Error response checks.
  integer flush_count;         // Flush abort checks.
  integer backpressure_count;  // Request/output backpressure checks.
  integer random_count;        // Deterministic-random store checks.
  integer byte_count;          // Byte store size coverage.
  integer half_count;          // Halfword store size coverage.
  integer word_count;          // Word store size coverage.
  logic [31:0] lfsr;           // Deterministic pseudo-random state.

  mem_req_rsp_if mem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  dcache_store #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .flush_i(flush),
    .start_valid_i(start_valid),
    .start_ready_o(start_ready),
    .start_addr_i(start_addr),
    .start_size_i(start_size),
    .start_wdata_i(start_wdata),
    .start_wstrb_i(start_wstrb),
    .done_valid_o(done_valid),
    .done_ready_i(done_ready),
    .done_addr_o(done_addr),
    .done_size_o(done_size),
    .done_wdata_o(done_wdata),
    .done_wstrb_o(done_wstrb),
    .done_error_o(done_error),
    .mem_if(mem_if)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  function automatic logic [STRB_WIDTH-1:0] strb_for_size(
    input logic [1:0] size,
    input logic [1:0] addr_low
  );
    logic [STRB_WIDTH-1:0] mask;
    begin
      unique case (size)
        2'd0: mask = STRB_WIDTH'(4'b0001 << addr_low);
        2'd1: mask = addr_low[1] ? STRB_WIDTH'(4'b1100) : STRB_WIDTH'(4'b0011);
        default: mask = STRB_WIDTH'(4'b1111);
      endcase
      strb_for_size = mask;
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

  task automatic note_size_coverage(input logic [1:0] size);
    begin
      unique case (size)
        2'd0: byte_count++;
        2'd1: half_count++;
        default: word_count++;
      endcase
    end
  endtask

  task automatic accept_start(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [1:0] size,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb
  );
    begin
      @(negedge clk);
      start_valid = 1'b1;
      start_addr = addr;
      start_size = size;
      start_wdata = wdata;
      start_wstrb = wstrb;
      #1;
      if (!start_ready) begin
        $fatal(1, "%s start not ready", name);
      end
      @(posedge clk);
      #1;
      start_valid = 1'b0;
      start_count++;
      note_size_coverage(size);
      pass_count++;
    end
  endtask

  task automatic expect_request(
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
        mem_if.req_ready = 1'b0;
        #1;
        if (!mem_if.req_valid || (mem_if.req_addr !== exp_addr) ||
            !mem_if.req_write || (mem_if.req_size !== exp_size) ||
            (mem_if.req_wdata !== exp_wdata) || (mem_if.req_wstrb !== exp_wstrb) ||
            mem_if.req_instr) begin
          $fatal(1, "%s stalled request mismatch valid=%0b addr=%08x size=%0d data=%08x strb=%04b instr=%0b",
                 name, mem_if.req_valid, mem_if.req_addr, mem_if.req_size,
                 mem_if.req_wdata, mem_if.req_wstrb, mem_if.req_instr);
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
        $fatal(1, "%s request mismatch valid=%0b addr=%08x exp=%08x size=%0d exp=%0d data=%08x exp=%08x strb=%04b exp=%04b write=%0b instr=%0b",
               name, mem_if.req_valid, mem_if.req_addr, exp_addr,
               mem_if.req_size, exp_size, mem_if.req_wdata, exp_wdata,
               mem_if.req_wstrb, exp_wstrb, mem_if.req_write, mem_if.req_instr);
      end
      @(posedge clk);
      #1;
      mem_if.req_ready = 1'b0;
      req_count++;
      pass_count++;
    end
  endtask

  task automatic deliver_response(input string name, input logic err, input int stalls);
    begin
      for (int i = 0; i < stalls; i++) begin
        @(negedge clk);
        mem_if.rsp_valid = 1'b0;
        #1;
        if (done_valid) begin
          $fatal(1, "%s completed before downstream response", name);
        end
        pass_count++;
      end
      @(negedge clk);
      mem_if.rsp_valid = 1'b1;
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
    input logic [ADDR_WIDTH-1:0] exp_addr,
    input logic [1:0] exp_size,
    input logic [DATA_WIDTH-1:0] exp_wdata,
    input logic [STRB_WIDTH-1:0] exp_wstrb,
    input logic exp_error,
    input int output_stalls
  );
    begin
      for (int i = 0; i < output_stalls; i++) begin
        @(negedge clk);
        done_ready = 1'b0;
        #1;
        if (!done_valid || (done_addr !== exp_addr) ||
            (done_size !== exp_size) || (done_wdata !== exp_wdata) ||
            (done_wstrb !== exp_wstrb) || (done_error !== exp_error)) begin
          $fatal(1, "%s held completion mismatch valid=%0b addr=%08x exp=%08x size=%0d exp=%0d data=%08x exp=%08x strb=%04b exp=%04b err=%0b exp=%0b",
                 name, done_valid, done_addr, exp_addr, done_size, exp_size,
                 done_wdata, exp_wdata, done_wstrb, exp_wstrb,
                 done_error, exp_error);
        end
        backpressure_count++;
        pass_count++;
      end
      @(negedge clk);
      done_ready = 1'b1;
      #1;
      if (!done_valid || (done_addr !== exp_addr) ||
          (done_size !== exp_size) || (done_wdata !== exp_wdata) ||
          (done_wstrb !== exp_wstrb) || (done_error !== exp_error)) begin
        $fatal(1, "%s completion mismatch valid=%0b addr=%08x exp=%08x size=%0d exp=%0d data=%08x exp=%08x strb=%04b exp=%04b err=%0b exp=%0b",
               name, done_valid, done_addr, exp_addr, done_size, exp_size,
               done_wdata, exp_wdata, done_wstrb, exp_wstrb,
               done_error, exp_error);
      end
      @(posedge clk);
      #1;
      done_ready = 1'b0;
      done_count++;
      if (exp_error) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic run_store(
    input string name,
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [1:0] size,
    input logic [DATA_WIDTH-1:0] wdata,
    input logic [STRB_WIDTH-1:0] wstrb,
    input int req_stalls,
    input int rsp_stalls,
    input int output_stalls,
    input logic err
  );
    begin
      accept_start({name, " start"}, addr, size, wdata, wstrb);
      expect_request({name, " request"}, addr, size, wdata, wstrb, req_stalls);
      deliver_response({name, " response"}, err, rsp_stalls);
      expect_done({name, " done"}, addr, size, wdata, wstrb, err, output_stalls);
    end
  endtask

  initial begin
    logic [ADDR_WIDTH-1:0] rand_addr;
    logic [1:0] rand_size;
    logic [DATA_WIDTH-1:0] rand_data;
    logic [STRB_WIDTH-1:0] rand_strb;

    pass_count = 0;
    start_count = 0;
    req_count = 0;
    rsp_count = 0;
    done_count = 0;
    error_count = 0;
    flush_count = 0;
    backpressure_count = 0;
    random_count = 0;
    byte_count = 0;
    half_count = 0;
    word_count = 0;
    lfsr = 32'h570c_a55a;

    flush = 1'b0;
    start_valid = 1'b0;
    start_addr = 32'h0000_0000;
    start_size = 2'd0;
    start_wdata = 32'h0000_0000;
    start_wstrb = 4'b0000;
    done_ready = 1'b0;
    reset_mem_defaults();
    rst_n = 1'b0;

    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);

    run_store("byte", 32'h0000_1001, 2'd0, 32'h1122_3344, 4'b0010, 0, 0, 0, 1'b0);
    run_store("half bp", 32'h0000_2002, 2'd1, 32'haabb_ccdd, 4'b1100, 3, 2, 2, 1'b0);
    run_store("word error", 32'h0000_3000, 2'd2, 32'h5566_7788, 4'b1111, 0, 0, 0, 1'b1);
    run_store("zero strb passthrough", 32'h0000_4000, 2'd2, 32'hcafe_f00d, 4'b0000, 1, 1, 1, 1'b0);

    accept_start("flush start", 32'h0000_5000, 2'd2, 32'h1234_5678, 4'b1111);
    expect_request("flush request", 32'h0000_5000, 2'd2, 32'h1234_5678, 4'b1111, 0);
    @(negedge clk);
    flush = 1'b1;
    #1;
    if (done_valid || mem_if.req_valid || mem_if.rsp_ready) begin
      $fatal(1, "flush did not suppress store outputs");
    end
    @(posedge clk);
    #1;
    flush = 1'b0;
    flush_count++;
    pass_count++;

    for (int i = 0; i < 32; i++) begin
      lfsr = next_lfsr(lfsr);
      rand_size = lfsr[1:0];
      if (rand_size == 2'd3) begin
        rand_size = 2'd2;
      end
      rand_addr = {lfsr[31:2], 2'b00} | ADDR_WIDTH'({30'b0, lfsr[3:2]});
      rand_data = lfsr ^ 32'hacdc_1357;
      rand_strb = strb_for_size(rand_size, rand_addr[1:0]);
      run_store("random", rand_addr, rand_size, rand_data, rand_strb,
                int'({30'b0, lfsr[5:4]}), int'({30'b0, lfsr[7:6]}),
                int'({30'b0, lfsr[9:8]}), lfsr[10]);
      random_count++;
    end

    if (pass_count < 160 || start_count < 35 || req_count < 35 ||
        rsp_count < 35 || done_count < 35 || error_count < 4 ||
        flush_count < 1 || backpressure_count < 25 || random_count < 32 ||
        byte_count < 5 || half_count < 5 || word_count < 10) begin
      $fatal(1, "dcache_store coverage goal missed pass=%0d start=%0d req=%0d rsp=%0d done=%0d err=%0d flush=%0d bp=%0d random=%0d byte=%0d half=%0d word=%0d",
             pass_count, start_count, req_count, rsp_count, done_count,
             error_count, flush_count, backpressure_count, random_count,
             byte_count, half_count, word_count);
    end

    $display("tb_dcache_store coverage: pass_count=%0d start=%0d req=%0d rsp=%0d done=%0d err=%0d flush=%0d backpressure=%0d random=%0d byte=%0d half=%0d word=%0d",
             pass_count, start_count, req_count, rsp_count, done_count,
             error_count, flush_count, backpressure_count, random_count,
             byte_count, half_count, word_count);
    $display("tb_dcache_store PASS");
    $finish;
  end
endmodule
