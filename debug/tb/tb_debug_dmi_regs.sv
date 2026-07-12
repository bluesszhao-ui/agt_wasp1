`timescale 1ns/1ps

// Self-checking verification environment for the stage-1 DMI register file.
module tb_debug_dmi_regs;
  import debug_dmi_pkg::*;

  localparam time CLK_PERIOD = 10ns;

  // Testbench clock/reset and the structured DMI transport instance.
  logic clk;
  logic rst_n;
  debug_dmi_if dmi (.clk(clk), .rst_n(rst_n));

  // Hart status inputs model the single core's Debug Mode handshake state.
  logic hart_halted;
  logic hart_running;
  logic hart_resumeack;
  logic hart_havereset;

  // Abstract command executor inputs model busy, completion, and data updates.
  logic        abstract_busy;
  logic        command_error_valid;
  logic [2:0]  command_error;
  logic        data0_we;
  logic [31:0] data0_wdata;
  logic        data1_we;
  logic [31:0] data1_wdata;

  // Debug Module control and abstract-command outputs checked by the scoreboard.
  logic        dmactive;
  logic        ndmreset;
  logic        haltreq;
  logic        resumereq;
  logic        ackhavereset;
  logic        command_valid;
  logic [31:0] command;
  logic [31:0] data0;
  logic [31:0] data1;
  logic [PROGBUF_WORD_COUNT-1:0][31:0] progbuf_words; // Full DUT Program Buffer array view.
  logic [31:0] progbuf_model [PROGBUF_WORD_COUNT]; // Software reference model per word.

  // Explicit coverage counters document which behavior classes were observed.
  int unsigned pass_count;
  int unsigned read_count;
  int unsigned write_count;
  int unsigned status_count;
  int unsigned pulse_count;
  int unsigned busy_count;
  int unsigned error_count;
  int unsigned backpressure_count;
  int unsigned zero_bubble_count;
  int unsigned random_count;
  int unsigned progbuf_count;
  int unsigned progbuf_random_count;
  int unsigned command_pulse_count;
  int unsigned ack_pulse_count;

  debug_dmi_regs u_debug_dmi_regs (
    .clk_i(clk),
    .rst_ni(rst_n),
    .dmi(dmi),
    .hart_halted_i(hart_halted),
    .hart_running_i(hart_running),
    .hart_resumeack_i(hart_resumeack),
    .hart_havereset_i(hart_havereset),
    .abstract_busy_i(abstract_busy),
    .command_error_valid_i(command_error_valid),
    .command_error_i(command_error),
    .data0_we_i(data0_we),
    .data0_wdata_i(data0_wdata),
    .data1_we_i(data1_we),
    .data1_wdata_i(data1_wdata),
    .dmactive_o(dmactive),
    .ndmreset_o(ndmreset),
    .haltreq_o(haltreq),
    .resumereq_o(resumereq),
    .ackhavereset_o(ackhavereset),
    .command_valid_o(command_valid),
    .command_o(command),
    .data0_o(data0),
    .data1_o(data1),
    .progbuf_words_o(progbuf_words)
  );

  // The project-wide verification clock is 100 MHz.
  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Pulse monitors ensure one-cycle side effects are counted even when a DMI
  // helper task subsequently advances the clock to consume the response.
  always @(posedge clk) begin
    #1ns;
    if (command_valid) command_pulse_count <= command_pulse_count + 1;
    if (ackhavereset) ack_pulse_count <= ack_pulse_count + 1;
  end

  // Return all request and executor controls to an inactive value.
  task automatic drive_idle;
    begin
      dmi.req_valid = 1'b0;
      dmi.req_op = DMI_OP_NOP;
      dmi.req_addr = '0;
      dmi.req_data = '0;
      dmi.rsp_ready = 1'b1;
      command_error_valid = 1'b0;
      command_error = CMDERR_NONE;
      data0_we = 1'b0;
      data0_wdata = '0;
      data1_we = 1'b0;
      data1_wdata = '0;
    end
  endtask

  // Apply asynchronous reset and verify all externally visible state is idle.
  task automatic apply_reset;
    begin
      hart_halted = 1'b0;
      hart_running = 1'b1;
      hart_resumeack = 1'b0;
      hart_havereset = 1'b0;
      abstract_busy = 1'b0;
      drive_idle();
      rst_n = 1'b0;
      repeat (3) @(posedge clk);
      rst_n = 1'b1;
      @(posedge clk);
      #1ns;
      if (dmactive || ndmreset || haltreq || resumereq || command_valid ||
          ackhavereset || (command !== '0) || (data0 !== '0) ||
          (data1 !== '0) || (progbuf_words !== '0) || dmi.rsp_valid) begin
        $error("reset state mismatch");
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Compare the full Program Buffer output against the software model.
  task automatic check_progbuf_array(input string label);
    begin
      for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
        if (progbuf_words[idx] !== progbuf_model[idx]) begin
          $fatal(1, "%s word%0d full-array mismatch actual=0x%08x expected=0x%08x",
                 label, idx, progbuf_words[idx], progbuf_model[idx]);
        end
      end
      pass_count++;
    end
  endtask

  // Verify all four DMI addresses, busy protection on reads and writes, and a
  // deterministic-random index/data scoreboard.
  task automatic check_progbuf_registers;
    logic [DMI_ADDR_WIDTH-1:0] addr;
    logic [31:0] value;
    begin
      for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
        addr = DMI_ADDR_PROGBUF0 + DMI_ADDR_WIDTH'(idx);
        dmi_read(addr, 32'h0000_0000, 32'hFFFF_FFFF, "progbuf reset word");
        value = 32'h0010_0093 + (idx << 7);
        dmi_write(addr, value, "progbuf directed write");
        progbuf_model[idx] = value;
        dmi_read(addr, value, 32'hFFFF_FFFF, "progbuf directed read");
        progbuf_count++;
      end
      check_progbuf_array("directed progbuf");

      abstract_busy = 1'b1;
      dmi_write(DMI_ADDR_PROGBUF2, 32'hDEAD_BEEF, "busy progbuf write ignored");
      dmi_read(DMI_ADDR_PROGBUF2, progbuf_model[2], 32'hFFFF_FFFF,
               "busy progbuf payload preserved");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_1102, 32'h0000_1F0F,
               "busy progbuf write cmderr");
      dmi_write(DMI_ADDR_ABSTRACTCS, 32'h0000_0100, "clear progbuf write busy cmderr");

      dmi_read(DMI_ADDR_PROGBUF0, progbuf_model[0], 32'hFFFF_FFFF,
               "busy progbuf read returns data");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_1102, 32'h0000_1F0F,
               "busy progbuf read cmderr");
      dmi_write(DMI_ADDR_ABSTRACTCS, 32'h0000_0100, "clear progbuf read busy cmderr");

      dmi_read(DMI_ADDR_DATA0, data0, 32'hFFFF_FFFF, "busy data0 read returns data");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_1102, 32'h0000_1F0F,
               "busy data0 read cmderr");
      dmi_write(DMI_ADDR_ABSTRACTCS, 32'h0000_0100, "clear data0 read busy cmderr");
      abstract_busy = 1'b0;
      check_progbuf_array("busy progbuf preserved");
      busy_count += 3;

      void'($urandom(32'h5042_5546));
      for (int unsigned iter = 0; iter < 32; iter++) begin
        int unsigned index;
        index = $urandom_range(PROGBUF_WORD_COUNT - 1, 0);
        value = $urandom();
        addr = DMI_ADDR_PROGBUF0 + DMI_ADDR_WIDTH'(index);
        dmi_write(addr, value, "random progbuf write");
        progbuf_model[index] = value;
        dmi_read(addr, value, 32'hFFFF_FFFF, "random progbuf read");
        check_progbuf_array("random progbuf array");
        progbuf_random_count++;
      end
    end
  endtask

  // Execute one DMI operation. The response is deliberately held for one
  // cycle, so every transfer also checks stable response behavior.
  task automatic dmi_transfer(
    input  logic [1:0] op,
    input  logic [DMI_ADDR_WIDTH-1:0] addr,
    input  logic [31:0] request_data,
    input  logic [1:0] expected_resp,
    input  logic [31:0] expected_data,
    input  logic [31:0] data_mask,
    input  string label
  );
    logic [1:0] held_resp;
    logic [31:0] held_data;
    begin
      @(negedge clk);
      dmi.rsp_ready = 1'b0;
      dmi.req_valid = 1'b1;
      dmi.req_op = op;
      dmi.req_addr = addr;
      dmi.req_data = request_data;
      while (!dmi.req_ready) @(negedge clk);
      @(posedge clk);
      #1ns;
      dmi.req_valid = 1'b0;
      if (!dmi.rsp_valid || (dmi.rsp_resp !== expected_resp) ||
          ((dmi.rsp_data & data_mask) !== (expected_data & data_mask))) begin
        $error("%s: resp=%0b data=0x%08h expected_resp=%0b expected_data=0x%08h mask=0x%08h",
               label, dmi.rsp_resp, dmi.rsp_data, expected_resp, expected_data, data_mask);
        $fatal(1);
      end

      held_resp = dmi.rsp_resp;
      held_data = dmi.rsp_data;
      @(posedge clk);
      #1ns;
      if (!dmi.rsp_valid || (dmi.rsp_resp !== held_resp) || (dmi.rsp_data !== held_data) ||
          dmi.req_ready) begin
        $error("%s: held response or request backpressure changed", label);
        $fatal(1);
      end
      backpressure_count++;

      dmi.rsp_ready = 1'b1;
      @(posedge clk);
      #1ns;
      if (dmi.rsp_valid) begin
        $error("%s: response did not retire", label);
        $fatal(1);
      end
      if (op == DMI_OP_READ) read_count++;
      if (op == DMI_OP_WRITE) write_count++;
      if (expected_resp != DMI_RESP_SUCCESS) error_count++;
      pass_count++;
    end
  endtask

  // Convenience wrappers make register intent clear at each directed test.
  task automatic dmi_read(
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0] expected,
    input logic [31:0] mask,
    input string label
  );
    dmi_transfer(DMI_OP_READ, addr, '0, DMI_RESP_SUCCESS, expected, mask, label);
  endtask

  task automatic dmi_write(
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0] value,
    input string label
  );
    dmi_transfer(DMI_OP_WRITE, addr, value, DMI_RESP_SUCCESS, '0, 32'hFFFF_FFFF, label);
  endtask

  // Verify activation semantics, level requests, and one-cycle control pulses.
  task automatic check_dmcontrol;
    int unsigned before_ack;
    begin
      dmi_write(DMI_ADDR_DMCONTROL, 32'hC001_0003, "activate ignores other fields");
      if (!dmactive || ndmreset || haltreq || resumereq) begin
        $error("activation write must only set dmactive");
        $fatal(1);
      end
      dmi_write(DMI_ADDR_DMCONTROL, 32'h8000_0003, "halt and ndmreset");
      if (!haltreq || !ndmreset || resumereq) begin
        $error("halt/ndmreset outputs mismatch");
        $fatal(1);
      end
      dmi_read(DMI_ADDR_DMCONTROL, 32'h8000_0003, 32'hCFFFFFC3, "dmcontrol readback");

      dmi_write(DMI_ADDR_DMCONTROL, 32'h4000_0001, "resume request");
      if (haltreq || !resumereq) begin
        $error("resume request not held");
        $fatal(1);
      end
      hart_resumeack = 1'b1;
      @(posedge clk);
      #1ns;
      hart_resumeack = 1'b0;
      if (resumereq) begin
        $error("resume request did not clear on acknowledgement");
        $fatal(1);
      end

      before_ack = ack_pulse_count;
      dmi_write(DMI_ADDR_DMCONTROL, 32'h9000_0001, "acknowledge havereset");
      if (ack_pulse_count != (before_ack + 1)) begin
        $error("ackhavereset pulse count mismatch");
        $fatal(1);
      end
      pulse_count++;
      pass_count++;
    end
  endtask

  // Verify single-hart status mapping and non-existent hart enumeration.
  task automatic check_dmstatus;
    begin
      hart_running = 1'b1;
      hart_halted = 1'b0;
      dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_0C82, 32'h000F_FFFF, "running hart status");
      hart_running = 1'b0;
      hart_halted = 1'b1;
      dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_0382, 32'h000F_FFFF, "halted hart status");
      hart_resumeack = 1'b1;
      hart_havereset = 1'b1;
      dmi_read(DMI_ADDR_DMSTATUS, 32'h000F_0382, 32'h000F_FFFF, "resume/reset status");
      hart_resumeack = 1'b0;
      hart_havereset = 1'b0;

      dmi_write(DMI_ADDR_DMCONTROL, 32'h0001_0001, "select nonexistent hart1");
      if (haltreq || resumereq) begin
        $error("requests must be suppressed for nonexistent hart");
        $fatal(1);
      end
      dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_C082, 32'h000F_FFFF, "nonexistent hart status");
      dmi_write(DMI_ADDR_DMCONTROL, 32'h0000_0001, "reselect hart0");
      status_count += 4;
      pass_count++;
    end
  endtask

  // Verify data0 ownership, busy protection, W1C cmderr, and command pulses.
  task automatic check_abstract_registers;
    int unsigned before_command;
    begin
      dmi_read(DMI_ADDR_HARTINFO, 32'h0000_0000, 32'hFFFF_FFFF, "hartinfo minimal image");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0400_0002, 32'h1F00_1F0F, "abstractcs reset image");
      dmi_read(DMI_ADDR_ABSTRACTAUTO, 32'h0000_0000, 32'hffff_ffff,
               "abstractauto reset zero");
      dmi_write(DMI_ADDR_ABSTRACTAUTO, 32'hffff_ffff,
                "abstractauto WARL write accepted");
      dmi_read(DMI_ADDR_ABSTRACTAUTO, 32'h0000_0000, 32'hffff_ffff,
               "abstractauto remains zero");
      dmi_write(DMI_ADDR_DATA0, 32'h1234_5678, "data0 dmi write");
      dmi_read(DMI_ADDR_DATA0, 32'h1234_5678, 32'hFFFF_FFFF, "data0 dmi read");
      dmi_write(DMI_ADDR_DATA1, 32'h2000_0010, "data1 dmi write");
      dmi_read(DMI_ADDR_DATA1, 32'h2000_0010, 32'hFFFF_FFFF, "data1 dmi read");

      data0_we = 1'b1;
      data0_wdata = 32'hCAFE_BABE;
      @(posedge clk);
      #1ns;
      data0_we = 1'b0;
      dmi_read(DMI_ADDR_DATA0, 32'hCAFE_BABE, 32'hFFFF_FFFF, "data0 executor update");
      data1_we = 1'b1;
      data1_wdata = 32'h2000_0014;
      @(posedge clk);
      #1ns;
      data1_we = 1'b0;
      dmi_read(DMI_ADDR_DATA1, 32'h2000_0014, 32'hFFFF_FFFF, "data1 executor update");

      abstract_busy = 1'b1;
      dmi_write(DMI_ADDR_DATA0, 32'hDEAD_BEEF, "data0 ignored while busy");
      dmi_write(DMI_ADDR_DATA1, 32'hDEAD_BEEF, "data1 ignored while busy");
      dmi_read(DMI_ADDR_DATA0, 32'hCAFE_BABE, 32'hFFFF_FFFF, "busy data0 preserved");
      dmi_read(DMI_ADDR_DATA1, 32'h2000_0014, 32'hFFFF_FFFF, "busy data1 preserved");
      before_command = command_pulse_count;
      dmi_write(DMI_ADDR_COMMAND, 32'h0022_1001, "command rejected while busy");
      if (command_pulse_count != before_command) begin
        $error("busy command generated command pulse");
        $fatal(1);
      end
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_1102, 32'h0000_1F0F, "busy cmderr");
      dmi_write(DMI_ADDR_ABSTRACTCS, 32'h0000_0100, "clear busy cmderr");
      abstract_busy = 1'b0;
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_0002, 32'h0000_1F0F, "cmderr cleared");

      before_command = command_pulse_count;
      dmi_write(DMI_ADDR_COMMAND, 32'h0022_1001, "accepted abstract command");
      if ((command_pulse_count != (before_command + 1)) || (command !== 32'h0022_1001)) begin
        $error("accepted command pulse/data mismatch");
        $fatal(1);
      end

      command_error = CMDERR_NOTSUP;
      command_error_valid = 1'b1;
      @(posedge clk);
      #1ns;
      command_error_valid = 1'b0;
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_0202, 32'h0000_070F, "executor cmderr");
      dmi_write(DMI_ADDR_ABSTRACTCS, 32'h0000_0200, "clear executor cmderr");
      busy_count += 2;
      pulse_count++;
      pass_count++;
    end
  endtask

  // Verify transport NOP, illegal operations/addresses, and explicit response hold.
  task automatic check_transport_errors;
    begin
      dmi_transfer(DMI_OP_NOP, '0, 32'hDEAD_BEEF, DMI_RESP_SUCCESS,
                   32'h0000_0000, 32'hFFFF_FFFF, "DMI nop");
      dmi_transfer(2'b11, DMI_ADDR_DMSTATUS, '0, DMI_RESP_FAILED,
                   32'h0000_0000, 32'hFFFF_FFFF, "reserved DMI op");
      dmi_transfer(DMI_OP_READ, 7'h7F, '0, DMI_RESP_FAILED,
                   32'h0000_0000, 32'hFFFF_FFFF, "unknown DMI address");
      dmi_write(DMI_ADDR_DMSTATUS, 32'hFFFF_FFFF, "read-only write ignored");
      dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_0382, 32'h000F_FFFF, "status unchanged after RO write");
      pass_count++;
    end
  endtask

  // Exercise simultaneous old-response consumption and next-request capture.
  task automatic check_zero_bubble_replace;
    begin
      @(negedge clk);
      dmi.rsp_ready = 1'b0;
      dmi.req_valid = 1'b1;
      dmi.req_op = DMI_OP_READ;
      dmi.req_addr = DMI_ADDR_DMCONTROL;
      dmi.req_data = '0;
      @(posedge clk);
      #1ns;
      dmi.req_valid = 1'b0;
      if (!dmi.rsp_valid || (dmi.rsp_resp != DMI_RESP_SUCCESS) ||
          (dmi.rsp_data != 32'h0000_0001)) begin
        $error("zero-bubble first response mismatch");
        $fatal(1);
      end

      @(negedge clk);
      dmi.rsp_ready = 1'b1;
      dmi.req_valid = 1'b1;
      dmi.req_op = DMI_OP_READ;
      dmi.req_addr = DMI_ADDR_DMSTATUS;
      #1ns;
      if (!dmi.req_ready) begin
        $error("zero-bubble replacement request was not ready");
        $fatal(1);
      end
      @(posedge clk);
      #1ns;
      dmi.req_valid = 1'b0;
      dmi.rsp_ready = 1'b0;
      if (!dmi.rsp_valid || (dmi.rsp_resp != DMI_RESP_SUCCESS) ||
          ((dmi.rsp_data & 32'h000F_FFFF) != 32'h0000_0382)) begin
        $error("zero-bubble replacement response mismatch");
        $fatal(1);
      end

      dmi.rsp_ready = 1'b1;
      @(posedge clk);
      #1ns;
      if (dmi.rsp_valid) begin
        $error("zero-bubble replacement response did not retire");
        $fatal(1);
      end
      read_count += 2;
      zero_bubble_count++;
      pass_count++;
    end
  endtask

  // Deterministic-random data patterns exercise every data bit through DMI.
  task automatic check_random_data0(input int unsigned iterations);
    logic [31:0] value;
    begin
      void'($urandom(32'h5753_5031));
      for (int unsigned idx = 0; idx < iterations; idx++) begin
        value = $urandom();
        dmi_write(DMI_ADDR_DATA0, value, "random data0 write");
        dmi_read(DMI_ADDR_DATA0, value, 32'hFFFF_FFFF, "random data0 read");
        random_count++;
      end
    end
  endtask

  // Clearing dmactive must return every Debug Module register and request to idle.
  task automatic check_dmactive_clear;
    begin
      dmi_write(DMI_ADDR_DMCONTROL, 32'h0000_0000, "clear dmactive");
      if (dmactive || ndmreset || haltreq || resumereq || (command !== '0) ||
          (data0 !== '0) || (data1 !== '0) || (progbuf_words !== '0)) begin
        $error("dmactive clear did not reset Debug Module state");
        $fatal(1);
      end
      data0_we = 1'b1;
      data0_wdata = 32'hFFFF_FFFF;
      data1_we = 1'b1;
      data1_wdata = 32'hFFFF_FFFF;
      command_error_valid = 1'b1;
      command_error = CMDERR_OTHER;
      @(posedge clk);
      #1ns;
      data0_we = 1'b0;
      data1_we = 1'b0;
      command_error_valid = 1'b0;
      if ((data0 !== '0) || (data1 !== '0)) begin
        $error("inactive DM accepted a stale executor data write");
        $fatal(1);
      end
      for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
        progbuf_model[idx] = '0;
      end
      dmi_write(DMI_ADDR_PROGBUF1, 32'hFFFF_FFFF, "inactive progbuf write ignored");
      dmi_read(DMI_ADDR_PROGBUF1, 32'h0000_0000, 32'hFFFF_FFFF,
               "inactive progbuf remains clear");
      check_progbuf_array("dmactive clear progbuf");
      dmi_read(DMI_ADDR_DMCONTROL, 32'h0000_0000, 32'hFFFF_FFFF, "inactive dmcontrol");
      dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_0082, 32'h000F_FFFF, "inactive dmstatus identity");
      dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_0002, 32'h0000_070F, "inactive executor error ignored");
      pass_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    read_count = 0;
    write_count = 0;
    status_count = 0;
    pulse_count = 0;
    busy_count = 0;
    error_count = 0;
    backpressure_count = 0;
    zero_bubble_count = 0;
    random_count = 0;
    progbuf_count = 0;
    progbuf_random_count = 0;
    command_pulse_count = 0;
    ack_pulse_count = 0;
    for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
      progbuf_model[idx] = '0;
    end
    rst_n = 1'b1;

    $display("phase reset start=%0t", $time);
    apply_reset();
    $display("phase identity start=%0t", $time);
    dmi_read(DMI_ADDR_DMSTATUS, 32'h0000_0082, 32'h000F_FFFF, "reset dmstatus identity");
    $display("phase dmcontrol start=%0t", $time);
    check_dmcontrol();
    $display("phase dmstatus start=%0t", $time);
    check_dmstatus();
    $display("phase abstract start=%0t", $time);
    check_abstract_registers();
    $display("phase progbuf start=%0t", $time);
    check_progbuf_registers();
    $display("phase transport start=%0t", $time);
    check_transport_errors();
    $display("phase zero_bubble start=%0t", $time);
    check_zero_bubble_replace();
    $display("phase random start=%0t", $time);
    check_random_data0(16);
    $display("phase deactivate start=%0t", $time);
    check_dmactive_clear();
    $display("phase complete=%0t", $time);

    $display("tb_debug_dmi_regs coverage: pass=%0d read=%0d write=%0d status=%0d pulse=%0d busy=%0d error=%0d backpressure=%0d zero_bubble=%0d random=%0d progbuf=%0d progbuf_random=%0d",
             pass_count, read_count, write_count, status_count, pulse_count,
             busy_count, error_count, backpressure_count, zero_bubble_count,
             random_count, progbuf_count, progbuf_random_count);
    $display("tb_debug_dmi_regs PASS");
    $finish;
  end
endmodule
