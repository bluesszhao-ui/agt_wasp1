`timescale 1ns/1ps

module tb_frontend_fetch;
  logic        clk;              // 100 MHz verification clock.
  logic        rst_n;            // Active-low reset driven by the testbench.
  logic        pc_valid;         // PC request valid stimulus.
  logic        pc_ready;         // DUT PC request ready.
  logic [31:0] pc;               // PC request address stimulus.
  logic        pc_misaligned;    // PC misalignment stimulus.
  logic        flush;            // Redirect/trap flush stimulus.
  logic        instr_valid;      // DUT instruction response valid.
  logic        instr_ready;      // Instruction consumer ready stimulus.
  logic [31:0] instr_pc;         // DUT instruction response PC.
  logic [31:0] instr;            // DUT instruction word.
  logic        instr_fault;      // DUT instruction fault flag.
  logic        instr_misaligned; // DUT instruction misalignment flag.

  integer pass_count;            // Total passing checks.
  integer req_count;             // Accepted memory request coverage.
  integer rsp_count;             // Delivered response coverage.
  integer backpressure_count;    // Response backpressure coverage.
  integer misalign_count;        // Misaligned PC coverage.
  integer flush_count;           // Flush/drop coverage.
  integer err_count;             // Memory error coverage.
  integer random_count;          // Deterministic-random handshake coverage.
  logic [31:0] lfsr;             // Deterministic pseudo-random stimulus state.

  mem_req_rsp_if imem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  frontend_fetch dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .pc_valid_i(pc_valid),
    .pc_ready_o(pc_ready),
    .pc_i(pc),
    .pc_misaligned_i(pc_misaligned),
    .flush_i(flush),
    .instr_valid_o(instr_valid),
    .instr_ready_i(instr_ready),
    .instr_pc_o(instr_pc),
    .instr_o(instr),
    .instr_fault_o(instr_fault),
    .instr_misaligned_o(instr_misaligned),
    .imem_if(imem_if)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    #20000;
    $fatal(1, "tb_frontend_fetch watchdog timeout");
  end

  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  function automatic logic [31:0] instr_for_pc(input logic [31:0] addr);
    instr_for_pc = 32'hA000_0000 ^ addr;
  endfunction

  task automatic reset_bus_defaults;
    begin
      imem_if.req_ready = 1'b0;
      imem_if.rsp_valid = 1'b0;
      imem_if.rsp_rdata = 32'h0000_0000;
      imem_if.rsp_err = 1'b0;
    end
  endtask

  task automatic expect_no_instr(input string name);
    begin
      #1;
      if (instr_valid) begin
        $fatal(1, "%s unexpected instruction pc=%08x instr=%08x fault=%0b",
               name, instr_pc, instr, instr_fault);
      end
      pass_count++;
    end
  endtask

  task automatic accept_request(input logic [31:0] exp_pc);
    begin
      @(negedge clk);
      pc_valid = 1'b1;
      pc = exp_pc;
      pc_misaligned = 1'b0;
      imem_if.req_ready = 1'b1;
      #1;
      if (!pc_ready || !imem_if.req_valid || (imem_if.req_addr !== exp_pc) ||
          imem_if.req_write || (imem_if.req_size !== 2'd2) ||
          (imem_if.req_wstrb !== 4'b0000) || !imem_if.req_instr) begin
        $fatal(1, "request mismatch ready=%0b valid=%0b addr=%08x",
               pc_ready, imem_if.req_valid, imem_if.req_addr);
      end
      @(posedge clk);
      #1;
      pc_valid = 1'b0;
      imem_if.req_ready = 1'b0;
      req_count++;
      pass_count++;
    end
  endtask

  task automatic deliver_response(
    input string       name,
    input logic [31:0] exp_pc,
    input logic [31:0] exp_instr,
    input logic        exp_fault
  );
    begin
      @(negedge clk);
      imem_if.rsp_valid = 1'b1;
      imem_if.rsp_rdata = exp_instr;
      imem_if.rsp_err = exp_fault;
      instr_ready = 1'b1;
      #1;
      if (!instr_valid || !imem_if.rsp_ready || (instr_pc !== exp_pc) ||
          (instr !== exp_instr) || (instr_fault !== exp_fault) ||
          instr_misaligned) begin
        $fatal(1, "%s response mismatch valid=%0b ready=%0b pc=%08x instr=%08x fault=%0b mis=%0b",
               name, instr_valid, imem_if.rsp_ready, instr_pc, instr,
               instr_fault, instr_misaligned);
      end
      @(posedge clk);
      #1;
      imem_if.rsp_valid = 1'b0;
      imem_if.rsp_err = 1'b0;
      rsp_count++;
      pass_count++;
    end
  endtask

  task automatic check_response_backpressure(input logic [31:0] exp_pc);
    begin
      accept_request(exp_pc);
      @(negedge clk);
      imem_if.rsp_valid = 1'b1;
      imem_if.rsp_rdata = instr_for_pc(exp_pc);
      instr_ready = 1'b0;
      #1;
      if (!instr_valid || imem_if.rsp_ready || (instr_pc !== exp_pc)) begin
        $fatal(1, "backpressure mismatch valid=%0b rsp_ready=%0b pc=%08x",
               instr_valid, imem_if.rsp_ready, instr_pc);
      end
      pass_count++;
      backpressure_count++;
      instr_ready = 1'b1;
      #1;
      if (!imem_if.rsp_ready) begin
        $fatal(1, "backpressure release did not assert rsp_ready");
      end
      @(posedge clk);
      #1;
      imem_if.rsp_valid = 1'b0;
      rsp_count++;
    end
  endtask

  task automatic check_misaligned(input logic [31:0] bad_pc);
    begin
      @(negedge clk);
      pc_valid = 1'b1;
      pc = bad_pc;
      pc_misaligned = 1'b1;
      instr_ready = 1'b1;
      #1;
      if (!pc_ready || imem_if.req_valid || !instr_valid ||
          (instr_pc !== bad_pc) || (instr !== 32'h0000_0000) ||
          !instr_fault || !instr_misaligned) begin
        $fatal(1, "misaligned response mismatch ready=%0b req=%0b valid=%0b pc=%08x fault=%0b mis=%0b",
               pc_ready, imem_if.req_valid, instr_valid, instr_pc,
               instr_fault, instr_misaligned);
      end
      @(posedge clk);
      #1;
      pc_valid = 1'b0;
      pc_misaligned = 1'b0;
      misalign_count++;
      pass_count++;
    end
  endtask

  task automatic check_flush_drop(input logic [31:0] exp_pc);
    begin
      accept_request(exp_pc);
      @(negedge clk);
      flush = 1'b1;
      #1;
      if (instr_valid) begin
        $fatal(1, "flush asserted with unexpected instruction valid");
      end
      @(posedge clk);
      #1;
      flush = 1'b0;
      @(negedge clk);
      imem_if.rsp_valid = 1'b1;
      imem_if.rsp_rdata = instr_for_pc(exp_pc);
      instr_ready = 1'b0;
      #1;
      if (instr_valid || !imem_if.rsp_ready) begin
        $fatal(1, "flush drop mismatch instr_valid=%0b rsp_ready=%0b",
               instr_valid, imem_if.rsp_ready);
      end
      @(posedge clk);
      #1;
      imem_if.rsp_valid = 1'b0;
      flush_count++;
      pass_count++;
    end
  endtask

  task automatic random_transaction(input logic [31:0] exp_pc);
    integer wait_cycles;
    integer rsp_delay;
    integer rsp_wait_cycles;
    begin
      @(negedge clk);
      pc_valid = 1'b1;
      pc = exp_pc;
      pc_misaligned = 1'b0;
      imem_if.req_ready = 1'b0;
      wait_cycles = 0;
      do begin
        @(negedge clk);
        lfsr = next_lfsr(lfsr);
        imem_if.req_ready = lfsr[0] || (wait_cycles >= 3);
        #1;
        wait_cycles++;
        if (wait_cycles > 6) begin
          $fatal(1, "random request wait timeout");
        end
      end while (!pc_ready);
      if (!imem_if.req_valid || (imem_if.req_addr !== exp_pc)) begin
        $fatal(1, "random request mismatch valid=%0b addr=%08x exp=%08x",
               imem_if.req_valid, imem_if.req_addr, exp_pc);
      end
      @(posedge clk);
      #1;
      pc_valid = 1'b0;
      imem_if.req_ready = 1'b0;
      req_count++;

      rsp_delay = {29'd0, 1'b0, lfsr[3:2]};
      repeat (rsp_delay) @(posedge clk);
      @(negedge clk);
      imem_if.rsp_valid = 1'b1;
      imem_if.rsp_rdata = instr_for_pc(exp_pc);
      instr_ready = lfsr[4];
      if (!instr_ready) begin
        backpressure_count++;
      end
      rsp_wait_cycles = 0;
      #1;
      while (!imem_if.rsp_ready) begin
        @(negedge clk);
        instr_ready = 1'b1;
        #1;
        rsp_wait_cycles++;
        if (rsp_wait_cycles > 4) begin
          $fatal(1, "random response wait timeout");
        end
      end
      if (!instr_valid || (instr_pc !== exp_pc) ||
          (instr !== instr_for_pc(exp_pc)) || instr_fault) begin
        $fatal(1, "random response mismatch valid=%0b pc=%08x instr=%08x fault=%0b",
               instr_valid, instr_pc, instr, instr_fault);
      end
      @(posedge clk);
      #1;
      imem_if.rsp_valid = 1'b0;
      rsp_count++;
      random_count++;
      pass_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    req_count = 0;
    rsp_count = 0;
    backpressure_count = 0;
    misalign_count = 0;
    flush_count = 0;
    err_count = 0;
    random_count = 0;
    lfsr = 32'h3456_789A;

    pc_valid = 1'b0;
    pc = 32'h0000_0000;
    pc_misaligned = 1'b0;
    flush = 1'b0;
    instr_ready = 1'b1;
    reset_bus_defaults();
    rst_n = 1'b0;

    repeat (2) @(posedge clk);
    expect_no_instr("reset");
    rst_n = 1'b1;

    accept_request(32'h0001_0000);
    deliver_response("normal fetch", 32'h0001_0000,
                     instr_for_pc(32'h0001_0000), 1'b0);

    check_response_backpressure(32'h0001_0004);
    check_misaligned(32'h0001_0002);
    check_flush_drop(32'h0001_0008);

    accept_request(32'h0001_000C);
    deliver_response("error fetch", 32'h0001_000C, 32'hDEAD_BEEF, 1'b1);
    err_count++;

    repeat (40) begin
      lfsr = next_lfsr(lfsr);
      random_transaction({16'h0002, lfsr[15:2], 2'b00});
    end

    if (pass_count < 45 || req_count < 43 || rsp_count < 42 ||
        backpressure_count < 1 || misalign_count < 1 ||
        flush_count < 1 || err_count < 1 || random_count < 40) begin
      $fatal(1, "frontend_fetch coverage goal missed");
    end

    $display("tb_frontend_fetch coverage: pass_count=%0d req=%0d rsp=%0d backpressure=%0d misalign=%0d flush=%0d err=%0d random=%0d",
             pass_count, req_count, rsp_count, backpressure_count,
             misalign_count, flush_count, err_count, random_count);
    $display("tb_frontend_fetch PASS");
    $finish;
  end
endmodule
