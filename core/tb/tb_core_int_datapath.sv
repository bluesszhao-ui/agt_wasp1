`timescale 1ns/1ps

module tb_core_int_datapath;
  logic        clk;            // Testbench clock.
  logic        rst_n;          // Active-low reset.
  logic [31:0] boot_pc;        // Reset PC for the integrated datapath.
  logic        if_req_valid;   // DUT fetch request valid.
  logic [31:0] if_req_pc;      // DUT fetch request PC.
  logic        if_rsp_valid;   // Testbench instruction response valid.
  logic        if_rsp_ready;   // DUT instruction response ready.
  logic [31:0] if_rsp_instr;   // Testbench instruction response instruction.
  logic        if_rsp_fault;   // Testbench instruction fetch fault.
  logic        commit_valid;   // DUT writeback valid.
  logic [4:0]  commit_rd;      // DUT writeback register.
  logic [31:0] commit_data;    // DUT writeback data.
  logic        ex_valid;       // DUT execute slot valid.
  logic [31:0] ex_pc;          // DUT execute slot PC.
  logic [31:0] ex_instr;       // DUT execute slot instruction.
  logic        illegal;        // DUT illegal instruction flag.
  logic        unsupported;    // DUT unsupported instruction class flag.

  integer pass_count;          // Total passing checks.
  integer commit_count;        // Number of observed commits.
  integer alu_i_count;         // Immediate ALU coverage.
  integer alu_r_count;         // Register ALU coverage.
  integer upper_count;         // LUI/AUIPC coverage.
  integer link_count;          // JAL/JALR link write coverage.
  integer suppress_count;      // x0/illegal/unsupported suppression coverage.
  integer pc_count;            // Fetch PC stepping coverage.

  core_int_datapath dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .boot_pc_i(boot_pc),
    .if_req_valid_o(if_req_valid),
    .if_req_pc_o(if_req_pc),
    .if_rsp_valid_i(if_rsp_valid),
    .if_rsp_ready_o(if_rsp_ready),
    .if_rsp_instr_i(if_rsp_instr),
    .if_rsp_fault_i(if_rsp_fault),
    .commit_valid_o(commit_valid),
    .commit_rd_o(commit_rd),
    .commit_data_o(commit_data),
    .ex_valid_o(ex_valid),
    .ex_pc_o(ex_pc),
    .ex_instr_o(ex_instr),
    .illegal_o(illegal),
    .unsupported_o(unsupported)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  function automatic logic [31:0] enc_r(
    input logic [6:0] funct7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd
  );
    enc_r = {funct7, rs2, rs1, funct3, rd, 7'b0110011};
  endfunction

  function automatic logic [31:0] enc_i(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3,
    input logic [4:0]  rd
  );
    enc_i = {imm, rs1, funct3, rd, 7'b0010011};
  endfunction

  function automatic logic [31:0] enc_u(
    input logic [19:0] imm20,
    input logic [4:0]  rd,
    input logic [6:0]  opcode
  );
    enc_u = {imm20, rd, opcode};
  endfunction

  function automatic logic [31:0] enc_jal(
    input logic [20:0] imm,
    input logic [4:0]  rd
  );
    enc_jal = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  function automatic logic [31:0] enc_load(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3,
    input logic [4:0]  rd
  );
    enc_load = {imm, rs1, funct3, rd, 7'b0000011};
  endfunction

  // Drive one fetch response before the next active edge. This testbench keeps
  // the frontend always responsive, matching the current unstalled datapath.
  task automatic drive_instr(input logic [31:0] instr);
    begin
      @(negedge clk);
      if_rsp_valid = 1'b1;
      if_rsp_instr = instr;
      if_rsp_fault = 1'b0;
      #1;
      if (!if_req_valid || !if_rsp_ready) begin
        $fatal(1, "fetch handshake not ready for instr %08x", instr);
      end
      @(posedge clk);
      #1;
      if (if_req_pc !== boot_pc + (pc_count * 32'd4) + 32'd4) begin
        $fatal(1, "fetch PC step mismatch got=%08x", if_req_pc);
      end
      pc_count++;
    end
  endtask

  task automatic expect_commit(
    input string       name,
    input logic [4:0]  exp_rd,
    input logic [31:0] exp_data
  );
    begin
      #1;
      if (!commit_valid || (commit_rd !== exp_rd) || (commit_data !== exp_data)) begin
        $fatal(1, "%s commit mismatch got valid=%0b rd=%0d data=%08x exp rd=%0d data=%08x",
               name, commit_valid, commit_rd, commit_data, exp_rd, exp_data);
      end
      pass_count++;
      commit_count++;
    end
  endtask

  task automatic expect_no_commit(input string name);
    begin
      #1;
      if (commit_valid) begin
        $fatal(1, "%s unexpected commit rd=%0d data=%08x", name, commit_rd, commit_data);
      end
      pass_count++;
      suppress_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    commit_count = 0;
    alu_i_count = 0;
    alu_r_count = 0;
    upper_count = 0;
    link_count = 0;
    suppress_count = 0;
    pc_count = 0;

    boot_pc = 32'h0001_0000;
    rst_n = 1'b0;
    if_rsp_valid = 1'b0;
    if_rsp_instr = 32'h0000_0013;
    if_rsp_fault = 1'b0;

    repeat (2) @(posedge clk);
    #1;
    if (if_req_pc !== boot_pc || ex_valid || commit_valid) begin
      $fatal(1, "reset state mismatch");
    end
    rst_n = 1'b1;

    // Fill the two-stage pipe. The first fetched ADDI reaches execute after
    // two accepted responses.
    drive_instr(enc_i(12'd5, 5'd0, 3'b000, 5'd1));  // addi x1,x0,5
    drive_instr(enc_i(12'd3, 5'd1, 3'b000, 5'd2));  // addi x2,x1,3
    expect_commit("addi x1", 5'd1, 32'd5);
    alu_i_count++;

    drive_instr(enc_r(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3)); // add x3,x1,x2
    expect_commit("addi x2", 5'd2, 32'd8);
    alu_i_count++;

    drive_instr(enc_r(7'b0100000, 5'd1, 5'd3, 3'b000, 5'd4)); // sub x4,x3,x1
    expect_commit("add x3", 5'd3, 32'd13);
    alu_r_count++;

    drive_instr(enc_i(12'd0, 5'd4, 3'b110, 5'd5)); // ori x5,x4,0
    expect_commit("sub x4", 5'd4, 32'd8);
    alu_r_count++;

    drive_instr(enc_u(20'h12345, 5'd6, 7'b0110111)); // lui x6,0x12345
    expect_commit("ori x5", 5'd5, 32'd8);
    alu_i_count++;

    drive_instr(enc_u(20'h00002, 5'd7, 7'b0010111)); // auipc x7,0x2000
    expect_commit("lui x6", 5'd6, 32'h1234_5000);
    upper_count++;

    drive_instr(enc_jal(21'd8, 5'd8)); // jal x8,+8, link only in this milestone
    expect_commit("auipc x7", 5'd7, 32'h0001_2018);
    upper_count++;

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd0)); // addi x0,x0,1, suppressed
    expect_commit("jal x8", 5'd8, 32'h0001_0020);
    link_count++;

    drive_instr(32'hffff_ffff); // illegal instruction suppresses writeback
    expect_no_commit("x0 suppress");

    drive_instr(enc_load(12'd0, 5'd0, 3'b010, 5'd9)); // load unsupported for now
    expect_no_commit("illegal suppress");

    drive_instr(32'h0000_0013); // nop drain
    expect_no_commit("unsupported load suppress");

    expect_no_commit("nop x0 drain");

    if (commit_count < 8 || alu_i_count < 3 || alu_r_count < 2 ||
        upper_count < 2 || link_count < 1 || suppress_count < 4 ||
        pc_count < 10) begin
      $fatal(1, "coverage goal missed");
    end

    $display("tb_core_int_datapath coverage: pass_count=%0d commit=%0d alu_i=%0d alu_r=%0d upper=%0d link=%0d suppress=%0d pc=%0d",
             pass_count, commit_count, alu_i_count, alu_r_count,
             upper_count, link_count, suppress_count, pc_count);
    $display("tb_core_int_datapath PASS");
    $finish;
  end
endmodule
