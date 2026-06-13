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
  logic        dmem_req_valid; // DUT data-memory request valid.
  logic [31:0] dmem_req_addr;  // DUT data-memory request address.
  logic        dmem_req_write; // DUT data-memory write qualifier.
  logic [1:0]  dmem_req_size;  // DUT data-memory access size.
  logic [31:0] dmem_req_wdata; // DUT data-memory write data.
  logic [3:0]  dmem_req_wstrb; // DUT data-memory byte strobes.
  logic [31:0] dmem_rsp_rdata; // Testbench data-memory read data.
  logic        dmem_rsp_err;   // Testbench data-memory response error.
  logic        commit_valid;   // DUT writeback valid.
  logic [4:0]  commit_rd;      // DUT writeback register.
  logic [31:0] commit_data;    // DUT writeback data.
  logic        ex_valid;       // DUT execute slot valid.
  logic [31:0] ex_pc;          // DUT execute slot PC.
  logic [31:0] ex_instr;       // DUT execute slot instruction.
  logic        illegal;        // DUT illegal instruction flag.
  logic        lsu_fault;      // DUT load/store fault flag.
  logic        unsupported;    // DUT unsupported instruction class flag.

  integer pass_count;          // Total passing checks.
  integer commit_count;        // Number of observed commits.
  integer alu_i_count;         // Immediate ALU coverage.
  integer alu_r_count;         // Register ALU coverage.
  integer upper_count;         // LUI/AUIPC coverage.
  integer link_count;          // JAL/JALR link write coverage.
  integer branch_count;        // Conditional branch coverage.
  integer redirect_count;      // Taken redirect and flush coverage.
  integer load_count;          // Load writeback coverage.
  integer store_count;         // Store request coverage.
  integer lsu_fault_count;     // LSU misalignment/error coverage.
  integer suppress_count;      // x0/illegal/unsupported suppression coverage.
  integer pc_count;            // Fetch PC stepping coverage.
  logic [31:0] exp_fetch_pc;   // Scoreboard expected fetch request PC.

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
    .dmem_req_valid_o(dmem_req_valid),
    .dmem_req_addr_o(dmem_req_addr),
    .dmem_req_write_o(dmem_req_write),
    .dmem_req_size_o(dmem_req_size),
    .dmem_req_wdata_o(dmem_req_wdata),
    .dmem_req_wstrb_o(dmem_req_wstrb),
    .dmem_rsp_rdata_i(dmem_rsp_rdata),
    .dmem_rsp_err_i(dmem_rsp_err),
    .commit_valid_o(commit_valid),
    .commit_rd_o(commit_rd),
    .commit_data_o(commit_data),
    .ex_valid_o(ex_valid),
    .ex_pc_o(ex_pc),
    .ex_instr_o(ex_instr),
    .illegal_o(illegal),
    .lsu_fault_o(lsu_fault),
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

  function automatic logic [31:0] enc_jalr(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [4:0]  rd
  );
    enc_jalr = {imm, rs1, 3'b000, rd, 7'b1100111};
  endfunction

  function automatic logic [31:0] enc_branch(
    input logic [12:0] imm,
    input logic [4:0]  rs2,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3
  );
    enc_branch = {imm[12], imm[10:5], rs2, rs1, funct3,
                  imm[4:1], imm[11], 7'b1100011};
  endfunction

  function automatic logic [31:0] enc_load(
    input logic [11:0] imm,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3,
    input logic [4:0]  rd
  );
    enc_load = {imm, rs1, funct3, rd, 7'b0000011};
  endfunction

  function automatic logic [31:0] enc_store(
    input logic [11:0] imm,
    input logic [4:0]  rs2,
    input logic [4:0]  rs1,
    input logic [2:0]  funct3
  );
    enc_store = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
  endfunction

  // Combinational single-cycle data-memory model for this staged datapath.
  // Later cache/AHB integration will replace this with a stalled handshake.
  always_comb begin
    dmem_rsp_err = 1'b0;
    unique case (dmem_req_addr)
      32'h0000_0300: dmem_rsp_rdata = 32'h89AB_CDEF;
      32'h0000_0301: dmem_rsp_rdata = 32'h4433_8022;
      32'h0000_0302: dmem_rsp_rdata = 32'h0080_2211;
      32'h0000_03F0: begin
        dmem_rsp_rdata = 32'hBAD0_0BAD;
        dmem_rsp_err = dmem_req_valid && !dmem_req_write;
      end
      default:       dmem_rsp_rdata = 32'h0000_0000;
    endcase
  end

  // Drive one fetch response before the next active edge and check the expected
  // request PC after the edge. Redirect tests override exp_next_pc.
  task automatic drive_instr_expect_next(
    input logic [31:0] instr,
    input logic [31:0] exp_next_pc
  );
    begin
      @(negedge clk);
      if (if_req_pc !== exp_fetch_pc) begin
        $fatal(1, "fetch PC before drive mismatch got=%08x exp=%08x",
               if_req_pc, exp_fetch_pc);
      end
      if_rsp_valid = 1'b1;
      if_rsp_instr = instr;
      if_rsp_fault = 1'b0;
      #1;
      if (!if_req_valid || !if_rsp_ready) begin
        $fatal(1, "fetch handshake not ready for instr %08x", instr);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_next_pc;
      if (if_req_pc !== exp_fetch_pc) begin
        $fatal(1, "fetch PC after drive mismatch got=%08x exp=%08x",
               if_req_pc, exp_fetch_pc);
      end
      pc_count++;
    end
  endtask

  task automatic drive_instr(input logic [31:0] instr);
    begin
      drive_instr_expect_next(instr, exp_fetch_pc + 32'd4);
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

  task automatic expect_store_req(
    input string       name,
    input logic [31:0] exp_addr,
    input logic [1:0]  exp_size,
    input logic [31:0] exp_wdata,
    input logic [3:0]  exp_wstrb
  );
    begin
      #1;
      if (!dmem_req_valid || !dmem_req_write || (dmem_req_addr !== exp_addr) ||
          (dmem_req_size !== exp_size) || (dmem_req_wdata !== exp_wdata) ||
          (dmem_req_wstrb !== exp_wstrb)) begin
        $fatal(1, "%s store mismatch valid=%0b write=%0b addr=%08x size=%0d wdata=%08x wstrb=%b",
               name, dmem_req_valid, dmem_req_write, dmem_req_addr,
               dmem_req_size, dmem_req_wdata, dmem_req_wstrb);
      end
      store_count++;
    end
  endtask

  task automatic expect_lsu_fault(
    input string name,
    input logic  exp_req_valid
  );
    begin
      #1;
      if (commit_valid || (dmem_req_valid !== exp_req_valid) || !lsu_fault) begin
        $fatal(1, "%s lsu fault mismatch commit=%0b req=%0b fault=%0b",
               name, commit_valid, dmem_req_valid, lsu_fault);
      end
      pass_count++;
      suppress_count++;
      lsu_fault_count++;
    end
  endtask

  task automatic expect_redirect_flush(
    input string       name,
    input logic [31:0] exp_target
  );
    begin
      #1;
      if (if_rsp_ready) begin
        $fatal(1, "%s redirect did not block fetch response acceptance", name);
      end
      @(posedge clk);
      #1;
      exp_fetch_pc = exp_target;
      if (if_req_pc !== exp_fetch_pc || ex_valid) begin
        $fatal(1, "%s redirect flush mismatch pc=%08x exp=%08x ex_valid=%0b",
               name, if_req_pc, exp_fetch_pc, ex_valid);
      end
      pass_count++;
      redirect_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    commit_count = 0;
    alu_i_count = 0;
    alu_r_count = 0;
    upper_count = 0;
    link_count = 0;
    branch_count = 0;
    redirect_count = 0;
    load_count = 0;
    store_count = 0;
    lsu_fault_count = 0;
    suppress_count = 0;
    pc_count = 0;

    boot_pc = 32'h0001_0000;
    exp_fetch_pc = boot_pc;
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

    drive_instr(enc_jal(21'd8, 5'd8)); // jal x8,+8
    expect_commit("auipc x7", 5'd7, 32'h0001_2018);
    upper_count++;

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd0)); // fall-through, flushed
    expect_commit("jal x8", 5'd8, 32'h0001_0020);
    link_count++;
    expect_redirect_flush("initial jal redirect", ex_pc + 32'd8);

    drive_instr(32'hffff_ffff); // illegal instruction suppresses writeback
    expect_no_commit("initial jal redirect bubble");

    drive_instr(32'h0000_0073); // ecall unsupported for now
    expect_no_commit("illegal suppress");

    drive_instr(32'h0000_0013); // nop drain
    expect_no_commit("unsupported ecall suppress");

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd0)); // addi x0,x0,1, suppressed
    expect_no_commit("nop x0 drain");

    drive_instr(enc_i(12'd9, 5'd0, 3'b000, 5'd10)); // addi x10,x0,9
    expect_no_commit("x0 suppress");

    drive_instr(enc_i(12'd9, 5'd0, 3'b000, 5'd11)); // addi x11,x0,9
    expect_commit("addi x10", 5'd10, 32'd9);
    alu_i_count++;

    drive_instr(enc_branch(13'd16, 5'd11, 5'd10, 3'b000)); // beq x10,x11,+16
    expect_commit("addi x11", 5'd11, 32'd9);
    alu_i_count++;

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd12)); // fall-through, flushed
    expect_no_commit("taken beq no write");
    branch_count++;
    expect_redirect_flush("beq redirect", ex_pc + 32'd16);

    drive_instr(enc_i(12'd7, 5'd0, 3'b000, 5'd12)); // branch target addi
    expect_no_commit("beq redirect bubble");

    drive_instr(enc_i(12'd2, 5'd12, 3'b000, 5'd13)); // addi x13,x12,2
    expect_commit("target addi x12", 5'd12, 32'd7);
    alu_i_count++;

    drive_instr(enc_jal(21'd12, 5'd14)); // jal x14,+12
    expect_commit("target addi x13", 5'd13, 32'd9);
    alu_i_count++;

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd15)); // fall-through, flushed
    expect_commit("jal x14 redirect link", 5'd14, ex_pc + 32'd4);
    link_count++;
    expect_redirect_flush("jal redirect", ex_pc + 32'd12);

    drive_instr(enc_jalr(12'h104, 5'd0, 5'd16)); // jalr x16,x0,0x104
    expect_no_commit("jal redirect bubble");

    drive_instr(enc_i(12'd1, 5'd0, 3'b000, 5'd17)); // fall-through, flushed
    expect_commit("jalr x16 redirect link", 5'd16, ex_pc + 32'd4);
    link_count++;
    expect_redirect_flush("jalr redirect", 32'h0000_0104);

    drive_instr(enc_i(12'd4, 5'd0, 3'b000, 5'd18)); // jalr target addi
    expect_no_commit("jalr redirect bubble");

    drive_instr(enc_branch(13'd8, 5'd18, 5'd17, 3'b000)); // beq x17,x18,+8 not taken
    expect_commit("jalr target addi x18", 5'd18, 32'd4);
    alu_i_count++;

    drive_instr(enc_i(12'd5, 5'd0, 3'b000, 5'd19)); // sequential after not-taken
    expect_no_commit("not-taken bne no write");
    branch_count++;

    drive_instr(enc_i(12'h300, 5'd0, 3'b000, 5'd20)); // addi x20,x0,0x300
    expect_commit("post branch addi x19", 5'd19, 32'd5);
    alu_i_count++;

    drive_instr(enc_load(12'd0, 5'd20, 3'b010, 5'd21)); // lw x21,0(x20)
    expect_commit("base addi x20", 5'd20, 32'h0000_0300);
    alu_i_count++;

    drive_instr(enc_load(12'd1, 5'd20, 3'b000, 5'd22)); // lb x22,1(x20)
    expect_commit("lw x21", 5'd21, 32'h89AB_CDEF);
    load_count++;

    drive_instr(enc_load(12'd2, 5'd20, 3'b100, 5'd23)); // lbu x23,2(x20)
    expect_commit("lb x22", 5'd22, 32'hFFFF_FF80);
    load_count++;

    drive_instr(enc_store(12'd4, 5'd21, 5'd20, 3'b010)); // sw x21,4(x20)
    expect_commit("lbu x23", 5'd23, 32'h0000_0080);
    load_count++;

    drive_instr(enc_store(12'd1, 5'd23, 5'd20, 3'b000)); // sb x23,1(x20)
    expect_store_req("sw x21", 32'h0000_0304, 2'd2, 32'h89AB_CDEF, 4'b1111);
    expect_no_commit("sw no commit");

    drive_instr(enc_load(12'd2, 5'd20, 3'b010, 5'd24)); // misaligned lw
    expect_store_req("sb x23", 32'h0000_0301, 2'd0, 32'h0000_8000, 4'b0010);
    expect_no_commit("sb no commit");

    drive_instr(enc_load(12'h0F0, 5'd20, 3'b010, 5'd25)); // memory error
    expect_lsu_fault("misaligned lw", 1'b0);

    drive_instr(32'h0000_0013); // drain memory error load
    expect_lsu_fault("memory error lw", 1'b1);

    if (commit_count < 8 || alu_i_count < 3 || alu_r_count < 2 ||
        upper_count < 2 || link_count < 3 || branch_count < 2 ||
        redirect_count < 3 || load_count < 3 || store_count < 2 ||
        lsu_fault_count < 2 || suppress_count < 12 || pc_count < 34) begin
      $fatal(1, "coverage goal missed");
    end

    $display("tb_core_int_datapath coverage: pass_count=%0d commit=%0d alu_i=%0d alu_r=%0d upper=%0d link=%0d branch=%0d redirect=%0d load=%0d store=%0d lsu_fault=%0d suppress=%0d pc=%0d",
             pass_count, commit_count, alu_i_count, alu_r_count,
             upper_count, link_count, branch_count, redirect_count,
             load_count, store_count, lsu_fault_count, suppress_count,
             pc_count);
    $display("tb_core_int_datapath PASS");
    $finish;
  end
endmodule
