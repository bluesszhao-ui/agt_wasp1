`timescale 1ns/1ps

// tb_frontend is the self-checking integration testbench for the frontend top.
// It uses the instruction memory interface as a controllable target and checks
// the PC, fetch, and ibuf blocks as one ready/valid pipeline.
module tb_frontend;
  logic        clk;               // 100 MHz verification clock.
  logic        rst_n;             // Active-low reset driven by the testbench.
  logic [31:0] boot_pc;           // Reset PC stimulus.
  logic        stall;             // PC generation stall stimulus.
  logic        redirect_valid;    // Redirect/flush stimulus qualifier.
  logic [31:0] redirect_pc;       // Redirect target stimulus.
  logic        instr_valid;       // DUT instruction response valid.
  logic        instr_ready;       // Core-side response ready stimulus.
  logic [31:0] instr_pc;          // DUT instruction response PC.
  logic [31:0] instr;             // DUT instruction word.
  logic        instr_fault;       // DUT instruction fault flag.
  logic        instr_misaligned;  // DUT misaligned-PC fault flag.

  integer pass_count;             // Total passing checks.
  integer req_count;              // Accepted instruction memory requests.
  integer rsp_count;              // Accepted instruction memory responses.
  integer pop_count;              // Core-side instruction pops.
  integer backpressure_count;     // Core/imem backpressure checks.
  integer redirect_count;         // Redirect and flush checks.
  integer misalign_count;         // Misaligned PC local fault checks.
  integer stall_count;            // Stall behavior checks.
  integer err_count;              // Memory error propagation checks.
  integer random_count;           // Deterministic-random fetch checks.
  logic [31:0] lfsr;              // Deterministic pseudo-random state.

  mem_req_rsp_if imem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  frontend dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .boot_pc_i(boot_pc),
    .stall_i(stall),
    .redirect_valid_i(redirect_valid),
    .redirect_pc_i(redirect_pc),
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
    #40000;
    $fatal(1, "tb_frontend watchdog timeout");
  end

  function automatic logic [31:0] next_lfsr(input logic [31:0] value);
    next_lfsr = {value[30:0], value[31] ^ value[21] ^ value[1] ^ value[0]};
  endfunction

  function automatic logic [31:0] instr_for_pc(input logic [31:0] addr);
    instr_for_pc = 32'hC000_0000 ^ addr;
  endfunction

  task automatic reset_imem_defaults;
    begin
      imem_if.req_ready = 1'b0;
      imem_if.rsp_valid = 1'b0;
      imem_if.rsp_rdata = 32'h0000_0000;
      imem_if.rsp_err = 1'b0;
    end
  endtask

  task automatic check_no_instr(input string name);
    begin
      #1;
      if (instr_valid) begin
        $fatal(1, "%s unexpected instr valid pc=%08x instr=%08x fault=%0b mis=%0b",
               name, instr_pc, instr, instr_fault, instr_misaligned);
      end
      pass_count++;
    end
  endtask

  task automatic accept_request(input string name, input logic [31:0] exp_pc);
    begin
      @(negedge clk);
      imem_if.req_ready = 1'b1;
      #1;
      if (!imem_if.req_valid || (imem_if.req_addr !== exp_pc) ||
          imem_if.req_write || (imem_if.req_size !== 2'd2) ||
          (imem_if.req_wdata !== 32'h0000_0000) ||
          (imem_if.req_wstrb !== 4'b0000) || !imem_if.req_instr) begin
        $fatal(1, "%s request mismatch valid=%0b addr=%08x write=%0b size=%0d instr=%0b",
               name, imem_if.req_valid, imem_if.req_addr, imem_if.req_write,
               imem_if.req_size, imem_if.req_instr);
      end
      @(posedge clk);
      #1;
      imem_if.req_ready = 1'b0;
      req_count++;
      pass_count++;
    end
  endtask

  task automatic deliver_response(
    input string       name,
    input logic [31:0] data,
    input logic        err
  );
    begin
      @(negedge clk);
      imem_if.rsp_valid = 1'b1;
      imem_if.rsp_rdata = data;
      imem_if.rsp_err = err;
      #1;
      if (!imem_if.rsp_ready) begin
        $fatal(1, "%s response was not accepted", name);
      end
      @(posedge clk);
      #1;
      imem_if.rsp_valid = 1'b0;
      imem_if.rsp_err = 1'b0;
      rsp_count++;
      pass_count++;
    end
  endtask

  task automatic pop_instr(
    input string       name,
    input logic [31:0] exp_pc,
    input logic [31:0] exp_instr,
    input logic        exp_fault,
    input logic        exp_misaligned
  );
    begin
      @(negedge clk);
      instr_ready = 1'b1;
      #1;
      if (!instr_valid || (instr_pc !== exp_pc) || (instr !== exp_instr) ||
          (instr_fault !== exp_fault) ||
          (instr_misaligned !== exp_misaligned)) begin
        $fatal(1, "%s pop mismatch valid=%0b pc=%08x exp=%08x instr=%08x exp=%08x fault=%0b exp=%0b mis=%0b exp=%0b",
               name, instr_valid, instr_pc, exp_pc, instr, exp_instr,
               instr_fault, exp_fault, instr_misaligned, exp_misaligned);
      end
      @(posedge clk);
      #1;
      instr_ready = 1'b0;
      pop_count++;
      pass_count++;
    end
  endtask

  task automatic fetch_and_pop(
    input string       name,
    input logic [31:0] exp_pc,
    input int          rsp_wait_cycles,
    input int          pop_wait_cycles,
    input logic        err
  );
    integer i;
    begin
      accept_request({name, " request"}, exp_pc);
      for (i = 0; i < rsp_wait_cycles; i++) begin
        @(negedge clk);
        check_no_instr({name, " wait"});
      end
      deliver_response({name, " response"}, instr_for_pc(exp_pc), err);
      for (i = 0; i < pop_wait_cycles; i++) begin
        @(negedge clk);
        #1;
        if (!instr_valid || (instr_pc !== exp_pc)) begin
          $fatal(1, "%s backpressure hold mismatch valid=%0b pc=%08x exp=%08x",
                 name, instr_valid, instr_pc, exp_pc);
        end
        backpressure_count++;
        pass_count++;
      end
      pop_instr({name, " pop"}, exp_pc, instr_for_pc(exp_pc), err, 1'b0);
      if (err) begin
        err_count++;
      end
    end
  endtask

  initial begin
    integer i;
    logic [31:0] rand_pc;

    pass_count = 0;
    req_count = 0;
    rsp_count = 0;
    pop_count = 0;
    backpressure_count = 0;
    redirect_count = 0;
    misalign_count = 0;
    stall_count = 0;
    err_count = 0;
    random_count = 0;
    lfsr = 32'h1BAD_C0DE;

    boot_pc = 32'h0000_1000;
    stall = 1'b0;
    redirect_valid = 1'b0;
    redirect_pc = 32'h0000_0000;
    instr_ready = 1'b0;
    reset_imem_defaults();
    rst_n = 1'b0;

    repeat (2) @(posedge clk);
    check_no_instr("reset");
    rst_n = 1'b1;
    @(posedge clk);
    check_no_instr("reset release");

    fetch_and_pop("boot fetch", 32'h0000_1000, 0, 0, 1'b0);

    accept_request("fill req0", 32'h0000_1004);
    deliver_response("fill rsp0", instr_for_pc(32'h0000_1004), 1'b0);
    @(negedge clk);
    #1;
    if (!instr_valid || (instr_pc !== 32'h0000_1004)) begin
      $fatal(1, "first buffered entry not visible");
    end
    pass_count++;

    accept_request("fill req1", 32'h0000_1008);
    deliver_response("fill rsp1", instr_for_pc(32'h0000_1008), 1'b0);
    accept_request("outstanding while full", 32'h0000_100C);

    @(negedge clk);
    imem_if.rsp_valid = 1'b1;
    imem_if.rsp_rdata = instr_for_pc(32'h0000_100C);
    #1;
    if (imem_if.rsp_ready) begin
      $fatal(1, "full ibuf unexpectedly accepted response");
    end
    backpressure_count++;
    pass_count++;

    pop_instr("pop full entry0", 32'h0000_1004, instr_for_pc(32'h0000_1004), 1'b0, 1'b0);
    @(negedge clk);
    #1;
    if (!imem_if.rsp_ready) begin
      $fatal(1, "response did not become ready after ibuf space opened");
    end
    @(posedge clk);
    #1;
    imem_if.rsp_valid = 1'b0;
    rsp_count++;
    pass_count++;
    pop_instr("pop full entry1", 32'h0000_1008, instr_for_pc(32'h0000_1008), 1'b0, 1'b0);
    pop_instr("pop delayed response", 32'h0000_100C, instr_for_pc(32'h0000_100C), 1'b0, 1'b0);

    accept_request("redirect killed request", 32'h0000_1010);
    @(negedge clk);
    redirect_valid = 1'b1;
    redirect_pc = 32'h0000_2001;
    imem_if.rsp_valid = 1'b1;
    imem_if.rsp_rdata = instr_for_pc(32'h0000_1010);
    #1;
    if (!imem_if.rsp_ready || instr_valid) begin
      $fatal(1, "redirect flush mismatch rsp_ready=%0b instr_valid=%0b",
             imem_if.rsp_ready, instr_valid);
    end
    @(posedge clk);
    #1;
    redirect_valid = 1'b0;
    imem_if.rsp_valid = 1'b0;
    redirect_count++;
    pass_count++;

    @(posedge clk);
    pop_instr("misaligned redirect fault", 32'h0000_2001, 32'h0000_0000, 1'b1, 1'b1);
    misalign_count++;

    @(negedge clk);
    redirect_valid = 1'b1;
    redirect_pc = 32'h0000_3000;
    @(posedge clk);
    #1;
    redirect_valid = 1'b0;
    redirect_count++;

    @(negedge clk);
    stall = 1'b1;
    imem_if.req_ready = 1'b1;
    #1;
    if (imem_if.req_valid) begin
      $fatal(1, "stall did not suppress request");
    end
    @(posedge clk);
    #1;
    stall = 1'b0;
    imem_if.req_ready = 1'b0;
    stall_count++;
    pass_count++;

    fetch_and_pop("error fetch", 32'h0000_3000, 1, 1, 1'b1);

    rand_pc = 32'h0000_3004;
    for (i = 0; i < 24; i++) begin
      lfsr = next_lfsr(lfsr);
      fetch_and_pop("random fetch", rand_pc, int'({30'b0, lfsr[1:0]}),
                    int'({30'b0, lfsr[3:2]}), 1'b0);
      rand_pc += 32'd4;
      random_count++;
    end

    if (pass_count < 120 || req_count < 30 || rsp_count < 29 ||
        pop_count < 30 || backpressure_count < 10 || redirect_count < 2 ||
        misalign_count < 1 || stall_count < 1 || err_count < 1 ||
        random_count < 24) begin
      $fatal(1, "frontend coverage goal missed pass=%0d req=%0d rsp=%0d pop=%0d backpressure=%0d redirect=%0d misalign=%0d stall=%0d err=%0d random=%0d",
             pass_count, req_count, rsp_count, pop_count, backpressure_count,
             redirect_count, misalign_count, stall_count, err_count,
             random_count);
    end

    $display("tb_frontend coverage: pass_count=%0d req=%0d rsp=%0d pop=%0d backpressure=%0d redirect=%0d misalign=%0d stall=%0d err=%0d random=%0d",
             pass_count, req_count, rsp_count, pop_count, backpressure_count,
             redirect_count, misalign_count, stall_count, err_count,
             random_count);
    $display("tb_frontend PASS");
    $finish;
  end
endmodule
