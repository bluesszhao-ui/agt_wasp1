`timescale 1ns/1ps

// Self-checking testbench for core_regfile.
//
// The bench mirrors architectural register contents in model_regs and verifies
// reset, x0 immutability, dual reads, same-cycle bypass, and random accesses.
module tb_core_regfile;
  logic        clk;    // 100MHz test clock.
  logic        rst_n;  // Active-low DUT reset.
  logic [4:0]  raddr1; // Read port 1 address stimulus.
  logic [31:0] rdata1; // Read port 1 DUT data.
  logic [4:0]  raddr2; // Read port 2 address stimulus.
  logic [31:0] rdata2; // Read port 2 DUT data.
  logic        we;     // Write enable stimulus.
  logic [4:0]  waddr;  // Write address stimulus.
  logic [31:0] wdata;  // Write data stimulus.

  logic [31:0] model_regs [31:0]; // Architectural reference model including x0.

  int unsigned pass_count;    // Number of successful checks.
  int unsigned reset_checks;  // Reset read coverage counter.
  int unsigned write_checks;  // Register write coverage counter.
  int unsigned x0_checks;     // x0 immutability coverage counter.
  int unsigned bypass_checks; // Same-cycle write/read bypass coverage counter.
  int unsigned random_checks; // Deterministic random access counter.

  core_regfile u_core_regfile (
    .clk_i(clk),
    .rst_ni(rst_n),
    .raddr1_i(raddr1),
    .rdata1_o(rdata1),
    .raddr2_i(raddr2),
    .rdata2_o(rdata2),
    .we_i(we),
    .waddr_i(waddr),
    .wdata_i(wdata)
  );

  // Generate the project default 10ns clock.
  initial begin
    clk = 1'b0;
    forever #5ns clk = ~clk;
  end

  // Drive inactive bus values between tests.
  task automatic idle_inputs;
    begin
      raddr1 = 5'd0;
      raddr2 = 5'd0;
      we = 1'b0;
      waddr = 5'd0;
      wdata = 32'h0000_0000;
    end
  endtask

  // Reference architectural read. x0 is always zero regardless of model array.
  function automatic logic [31:0] ref_read(input logic [4:0] addr);
    begin
      if (addr == 5'd0) begin
        ref_read = 32'h0000_0000;
      end else begin
        ref_read = model_regs[addr];
      end
    end
  endfunction

  // Check both combinational read ports against expected values.
  task automatic check_read(
    input logic [4:0] addr1,
    input logic [31:0] exp1,
    input logic [4:0] addr2,
    input logic [31:0] exp2,
    input string label
  );
    begin
      raddr1 = addr1;
      raddr2 = addr2;
      #1ns;
      if ((rdata1 !== exp1) || (rdata2 !== exp2)) begin
        $error("%s: r1 x%0d expected=0x%08h got=0x%08h r2 x%0d expected=0x%08h got=0x%08h",
               label, addr1, exp1, rdata1, addr2, exp2, rdata2);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Commit one write and update the reference model after the DUT clock edge.
  task automatic write_reg(
    input logic [4:0] addr,
    input logic [31:0] data,
    input string label
  );
    begin
      @(negedge clk);
      we = 1'b1;
      waddr = addr;
      wdata = data;
      @(posedge clk);
      #1ns;
      if (addr != 5'd0) begin
        model_regs[addr] = data;
      end
      we = 1'b0;
      check_read(addr, ref_read(addr), 5'd0, 32'h0000_0000, label);
      write_checks++;
    end
  endtask

  // Reset DUT and verify every logical register reads zero.
  task automatic check_reset_state;
    begin
      rst_n = 1'b0;
      repeat (3) @(posedge clk);
      @(negedge clk);
      rst_n = 1'b1;
      #1ns;
      for (int unsigned idx = 0; idx < 32; idx++) begin
        model_regs[idx] = 32'h0000_0000;
      end
      for (int unsigned idx = 0; idx < 32; idx += 2) begin
        check_read(5'(idx), 32'h0000_0000,
                   5'(idx + 1), 32'h0000_0000,
                   "reset clear");
        reset_checks += 2;
      end
    end
  endtask

  task automatic check_x0_immutable;
    begin
      write_reg(5'd0, 32'hFFFF_FFFF, "x0 write ignored");
      check_read(5'd0, 32'h0000_0000, 5'd1, ref_read(5'd1), "x0 remains zero");
      x0_checks += 2;
    end
  endtask

  task automatic check_bypass;
    logic [4:0] addr;
    logic [31:0] data;
    begin
      addr = 5'd7;
      data = 32'hCAFE_7007;
      @(negedge clk);
      we = 1'b1;
      waddr = addr;
      wdata = data;
      raddr1 = addr;
      raddr2 = addr;
      #1ns;
      if ((rdata1 !== data) || (rdata2 !== data)) begin
        $error("write bypass failed: expected=0x%08h rdata1=0x%08h rdata2=0x%08h",
               data, rdata1, rdata2);
        $fatal(1);
      end
      bypass_checks++;
      @(posedge clk);
      #1ns;
      model_regs[addr] = data;
      we = 1'b0;
      check_read(addr, data, 5'd0, 32'h0000_0000, "bypass committed");
    end
  endtask

  task automatic check_directed_writes;
    begin
      write_reg(5'd1, 32'h1111_0001, "write x1");
      write_reg(5'd2, 32'h2222_0002, "write x2");
      write_reg(5'd31, 32'hFFFF_0031, "write x31");
      check_read(5'd1, 32'h1111_0001, 5'd2, 32'h2222_0002, "dual read");
      check_read(5'd31, 32'hFFFF_0031, 5'd0, 32'h0000_0000, "high reg read");
    end
  endtask

  task automatic check_random(input int unsigned count);
    logic [4:0] addr;
    logic [31:0] data;
    logic [4:0] ra;
    logic [4:0] rb;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        addr = 5'($urandom_range(0, 31));
        data = $urandom();
        write_reg(addr, data, "random write");

        ra = 5'($urandom_range(0, 31));
        rb = 5'($urandom_range(0, 31));
        check_read(ra, ref_read(ra), rb, ref_read(rb), "random read");
        random_checks++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (reset_checks < 32 || write_checks < 35 || x0_checks < 2 ||
          bypass_checks < 1 || random_checks < 32) begin
        $error("coverage miss: reset=%0d write=%0d x0=%0d bypass=%0d random=%0d",
               reset_checks, write_checks, x0_checks, bypass_checks, random_checks);
        $fatal(1);
      end
      $display("tb_core_regfile coverage: pass_count=%0d reset_checks=%0d write_checks=%0d x0_checks=%0d bypass_checks=%0d random_checks=%0d",
               pass_count, reset_checks, write_checks, x0_checks, bypass_checks, random_checks);
    end
  endtask

  initial begin
    void'($urandom(32'hC0DE_0002));
    pass_count = 0;
    reset_checks = 0;
    write_checks = 0;
    x0_checks = 0;
    bypass_checks = 0;
    random_checks = 0;
    for (int unsigned idx = 0; idx < 32; idx++) begin
      model_regs[idx] = 32'h0000_0000;
    end

    idle_inputs();
    rst_n = 1'b1;

    check_reset_state();
    check_x0_immutable();
    check_directed_writes();
    check_bypass();
    check_random(32);
    check_coverage_summary();

    $display("tb_core_regfile PASS");
    $finish;
  end
endmodule
