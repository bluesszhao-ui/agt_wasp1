`timescale 1ns/1ps

module tb_core_wb;
  import core_types_pkg::*;

  logic         wb_valid;     // Testbench drive for writeback-stage valid.
  logic [4:0]   rd;           // Testbench drive for destination register.
  logic         rd_write;     // Testbench drive for decoded rd write intent.
  core_wb_sel_e wb_sel;       // Testbench drive for writeback source selector.
  logic         trap;         // Testbench drive for trap suppression.
  logic         fault;        // Testbench drive for late fault suppression.
  logic [31:0]  alu_result;   // Testbench ALU source value.
  logic [31:0]  load_data;    // Testbench load source value.
  logic [31:0]  csr_rdata;    // Testbench CSR source value.
  logic [31:0]  pc_plus4;     // Testbench PC+4 source value.
  logic [31:0]  imm_u;        // Testbench immediate source value.
  logic         rf_we;        // DUT final register-file write enable.
  logic [4:0]   rf_waddr;     // DUT final register-file write address.
  logic [31:0]  rf_wdata;     // DUT final register-file write data.

  integer pass_count;         // Total passing checks.
  integer source_count;       // Directed checks over each writeback source.
  integer suppress_count;     // Directed checks over write suppression causes.
  integer x0_count;           // Directed x0 suppression checks.
  integer default_count;      // Illegal selector default-path checks.
  integer random_count;       // Deterministic random checks.
  integer i;                  // Random loop index.

  core_wb dut (
    .wb_valid_i(wb_valid),
    .rd_i(rd),
    .rd_write_i(rd_write),
    .wb_sel_i(wb_sel),
    .trap_i(trap),
    .fault_i(fault),
    .alu_result_i(alu_result),
    .load_data_i(load_data),
    .csr_rdata_i(csr_rdata),
    .pc_plus4_i(pc_plus4),
    .imm_u_i(imm_u),
    .rf_we_o(rf_we),
    .rf_waddr_o(rf_waddr),
    .rf_wdata_o(rf_wdata)
  );

  // Reference model mirrors the architectural contract: select data first, then
  // independently qualify whether the selected value is allowed to update rd.
  task automatic ref_outputs(
    input  logic                         ref_valid,
    input  logic [4:0]                   ref_rd,
    input  logic                         ref_rd_write,
    input  core_wb_sel_e                 ref_sel,
    input  logic                         ref_trap,
    input  logic                         ref_fault,
    input  logic [31:0]                  ref_alu,
    input  logic [31:0]                  ref_load,
    input  logic [31:0]                  ref_csr,
    input  logic [31:0]                  ref_pc4,
    input  logic [31:0]                  ref_imm,
    output logic                         exp_we,
    output logic [4:0]                   exp_waddr,
    output logic [31:0]                  exp_wdata
  );
    exp_we = ref_valid && ref_rd_write && (ref_rd != 5'd0) &&
             !ref_trap && !ref_fault;
    exp_waddr = ref_rd;

    unique case (ref_sel)
      CORE_WB_LOAD: exp_wdata = ref_load;
      CORE_WB_CSR:  exp_wdata = ref_csr;
      CORE_WB_PC4:  exp_wdata = ref_pc4;
      CORE_WB_IMM:  exp_wdata = ref_imm;
      default:      exp_wdata = ref_alu;
    endcase
  endtask

  // Drive one scenario, wait for combinational settle, and compare with the
  // local reference model.
  task automatic run_case(
    input string                        name,
    input logic                         t_valid,
    input logic [4:0]                   t_rd,
    input logic                         t_rd_write,
    input core_wb_sel_e                 t_sel,
    input logic                         t_trap,
    input logic                         t_fault
  );
    logic        exp_we;
    logic [4:0]  exp_waddr;
    logic [31:0] exp_wdata;
    begin
      wb_valid = t_valid;
      rd = t_rd;
      rd_write = t_rd_write;
      wb_sel = t_sel;
      trap = t_trap;
      fault = t_fault;
      #1;

      ref_outputs(wb_valid, rd, rd_write, wb_sel, trap, fault,
                  alu_result, load_data, csr_rdata, pc_plus4, imm_u,
                  exp_we, exp_waddr, exp_wdata);

      if ((rf_we !== exp_we) || (rf_waddr !== exp_waddr) ||
          (rf_wdata !== exp_wdata)) begin
        $fatal(1, "%s failed: got we=%0b addr=%0d data=%08x exp we=%0b addr=%0d data=%08x",
               name, rf_we, rf_waddr, rf_wdata, exp_we, exp_waddr, exp_wdata);
      end

      pass_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    source_count = 0;
    suppress_count = 0;
    x0_count = 0;
    default_count = 0;
    random_count = 0;

    wb_valid = 1'b0;
    rd = 5'd0;
    rd_write = 1'b0;
    wb_sel = CORE_WB_ALU;
    trap = 1'b0;
    fault = 1'b0;
    alu_result = 32'h1111_0001;
    load_data = 32'h2222_0002;
    csr_rdata = 32'h3333_0003;
    pc_plus4 = 32'h4444_0004;
    imm_u = 32'h5555_0005;
    #1;

    run_case("alu source", 1'b1, 5'd1, 1'b1, CORE_WB_ALU, 1'b0, 1'b0);
    source_count++;
    run_case("load source", 1'b1, 5'd2, 1'b1, CORE_WB_LOAD, 1'b0, 1'b0);
    source_count++;
    run_case("csr source", 1'b1, 5'd3, 1'b1, CORE_WB_CSR, 1'b0, 1'b0);
    source_count++;
    run_case("pc4 source", 1'b1, 5'd4, 1'b1, CORE_WB_PC4, 1'b0, 1'b0);
    source_count++;
    run_case("imm source", 1'b1, 5'd5, 1'b1, CORE_WB_IMM, 1'b0, 1'b0);
    source_count++;

    run_case("invalid suppress", 1'b0, 5'd6, 1'b1, CORE_WB_ALU, 1'b0, 1'b0);
    suppress_count++;
    run_case("no rd write suppress", 1'b1, 5'd7, 1'b0, CORE_WB_ALU, 1'b0, 1'b0);
    suppress_count++;
    run_case("trap suppress", 1'b1, 5'd8, 1'b1, CORE_WB_ALU, 1'b1, 1'b0);
    suppress_count++;
    run_case("fault suppress", 1'b1, 5'd9, 1'b1, CORE_WB_ALU, 1'b0, 1'b1);
    suppress_count++;

    run_case("x0 suppress", 1'b1, 5'd0, 1'b1, CORE_WB_ALU, 1'b0, 1'b0);
    x0_count++;

    run_case("default source", 1'b1, 5'd10, 1'b1, core_wb_sel_e'(3'd7), 1'b0, 1'b0);
    default_count++;

    void'($urandom(32'hA2A0_0009));
    for (i = 0; i < 200; i++) begin
      alu_result = $urandom();
      load_data = $urandom();
      csr_rdata = $urandom();
      pc_plus4 = $urandom();
      imm_u = $urandom();
      run_case("random", logic'($urandom_range(0, 1)),
               5'($urandom_range(0, 31)),
               logic'($urandom_range(0, 1)),
               core_wb_sel_e'($urandom_range(0, 7)),
               logic'($urandom_range(0, 1)),
               logic'($urandom_range(0, 1)));
      random_count++;
    end

    if (source_count < 5 || suppress_count < 4 || x0_count < 1 ||
        default_count < 1 || random_count < 200) begin
      $fatal(1, "coverage goal missed");
    end

    $display("tb_core_wb coverage: pass_count=%0d source=%0d suppress=%0d x0=%0d default=%0d random=%0d",
             pass_count, source_count, suppress_count, x0_count,
             default_count, random_count);
    $display("tb_core_wb PASS");
    $finish;
  end
endmodule
