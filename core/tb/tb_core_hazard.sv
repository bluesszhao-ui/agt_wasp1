`timescale 1ns/1ps

// Self-checking testbench for core_hazard.
//
// Directed tests cover x0 suppression, EX/WB forwarding, forwarding priority,
// and load-use stalls. Random tests compare the DUT against a local reference
// model for source/destination dependency behavior.
module tb_core_hazard;
  logic       id_valid;       // Decode valid stimulus.
  logic [4:0] id_rs1;         // Decode rs1 stimulus.
  logic       id_uses_rs1;    // Decode rs1-use stimulus.
  logic [4:0] id_rs2;         // Decode rs2 stimulus.
  logic       id_uses_rs2;    // Decode rs2-use stimulus.
  logic       ex_valid;       // Execute valid stimulus.
  logic [4:0] ex_rd;          // Execute rd stimulus.
  logic       ex_writes_rd;   // Execute rd-write stimulus.
  logic       ex_is_load;     // Execute load-result stimulus.
  logic       wb_valid;       // Writeback valid stimulus.
  logic [4:0] wb_rd;          // Writeback rd stimulus.
  logic       wb_writes_rd;   // Writeback rd-write stimulus.
  logic       rs1_forward_ex; // DUT rs1 EX-forward output.
  logic       rs1_forward_wb; // DUT rs1 WB-forward output.
  logic       rs2_forward_ex; // DUT rs2 EX-forward output.
  logic       rs2_forward_wb; // DUT rs2 WB-forward output.
  logic       load_use_stall; // DUT load-use stall output.
  logic       fetch_stall;    // DUT fetch stall output.
  logic       decode_stall;   // DUT decode stall output.
  logic       execute_bubble; // DUT execute bubble output.

  int unsigned pass_count;    // Number of successful checks.
  int unsigned ex_fwd_count;  // EX forwarding coverage counter.
  int unsigned wb_fwd_count;  // WB forwarding coverage counter.
  int unsigned stall_count;   // Load-use stall coverage counter.
  int unsigned x0_count;      // x0 suppression coverage counter.
  int unsigned priority_count;// EX-over-WB priority coverage counter.
  int unsigned random_count;  // Deterministic random coverage counter.

  core_hazard u_core_hazard (
    .id_valid_i(id_valid),
    .id_rs1_i(id_rs1),
    .id_uses_rs1_i(id_uses_rs1),
    .id_rs2_i(id_rs2),
    .id_uses_rs2_i(id_uses_rs2),
    .ex_valid_i(ex_valid),
    .ex_rd_i(ex_rd),
    .ex_writes_rd_i(ex_writes_rd),
    .ex_is_load_i(ex_is_load),
    .wb_valid_i(wb_valid),
    .wb_rd_i(wb_rd),
    .wb_writes_rd_i(wb_writes_rd),
    .rs1_forward_ex_o(rs1_forward_ex),
    .rs1_forward_wb_o(rs1_forward_wb),
    .rs2_forward_ex_o(rs2_forward_ex),
    .rs2_forward_wb_o(rs2_forward_wb),
    .load_use_stall_o(load_use_stall),
    .fetch_stall_o(fetch_stall),
    .decode_stall_o(decode_stall),
    .execute_bubble_o(execute_bubble)
  );

  // Reference model for one hazard decision.
  task automatic ref_outputs(
    output logic exp_rs1_ex,
    output logic exp_rs1_wb,
    output logic exp_rs2_ex,
    output logic exp_rs2_wb,
    output logic exp_stall
  );
    logic rs1_ex_match;
    logic rs2_ex_match;
    logic rs1_wb_match;
    logic rs2_wb_match;
    begin
      rs1_ex_match = id_valid && id_uses_rs1 && ex_valid && ex_writes_rd &&
                     (ex_rd != 5'd0) && (id_rs1 == ex_rd);
      rs2_ex_match = id_valid && id_uses_rs2 && ex_valid && ex_writes_rd &&
                     (ex_rd != 5'd0) && (id_rs2 == ex_rd);
      rs1_wb_match = id_valid && id_uses_rs1 && wb_valid && wb_writes_rd &&
                     (wb_rd != 5'd0) && (id_rs1 == wb_rd);
      rs2_wb_match = id_valid && id_uses_rs2 && wb_valid && wb_writes_rd &&
                     (wb_rd != 5'd0) && (id_rs2 == wb_rd);

      exp_rs1_ex = rs1_ex_match && !ex_is_load;
      exp_rs2_ex = rs2_ex_match && !ex_is_load;
      exp_rs1_wb = rs1_wb_match && !exp_rs1_ex;
      exp_rs2_wb = rs2_wb_match && !exp_rs2_ex;
      exp_stall = ex_is_load && (rs1_ex_match || rs2_ex_match);
    end
  endtask

  // Drive baseline values with no dependencies.
  task automatic drive_idle;
    begin
      id_valid = 1'b1;
      id_rs1 = 5'd1;
      id_uses_rs1 = 1'b1;
      id_rs2 = 5'd2;
      id_uses_rs2 = 1'b1;
      ex_valid = 1'b0;
      ex_rd = 5'd0;
      ex_writes_rd = 1'b0;
      ex_is_load = 1'b0;
      wb_valid = 1'b0;
      wb_rd = 5'd0;
      wb_writes_rd = 1'b0;
    end
  endtask

  // Compare all forwarding and stall outputs against explicit expectations.
  task automatic check_expected(
    input logic exp_rs1_ex,
    input logic exp_rs1_wb,
    input logic exp_rs2_ex,
    input logic exp_rs2_wb,
    input logic exp_stall,
    input string label
  );
    begin
      #1ns;
      if (rs1_forward_ex !== exp_rs1_ex ||
          rs1_forward_wb !== exp_rs1_wb ||
          rs2_forward_ex !== exp_rs2_ex ||
          rs2_forward_wb !== exp_rs2_wb ||
          load_use_stall !== exp_stall ||
          fetch_stall !== exp_stall ||
          decode_stall !== exp_stall ||
          execute_bubble !== exp_stall) begin
        $error("%s mismatch rs1_ex=%0b/%0b rs1_wb=%0b/%0b rs2_ex=%0b/%0b rs2_wb=%0b/%0b stall=%0b/%0b fetch=%0b decode=%0b bubble=%0b",
               label, rs1_forward_ex, exp_rs1_ex, rs1_forward_wb, exp_rs1_wb,
               rs2_forward_ex, exp_rs2_ex, rs2_forward_wb, exp_rs2_wb,
               load_use_stall, exp_stall, fetch_stall, decode_stall, execute_bubble);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Drive current inputs through the reference model and compare the DUT.
  task automatic check_ref(input string label);
    logic exp_rs1_ex;
    logic exp_rs1_wb;
    logic exp_rs2_ex;
    logic exp_rs2_wb;
    logic exp_stall;
    begin
      ref_outputs(exp_rs1_ex, exp_rs1_wb, exp_rs2_ex, exp_rs2_wb, exp_stall);
      check_expected(exp_rs1_ex, exp_rs1_wb, exp_rs2_ex, exp_rs2_wb, exp_stall, label);
    end
  endtask

  task automatic check_directed;
    begin
      drive_idle();
      check_expected(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "idle");

      drive_idle();
      ex_valid = 1'b1;
      ex_writes_rd = 1'b1;
      ex_rd = 5'd1;
      check_expected(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "rs1 ex forward");
      ex_fwd_count++;

      drive_idle();
      ex_valid = 1'b1;
      ex_writes_rd = 1'b1;
      ex_rd = 5'd2;
      check_expected(1'b0, 1'b0, 1'b1, 1'b0, 1'b0, "rs2 ex forward");
      ex_fwd_count++;

      drive_idle();
      wb_valid = 1'b1;
      wb_writes_rd = 1'b1;
      wb_rd = 5'd1;
      check_expected(1'b0, 1'b1, 1'b0, 1'b0, 1'b0, "rs1 wb forward");
      wb_fwd_count++;

      drive_idle();
      wb_valid = 1'b1;
      wb_writes_rd = 1'b1;
      wb_rd = 5'd2;
      check_expected(1'b0, 1'b0, 1'b0, 1'b1, 1'b0, "rs2 wb forward");
      wb_fwd_count++;

      drive_idle();
      ex_valid = 1'b1;
      ex_writes_rd = 1'b1;
      ex_is_load = 1'b1;
      ex_rd = 5'd1;
      check_expected(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, "rs1 load-use stall");
      stall_count++;

      drive_idle();
      ex_valid = 1'b1;
      ex_writes_rd = 1'b1;
      ex_is_load = 1'b1;
      ex_rd = 5'd2;
      check_expected(1'b0, 1'b0, 1'b0, 1'b0, 1'b1, "rs2 load-use stall");
      stall_count++;

      drive_idle();
      id_rs1 = 5'd0;
      id_rs2 = 5'd0;
      ex_valid = 1'b1;
      ex_writes_rd = 1'b1;
      ex_is_load = 1'b1;
      ex_rd = 5'd0;
      wb_valid = 1'b1;
      wb_writes_rd = 1'b1;
      wb_rd = 5'd0;
      check_expected(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "x0 ignored");
      x0_count++;

      drive_idle();
      ex_valid = 1'b1;
      ex_writes_rd = 1'b1;
      ex_rd = 5'd1;
      wb_valid = 1'b1;
      wb_writes_rd = 1'b1;
      wb_rd = 5'd1;
      check_expected(1'b1, 1'b0, 1'b0, 1'b0, 1'b0, "ex priority over wb");
      priority_count++;

      drive_idle();
      id_valid = 1'b0;
      ex_valid = 1'b1;
      ex_writes_rd = 1'b1;
      ex_is_load = 1'b1;
      ex_rd = 5'd1;
      check_expected(1'b0, 1'b0, 1'b0, 1'b0, 1'b0, "invalid id slot");
    end
  endtask

  task automatic check_random(input int unsigned count);
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        id_valid = $urandom_range(0, 1) != 0;
        id_rs1 = 5'($urandom_range(0, 31));
        id_uses_rs1 = $urandom_range(0, 1) != 0;
        id_rs2 = 5'($urandom_range(0, 31));
        id_uses_rs2 = $urandom_range(0, 1) != 0;
        ex_valid = $urandom_range(0, 1) != 0;
        ex_rd = 5'($urandom_range(0, 31));
        ex_writes_rd = $urandom_range(0, 1) != 0;
        ex_is_load = $urandom_range(0, 1) != 0;
        wb_valid = $urandom_range(0, 1) != 0;
        wb_rd = 5'($urandom_range(0, 31));
        wb_writes_rd = $urandom_range(0, 1) != 0;
        check_ref("random hazard");
        random_count++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (ex_fwd_count < 2 || wb_fwd_count < 2 || stall_count < 2 ||
          x0_count < 1 || priority_count < 1 || random_count < 200) begin
        $error("coverage miss: ex=%0d wb=%0d stall=%0d x0=%0d priority=%0d random=%0d",
               ex_fwd_count, wb_fwd_count, stall_count, x0_count,
               priority_count, random_count);
        $fatal(1);
      end
      $display("tb_core_hazard coverage: pass_count=%0d ex=%0d wb=%0d stall=%0d x0=%0d priority=%0d random=%0d",
               pass_count, ex_fwd_count, wb_fwd_count, stall_count,
               x0_count, priority_count, random_count);
    end
  endtask

  initial begin
    void'($urandom(32'hA2A0_0008));
    pass_count = 0;
    ex_fwd_count = 0;
    wb_fwd_count = 0;
    stall_count = 0;
    x0_count = 0;
    priority_count = 0;
    random_count = 0;

    check_directed();
    check_random(200);
    check_coverage_summary();

    $display("tb_core_hazard PASS");
    $finish;
  end
endmodule
