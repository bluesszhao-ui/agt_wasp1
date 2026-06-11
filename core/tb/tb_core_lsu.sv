`timescale 1ns/1ps

// Self-checking testbench for core_lsu.
//
// Reference functions calculate expected store strobes, lane-shifted write
// data, load extension, and misalignment behavior for directed and random
// accesses.
module tb_core_lsu;
  import core_types_pkg::*;

  logic [31:0] base;       // Base address stimulus.
  logic [31:0] imm;        // Immediate/address offset stimulus.
  logic [31:0] store_data; // Raw store data stimulus.
  core_lsu_size_e size;    // Access size stimulus.
  logic unsigned_load;     // Unsigned-load stimulus.
  logic load;              // Load qualifier stimulus.
  logic store;             // Store qualifier stimulus.
  logic [31:0] rsp_rdata;  // Memory response data stimulus.
  logic rsp_err;           // Memory response error stimulus.
  logic req_valid;         // DUT request-valid output.
  logic [31:0] req_addr;   // DUT effective address output.
  logic req_write;         // DUT write qualifier output.
  logic [1:0] req_size;    // DUT memory size output.
  logic [31:0] req_wdata;  // DUT lane-shifted write data.
  logic [3:0] req_wstrb;   // DUT byte strobes.
  logic [31:0] load_data;  // DUT formatted load data.
  logic misaligned;        // DUT misalignment indicator.
  logic fault;             // DUT combined fault indicator.

  int unsigned pass_count;     // Number of successful checks.
  int unsigned load_count;     // Directed load case counter.
  int unsigned store_count;    // Directed store case counter.
  int unsigned misalign_count; // Misalignment coverage counter.
  int unsigned sign_count;     // Sign/zero extension coverage counter.
  int unsigned random_count;   // Deterministic random check counter.
  int unsigned error_count;    // Response-error coverage counter.

  core_lsu u_core_lsu (
    .base_i(base),
    .imm_i(imm),
    .store_data_i(store_data),
    .size_i(size),
    .unsigned_i(unsigned_load),
    .load_i(load),
    .store_i(store),
    .rsp_rdata_i(rsp_rdata),
    .rsp_err_i(rsp_err),
    .req_valid_o(req_valid),
    .req_addr_o(req_addr),
    .req_write_o(req_write),
    .req_size_o(req_size),
    .req_wdata_o(req_wdata),
    .req_wstrb_o(req_wstrb),
    .load_data_o(load_data),
    .misaligned_o(misaligned),
    .fault_o(fault)
  );

  // Reference store byte-enable generation.
  function automatic logic [3:0] ref_wstrb(
    input core_lsu_size_e ref_size,
    input logic [1:0] off
  );
    begin
      unique case (ref_size)
        CORE_LSU_BYTE: ref_wstrb = 4'b0001 << off;
        CORE_LSU_HALF: ref_wstrb = off[1] ? 4'b1100 : 4'b0011;
        default:       ref_wstrb = 4'b1111;
      endcase
    end
  endfunction

  // Reference store-data lane shifter.
  function automatic logic [31:0] ref_wdata(
    input core_lsu_size_e ref_size,
    input logic [1:0] off,
    input logic [31:0] data
  );
    begin
      unique case (ref_size)
        CORE_LSU_BYTE: ref_wdata = {24'h000000, data[7:0]} << (off * 8);
        CORE_LSU_HALF: ref_wdata = off[1] ? {data[15:0], 16'h0000} :
                                            {16'h0000, data[15:0]};
        default:       ref_wdata = data;
      endcase
    end
  endfunction

  // Reference load byte/half selection and sign/zero extension.
  function automatic logic [31:0] ref_load(
    input core_lsu_size_e ref_size,
    input logic ref_unsigned,
    input logic [1:0] off,
    input logic [31:0] data
  );
    logic [7:0] byte_data;
    logic [15:0] half_data;
    begin
      unique case (off)
        2'd0: byte_data = data[7:0];
        2'd1: byte_data = data[15:8];
        2'd2: byte_data = data[23:16];
        default: byte_data = data[31:24];
      endcase
      half_data = off[1] ? data[31:16] : data[15:0];

      unique case (ref_size)
        CORE_LSU_BYTE: ref_load = ref_unsigned ? {24'h000000, byte_data} :
                                                 {{24{byte_data[7]}}, byte_data};
        CORE_LSU_HALF: ref_load = ref_unsigned ? {16'h0000, half_data} :
                                                 {{16{half_data[15]}}, half_data};
        default:       ref_load = data;
      endcase
    end
  endfunction

  function automatic logic ref_misaligned(
    input core_lsu_size_e ref_size,
    input logic [1:0] off
  );
    begin
      unique case (ref_size)
        CORE_LSU_HALF: ref_misaligned = off[0];
        CORE_LSU_WORD: ref_misaligned = |off;
        default:       ref_misaligned = 1'b0;
      endcase
    end
  endfunction

  task automatic drive_idle;
    begin
      base = 32'h0000_0000;
      imm = 32'h0000_0000;
      store_data = 32'h0000_0000;
      size = CORE_LSU_WORD;
      unsigned_load = 1'b0;
      load = 1'b0;
      store = 1'b0;
      rsp_rdata = 32'h0000_0000;
      rsp_err = 1'b0;
    end
  endtask

  task automatic check_common(
    input logic exp_req_valid,
    input logic [31:0] exp_addr,
    input logic exp_write,
    input logic [1:0] exp_size,
    input logic [31:0] exp_wdata,
    input logic [3:0] exp_wstrb,
    input logic [31:0] exp_load,
    input logic exp_misaligned,
    input logic exp_fault,
    input string label
  );
    begin
      #1ns;
      if (req_valid !== exp_req_valid || req_addr !== exp_addr ||
          req_write !== exp_write || req_size !== exp_size ||
          req_wdata !== exp_wdata || req_wstrb !== exp_wstrb ||
          load_data !== exp_load || misaligned !== exp_misaligned ||
          fault !== exp_fault) begin
        $error("%s mismatch valid=%0b/%0b addr=0x%08h/0x%08h write=%0b/%0b size=%0d/%0d wdata=0x%08h/0x%08h wstrb=0x%1h/0x%1h load=0x%08h/0x%08h mis=%0b/%0b fault=%0b/%0b",
               label, req_valid, exp_req_valid, req_addr, exp_addr,
               req_write, exp_write, req_size, exp_size, req_wdata, exp_wdata,
               req_wstrb, exp_wstrb, load_data, exp_load, misaligned,
               exp_misaligned, fault, exp_fault);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic check_load_case(
    input logic [31:0] addr,
    input core_lsu_size_e check_size,
    input logic check_unsigned,
    input logic [31:0] data,
    input string label
  );
    logic exp_mis;
    begin
      base = {addr[31:2], 2'b00};
      imm = {30'h00000000, addr[1:0]};
      store_data = 32'h0000_0000;
      size = check_size;
      unsigned_load = check_unsigned;
      load = 1'b1;
      store = 1'b0;
      rsp_rdata = data;
      rsp_err = 1'b0;
      exp_mis = ref_misaligned(check_size, addr[1:0]);
      check_common(!exp_mis, addr, 1'b0, check_size, 32'h0000_0000, 4'b0000,
                   ref_load(check_size, check_unsigned, addr[1:0], data),
                   exp_mis, exp_mis, label);
      load_count++;
      if (check_size != CORE_LSU_WORD) begin
        sign_count++;
      end
      if (exp_mis) begin
        misalign_count++;
      end
    end
  endtask

  task automatic check_store_case(
    input logic [31:0] addr,
    input core_lsu_size_e check_size,
    input logic [31:0] data,
    input string label
  );
    logic exp_mis;
    logic [31:0] exp_wdata;
    logic [3:0] exp_wstrb;
    begin
      base = {addr[31:2], 2'b00};
      imm = {30'h00000000, addr[1:0]};
      store_data = data;
      size = check_size;
      unsigned_load = 1'b0;
      load = 1'b0;
      store = 1'b1;
      rsp_rdata = 32'h0000_0000;
      rsp_err = 1'b0;
      exp_mis = ref_misaligned(check_size, addr[1:0]);
      exp_wdata = exp_mis ? 32'h0000_0000 : ref_wdata(check_size, addr[1:0], data);
      exp_wstrb = exp_mis ? 4'b0000 : ref_wstrb(check_size, addr[1:0]);
      check_common(!exp_mis, addr, 1'b1, check_size, exp_wdata, exp_wstrb,
                   32'h0000_0000, exp_mis, exp_mis, label);
      store_count++;
      if (exp_mis) begin
        misalign_count++;
      end
    end
  endtask

  task automatic check_error;
    begin
      base = 32'h0000_4000;
      imm = 32'h0000_0000;
      store_data = 32'h0000_0000;
      size = CORE_LSU_WORD;
      unsigned_load = 1'b0;
      load = 1'b1;
      store = 1'b0;
      rsp_rdata = 32'hCAFE_BABE;
      rsp_err = 1'b1;
      check_common(1'b1, 32'h0000_4000, 1'b0, CORE_LSU_WORD, 32'h0000_0000,
                   4'b0000, 32'hCAFE_BABE, 1'b0, 1'b1, "response error");
      error_count++;
    end
  endtask

  task automatic check_random(input int unsigned count);
    logic [31:0] rand_addr;
    logic [31:0] rand_data;
    core_lsu_size_e rand_size;
    logic rand_store;
    logic rand_unsigned;
    logic exp_mis;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        rand_addr = $urandom();
        rand_data = $urandom();
        rand_size = core_lsu_size_e'($urandom_range(0, 2));
        rand_store = $urandom_range(0, 1) != 0;
        rand_unsigned = $urandom_range(0, 1) != 0;

        base = {rand_addr[31:2], 2'b00};
        imm = {30'h00000000, rand_addr[1:0]};
        store_data = rand_data;
        size = rand_size;
        unsigned_load = rand_unsigned;
        load = !rand_store;
        store = rand_store;
        rsp_rdata = rand_data;
        rsp_err = 1'b0;
        exp_mis = ref_misaligned(rand_size, rand_addr[1:0]);
        check_common(!exp_mis, rand_addr, rand_store, rand_size,
                     (rand_store && !exp_mis) ? ref_wdata(rand_size, rand_addr[1:0], rand_data) : 32'h0000_0000,
                     (rand_store && !exp_mis) ? ref_wstrb(rand_size, rand_addr[1:0]) : 4'b0000,
                     ref_load(rand_size, rand_unsigned, rand_addr[1:0], rand_data),
                     exp_mis, exp_mis, "random lsu");
        random_count++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (load_count < 10 || store_count < 9 || misalign_count < 4 ||
          sign_count < 6 || random_count < 100 || error_count < 1) begin
        $error("coverage miss: load=%0d store=%0d misalign=%0d sign=%0d random=%0d error=%0d",
               load_count, store_count, misalign_count, sign_count,
               random_count, error_count);
        $fatal(1);
      end
      $display("tb_core_lsu coverage: pass_count=%0d load=%0d store=%0d misalign=%0d sign=%0d random=%0d error=%0d",
               pass_count, load_count, store_count, misalign_count, sign_count,
               random_count, error_count);
    end
  endtask

  initial begin
    void'($urandom(32'h15A0_0006));
    pass_count = 0;
    load_count = 0;
    store_count = 0;
    misalign_count = 0;
    sign_count = 0;
    random_count = 0;
    error_count = 0;

    drive_idle();
    check_common(1'b0, 32'h0000_0000, 1'b0, CORE_LSU_WORD, 32'h0000_0000,
                 4'b0000, 32'h0000_0000, 1'b0, 1'b0, "idle");

    check_load_case(32'h0000_1000, CORE_LSU_BYTE, 1'b0, 32'h4433_2280, "lb off0 sign");
    check_load_case(32'h0000_1001, CORE_LSU_BYTE, 1'b1, 32'h4433_8122, "lbu off1");
    check_load_case(32'h0000_1002, CORE_LSU_BYTE, 1'b0, 32'h4480_2211, "lb off2 sign");
    check_load_case(32'h0000_1003, CORE_LSU_BYTE, 1'b1, 32'h8044_2211, "lbu off3");
    check_load_case(32'h0000_1000, CORE_LSU_HALF, 1'b0, 32'h1234_8001, "lh low sign");
    check_load_case(32'h0000_1002, CORE_LSU_HALF, 1'b1, 32'h8001_1234, "lhu high");
    check_load_case(32'h0000_1000, CORE_LSU_WORD, 1'b0, 32'hDEAD_BEEF, "lw");
    check_load_case(32'h0000_1001, CORE_LSU_HALF, 1'b0, 32'hAAAA_5555, "lh misalign");
    check_load_case(32'h0000_1002, CORE_LSU_WORD, 1'b0, 32'hAAAA_5555, "lw misalign");
    check_load_case(32'h0000_1003, CORE_LSU_WORD, 1'b0, 32'hAAAA_5555, "lw misalign off3");

    check_store_case(32'h0000_2000, CORE_LSU_BYTE, 32'hAAAA_00DD, "sb off0");
    check_store_case(32'h0000_2001, CORE_LSU_BYTE, 32'hAAAA_00DD, "sb off1");
    check_store_case(32'h0000_2002, CORE_LSU_BYTE, 32'hAAAA_00DD, "sb off2");
    check_store_case(32'h0000_2003, CORE_LSU_BYTE, 32'hAAAA_00DD, "sb off3");
    check_store_case(32'h0000_2000, CORE_LSU_HALF, 32'hAAAA_BEEF, "sh low");
    check_store_case(32'h0000_2002, CORE_LSU_HALF, 32'hAAAA_BEEF, "sh high");
    check_store_case(32'h0000_2000, CORE_LSU_WORD, 32'hCAFE_BABE, "sw");
    check_store_case(32'h0000_2001, CORE_LSU_HALF, 32'hAAAA_BEEF, "sh misalign");
    check_store_case(32'h0000_2002, CORE_LSU_WORD, 32'hCAFE_BABE, "sw misalign");

    check_error();
    check_random(100);
    check_coverage_summary();

    $display("tb_core_lsu PASS");
    $finish;
  end
endmodule
