`timescale 1ns/1ps

// Self-checking testbench for the wasp1 JTAG Debug Transport Module.
module tb_debug_jtag_dtm;
  import debug_dmi_pkg::*;

  localparam int IR_WIDTH = 5;
  localparam int DMI_DR_WIDTH = DMI_ADDR_WIDTH + 34;
  localparam logic [5:0] DMI_ABITS = 6'(DMI_ADDR_WIDTH);
  localparam logic [31:0] IDCODE_VALUE = 32'h1000_01CF;
  localparam logic [IR_WIDTH-1:0] IR_IDCODE = 5'b00001;
  localparam logic [IR_WIDTH-1:0] IR_DTMCS  = 5'b10000;
  localparam logic [IR_WIDTH-1:0] IR_DMI    = 5'b10001;

  // System debug clock/reset domain. The clock policy is the project default.
  logic clk_i;
  logic rst_ni;

  // JTAG pins driven by bit-bang tasks.
  logic tck_i;
  logic trst_ni;
  logic tms_i;
  logic tdi_i;
  logic tdo_o;

  // DTMCS hard reset pulse monitor.
  logic dtm_hardreset_o;
  logic hardreset_seen_q;

  // DMI interface and a small behavioral Debug Module response model.
  debug_dmi_if dmi_if (
    .clk   (clk_i),
    .rst_n (rst_ni)
  );

  // Mock register file indexed by DMI address for read/write checks.
  logic [31:0] dmi_mem [0:127];
  logic        model_pending_q;
  int          model_delay_q;
  int          response_latency_cfg;
  logic [DMI_ADDR_WIDTH-1:0] model_addr_q;
  logic [31:0]               model_data_q;
  logic [1:0]                model_op_q;
  int pass_count;
  int dmi_req_count;
  int dmi_rsp_count;
  int busy_checks;
  int dtmcs_checks;
  int idcode_checks;

  debug_jtag_dtm #(
    .IR_WIDTH       (IR_WIDTH),
    .DMI_ADDR_WIDTH (DMI_ADDR_WIDTH),
    .IDCODE_VALUE   (IDCODE_VALUE)
  ) dut (
    .clk_i           (clk_i),
    .rst_ni          (rst_ni),
    .tck_i           (tck_i),
    .trst_ni         (trst_ni),
    .tms_i           (tms_i),
    .tdi_i           (tdi_i),
    .tdo_o           (tdo_o),
    .dmi             (dmi_if),
    .dtm_hardreset_o (dtm_hardreset_o)
  );

  // 100 MHz verification clock.
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;
  end

  // Sticky monitor for the one-TCK DTM hard reset pulse.
  always_ff @(posedge dtm_hardreset_o or negedge trst_ni) begin
    if (!trst_ni) begin
      hardreset_seen_q <= 1'b0;
    end else begin
      hardreset_seen_q <= 1'b1;
    end
  end

  // Behavioral DMI target. It accepts one request, waits a programmable number
  // of clk_i cycles, then returns a deterministic response.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      dmi_if.req_ready <= 1'b0;
      dmi_if.rsp_valid <= 1'b0;
      dmi_if.rsp_resp  <= DMI_RESP_SUCCESS;
      dmi_if.rsp_data  <= 32'h0;
      model_pending_q  <= 1'b0;
      model_delay_q    <= 0;
      model_addr_q     <= '0;
      model_data_q     <= 32'h0;
      model_op_q       <= DMI_OP_NOP;
      dmi_req_count    <= 0;
      dmi_rsp_count    <= 0;
    end else begin
      dmi_if.req_ready <= !model_pending_q && !dmi_if.rsp_valid;

      if (dmi_if.req_valid && dmi_if.req_ready) begin
        model_pending_q <= 1'b1;
        model_delay_q   <= response_latency_cfg;
        model_addr_q    <= dmi_if.req_addr;
        model_data_q    <= dmi_if.req_data;
        model_op_q      <= dmi_if.req_op;
        dmi_req_count   <= dmi_req_count + 1;
        if (dmi_if.req_op == DMI_OP_WRITE) begin
          dmi_mem[dmi_if.req_addr] <= dmi_if.req_data;
        end
      end

      if (model_pending_q) begin
        if (model_delay_q > 0) begin
          model_delay_q <= model_delay_q - 1;
        end else if (!dmi_if.rsp_valid) begin
          model_pending_q  <= 1'b0;
          dmi_if.rsp_valid <= 1'b1;
          dmi_if.rsp_resp  <= DMI_RESP_SUCCESS;
          dmi_if.rsp_data  <= (model_op_q == DMI_OP_READ) ? dmi_mem[model_addr_q] : model_data_q;
        end
      end

      if (dmi_if.rsp_valid && dmi_if.rsp_ready) begin
        dmi_if.rsp_valid <= 1'b0;
        dmi_rsp_count    <= dmi_rsp_count + 1;
      end
    end
  end

  function automatic logic [63:0] dmi_packet(
    input logic [1:0]                op,
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0]               data
  );
    begin
      dmi_packet = 64'h0;
      dmi_packet[1:0] = op;
      dmi_packet[33:2] = data;
      dmi_packet[DMI_DR_WIDTH-1:34] = addr;
    end
  endfunction

  task automatic check(input logic condition, input string message);
    begin
      if (!condition) begin
        $error("CHECK FAILED: %s at %0t", message, $time);
        $finish;
      end
      pass_count++;
    end
  endtask

  // Drive one complete JTAG TCK cycle and sample the previous TDO bit.
  task automatic jtag_cycle(
    input  logic tms,
    input  logic tdi,
    output logic tdo_sample
  );
    begin
      tms_i = tms;
      tdi_i = tdi;
      #3;
      tck_i = 1'b1;
      #1;
      tdo_sample = tdo_o;
      #4;
      tck_i = 1'b0;
      #2;
    end
  endtask

  task automatic jtag_cycle_ignore(input logic tms, input logic tdi);
    logic unused_tdo;
    begin
      jtag_cycle(tms, tdi, unused_tdo);
    end
  endtask

  task automatic tap_reset_to_idle;
    int i;
    begin
      for (i = 0; i < 6; i++) begin
        jtag_cycle_ignore(1'b1, 1'b0);
      end
      jtag_cycle_ignore(1'b0, 1'b0);
    end
  endtask

  task automatic set_ir(input logic [IR_WIDTH-1:0] ir_value);
    int i;
    logic unused_tdo;
    begin
      jtag_cycle_ignore(1'b1, 1'b0); // Select-DR-Scan
      jtag_cycle_ignore(1'b1, 1'b0); // Select-IR-Scan
      jtag_cycle_ignore(1'b0, 1'b0); // Capture-IR
      jtag_cycle_ignore(1'b0, 1'b0); // Shift-IR, TDO now holds capture bit 0
      for (i = 0; i < IR_WIDTH; i++) begin
        jtag_cycle(i == (IR_WIDTH - 1), ir_value[i], unused_tdo);
      end
      jtag_cycle_ignore(1'b1, 1'b0); // Update-IR
      jtag_cycle_ignore(1'b0, 1'b0); // Run-Test/Idle
    end
  endtask

  task automatic scan_dr(
    input  int          width,
    input  logic [63:0] data_in,
    output logic [63:0] data_out
  );
    int i;
    logic tdo_bit;
    begin
      data_out = 64'h0;
      jtag_cycle_ignore(1'b1, 1'b0); // Select-DR-Scan
      jtag_cycle_ignore(1'b0, 1'b0); // Capture-DR
      jtag_cycle_ignore(1'b0, 1'b0); // Shift-DR, TDO now holds capture bit 0
      for (i = 0; i < width; i++) begin
        jtag_cycle(i == (width - 1), data_in[i], tdo_bit);
        data_out[i] = tdo_bit;
      end
      jtag_cycle_ignore(1'b1, 1'b0); // Update-DR
      jtag_cycle_ignore(1'b0, 1'b0); // Run-Test/Idle
    end
  endtask

  task automatic wait_debug_clocks(input int cycles);
    int i;
    begin
      for (i = 0; i < cycles; i++) begin
        @(posedge clk_i);
      end
    end
  endtask

  task automatic jtag_idle_cycles(input int cycles);
    int i;
    begin
      for (i = 0; i < cycles; i++) begin
        jtag_cycle_ignore(1'b0, 1'b0);
      end
    end
  endtask

  initial begin
    logic [63:0] scan_out;
    logic [31:0] dtmcs;
    logic [63:0] dmi_out;

    pass_count = 0;
    busy_checks = 0;
    dtmcs_checks = 0;
    idcode_checks = 0;
    response_latency_cfg = 2;
    rst_ni = 1'b0;
    trst_ni = 1'b0;
    tck_i = 1'b0;
    tms_i = 1'b1;
    tdi_i = 1'b0;

    wait_debug_clocks(4);
    trst_ni = 1'b1;
    rst_ni = 1'b1;
    wait_debug_clocks(2);
    tap_reset_to_idle();

    // IDCODE: reset instruction must select the 32-bit IDCODE data register.
    scan_dr(32, 64'h0, scan_out);
    check(scan_out[31:0] == IDCODE_VALUE, "reset-selected IDCODE scan");
    idcode_checks++;

    // DTMCS: version, abits, idle, and dmistat must match the stage-1 contract.
    set_ir(IR_DTMCS);
    scan_dr(32, 64'h0, scan_out);
    dtmcs = scan_out[31:0];
    check(dtmcs[3:0] == 4'd1, "DTMCS version is v0.13 JTAG DTM");
    check(dtmcs[9:4] == DMI_ABITS, "DTMCS abits reports DMI width");
    check(dtmcs[14:12] == 3'd1, "DTMCS idle is one TCK idle cycle");
    check(dtmcs[11:10] == DMI_RESP_SUCCESS, "DTMCS dmistat starts clear");
    dtmcs_checks += 4;

    // DTMCS hard reset is a write-one pulse and also clears sticky status.
    scan_dr(32, 64'h0002_0000, scan_out);
    check(hardreset_seen_q, "DTMCS dmihardreset pulse observed");

    // DMI write: the first scan launches the request, a later NOP scan returns
    // the write response captured from the DMI model.
    set_ir(IR_DMI);
    scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_WRITE, DMI_ADDR_DATA0, 32'hCAFE_1234), dmi_out);
    check(dmi_out[1:0] == DMI_RESP_SUCCESS, "initial DMI scan returns previous success");
    wait_debug_clocks(12);
    jtag_idle_cycles(4);
    scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_NOP, '0, 32'h0), dmi_out);
    check(dmi_out[1:0] == DMI_RESP_SUCCESS, "DMI write response status success");
    check(dmi_out[33:2] == 32'hCAFE_1234, "DMI write response returns written data");
    check(dmi_out[DMI_DR_WIDTH-1:34] == DMI_ADDR_DATA0, "DMI write response returns address");
    check(dmi_mem[DMI_ADDR_DATA0] == 32'hCAFE_1234, "DMI write reached model register");

    // DMI read: preload the model register and check the response payload.
    dmi_mem[DMI_ADDR_DMSTATUS] = 32'hA5A5_5A5A;
    scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_READ, DMI_ADDR_DMSTATUS, 32'h0), dmi_out);
    wait_debug_clocks(12);
    jtag_idle_cycles(4);
    scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_NOP, '0, 32'h0), dmi_out);
    check(dmi_out[1:0] == DMI_RESP_SUCCESS, "DMI read response status success");
    check(dmi_out[33:2] == 32'hA5A5_5A5A, "DMI read response returns model data");
    check(dmi_out[DMI_DR_WIDTH-1:34] == DMI_ADDR_DMSTATUS, "DMI read response returns address");

    // Busy path: issue a second DMI operation while one is still in flight.
    response_latency_cfg = 60;
    scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_READ, DMI_ADDR_DATA0, 32'h0), dmi_out);
    scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_WRITE, DMI_ADDR_DATA0, 32'h1111_2222), dmi_out);
    check(dmi_out[1:0] == DMI_RESP_BUSY, "DMI scan reports busy while request is in flight");
    busy_checks++;

    set_ir(IR_DTMCS);
    scan_dr(32, 64'h0, scan_out);
    dtmcs = scan_out[31:0];
    check(dtmcs[11:10] == DMI_RESP_BUSY, "DTMCS dmistat records sticky busy");
    busy_checks++;

    scan_dr(32, 64'h0001_0000, scan_out);
    wait_debug_clocks(80);
    jtag_idle_cycles(4);
    scan_dr(32, 64'h0, scan_out);
    dtmcs = scan_out[31:0];
    check(dtmcs[11:10] == DMI_RESP_SUCCESS, "DTMCS dmireset clears sticky busy");
    busy_checks++;

    // Unsupported IR values must safely select BYPASS.
    set_ir(5'b00110);
    scan_dr(1, 64'h1, scan_out);
    check(scan_out[0] == 1'b0, "unknown IR maps to BYPASS capture zero");

    wait_debug_clocks(80);
    check(dmi_req_count >= 3, "DMI model accepted expected requests");
    check(dmi_rsp_count >= 3, "DMI model returned expected responses");

    $display("tb_debug_jtag_dtm coverage: pass_count=%0d idcode=%0d dtmcs=%0d busy=%0d dmi_req=%0d dmi_rsp=%0d",
             pass_count, idcode_checks, dtmcs_checks, busy_checks, dmi_req_count, dmi_rsp_count);
    $display("tb_debug_jtag_dtm PASS");
    $finish;
  end
endmodule
