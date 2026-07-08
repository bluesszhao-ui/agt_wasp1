`timescale 1ns/1ps

// Self-checking JTAG-to-Debug-Module integration testbench.
module tb_debug_jtag;
  import debug_dmi_pkg::*;

  localparam int IR_WIDTH = 5;
  localparam int DMI_DR_WIDTH = DMI_ADDR_WIDTH + 34;
  localparam logic [5:0] DMI_ABITS = 6'(DMI_ADDR_WIDTH);
  localparam logic [31:0] IDCODE_VALUE = 32'h1000_01CF;
  localparam logic [IR_WIDTH-1:0] IR_DTMCS = 5'b10000;
  localparam logic [IR_WIDTH-1:0] IR_DMI   = 5'b10001;
  localparam time CLK_PERIOD = 10ns;

  logic clk;                   // 100 MHz Debug Module clock.
  logic rst_n;                 // Active-low system/debug reset.
  logic tck;                   // JTAG test clock.
  logic trst_n;                // Active-low JTAG reset.
  logic tms;                   // JTAG mode select.
  logic tdi;                   // JTAG serial input.
  logic tdo;                   // JTAG serial output.
  logic hart_reset_event;      // Simulated hart reset event.
  logic dmactive;              // Observed Debug Module active state.
  logic ndmreset;              // Observed non-debug reset request.
  logic dtm_hardreset;         // Observed DTM hard reset pulse.

  debug_if core_debug (
    .clk   (clk),
    .rst_n (rst_n)
  );

  int unsigned pass_count;
  int unsigned jtag_dmi_reads;
  int unsigned jtag_dmi_writes;
  int unsigned halt_count;
  int unsigned resume_count;
  int unsigned gpr_write_count;
  int unsigned gpr_read_count;
  int unsigned csr_read_count;
  int unsigned step_count;
  int unsigned reset_count;

  debug_jtag u_debug_jtag (
    .clk_i              (clk),
    .rst_ni             (rst_n),
    .tck_i              (tck),
    .trst_ni            (trst_n),
    .tms_i              (tms),
    .tdi_i              (tdi),
    .tdo_o              (tdo),
    .core_debug         (core_debug),
    .hart_reset_event_i (hart_reset_event),
    .dmactive_o         (dmactive),
    .ndmreset_o         (ndmreset),
    .dtm_hardreset_o    (dtm_hardreset)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  function automatic logic [31:0] make_access_command(
    input logic [2:0]  aarsize,
    input logic        transfer,
    input logic        write_value,
    input logic [15:0] regno
  );
    logic [31:0] value;
    begin
      value = '0;
      value[31:24] = ABSTRACT_CMD_ACCESS_REGISTER;
      value[22:20] = aarsize;
      value[17] = transfer;
      value[16] = write_value;
      value[15:0] = regno;
      make_access_command = value;
    end
  endfunction

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

  task automatic check(input logic condition, input string label);
    begin
      if (!condition) begin
        $error("CHECK FAILED: %s at %0t", label, $time);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic step_clock;
    begin
      @(posedge clk);
      #1ns;
    end
  endtask

  task automatic wait_debug_clocks(input int cycles);
    int i;
    begin
      for (i = 0; i < cycles; i++) begin
        @(posedge clk);
      end
    end
  endtask

  task automatic drive_core_idle;
    begin
      core_debug.halted = 1'b0;
      core_debug.running = 1'b1;
      core_debug.dpc = 32'h0000_0000;
      core_debug.dcsr_cause = ABSTRACT_DCSR_CAUSE_HALTREQ;
      core_debug.gpr_req_ready = 1'b0;
      core_debug.gpr_rsp_valid = 1'b0;
      core_debug.gpr_rsp_rdata = '0;
      core_debug.gpr_rsp_err = 1'b0;
      core_debug.mem_req_ready = 1'b0;
      core_debug.mem_rsp_valid = 1'b0;
      core_debug.mem_rsp_rdata = '0;
      core_debug.mem_rsp_err = 1'b0;
      hart_reset_event = 1'b0;
    end
  endtask

  task automatic jtag_cycle(
    input  logic tms_value,
    input  logic tdi_value,
    output logic tdo_sample
  );
    begin
      tms = tms_value;
      tdi = tdi_value;
      #3ns;
      tck = 1'b1;
      #1ns;
      tdo_sample = tdo;
      #4ns;
      tck = 1'b0;
      #2ns;
    end
  endtask

  task automatic jtag_cycle_ignore(input logic tms_value, input logic tdi_value);
    logic unused_tdo;
    begin
      jtag_cycle(tms_value, tdi_value, unused_tdo);
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
      jtag_cycle_ignore(1'b0, 1'b0); // Shift-IR
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
      jtag_cycle_ignore(1'b0, 1'b0); // Shift-DR
      for (i = 0; i < width; i++) begin
        jtag_cycle(i == (width - 1), data_in[i], tdo_bit);
        data_out[i] = tdo_bit;
      end
      jtag_cycle_ignore(1'b1, 1'b0); // Update-DR
      jtag_cycle_ignore(1'b0, 1'b0); // Run-Test/Idle
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

  task automatic jtag_dmi_transfer(
    input  logic [1:0]                op,
    input  logic [DMI_ADDR_WIDTH-1:0] addr,
    input  logic [31:0]               data,
    output logic [1:0]                rsp,
    output logic [31:0]               rsp_data,
    output logic [DMI_ADDR_WIDTH-1:0] rsp_addr
  );
    logic [63:0] scan_out;
    begin
      set_ir(IR_DMI);
      scan_dr(DMI_DR_WIDTH, dmi_packet(op, addr, data), scan_out);
      wait_debug_clocks(8);
      jtag_idle_cycles(4);
      scan_dr(DMI_DR_WIDTH, dmi_packet(DMI_OP_NOP, '0, 32'h0), scan_out);
      rsp = scan_out[1:0];
      rsp_data = scan_out[33:2];
      rsp_addr = scan_out[DMI_DR_WIDTH-1:34];
      if (op == DMI_OP_READ) jtag_dmi_reads++;
      if (op == DMI_OP_WRITE) jtag_dmi_writes++;
    end
  endtask

  task automatic jtag_dmi_write(
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0]               data,
    input string                     label
  );
    logic [1:0] rsp;
    logic [31:0] rsp_data;
    logic [DMI_ADDR_WIDTH-1:0] rsp_addr;
    begin
      jtag_dmi_transfer(DMI_OP_WRITE, addr, data, rsp, rsp_data, rsp_addr);
      check(rsp == DMI_RESP_SUCCESS, {label, " write response success"});
      check(rsp_addr == addr, {label, " write response address"});
    end
  endtask

  task automatic jtag_dmi_read(
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0]               expected,
    input logic [31:0]               mask,
    input string                     label
  );
    logic [1:0] rsp;
    logic [31:0] rsp_data;
    logic [DMI_ADDR_WIDTH-1:0] rsp_addr;
    begin
      jtag_dmi_transfer(DMI_OP_READ, addr, 32'h0, rsp, rsp_data, rsp_addr);
      check(rsp == DMI_RESP_SUCCESS, {label, " read response success"});
      check(rsp_addr == addr, {label, " read response address"});
      check((rsp_data & mask) == (expected & mask), {label, " read data"});
    end
  endtask

  task automatic wait_for_gpr_req(input string label);
    int unsigned timeout;
    begin
      timeout = 0;
      while (!core_debug.gpr_req_valid && timeout < 40) begin
        step_clock();
        timeout++;
      end
      check(core_debug.gpr_req_valid, {label, " GPR request visible"});
    end
  endtask

  task automatic complete_gpr_access(
    input logic        expected_write,
    input logic [4:0]  expected_addr,
    input logic [31:0] expected_wdata,
    input logic [31:0] response_data,
    input logic        response_error,
    input string       label
  );
    begin
      wait_for_gpr_req(label);
      check(core_debug.gpr_req_write == expected_write, {label, " GPR direction"});
      check(core_debug.gpr_req_addr == expected_addr, {label, " GPR address"});
      if (expected_write) begin
        check(core_debug.gpr_req_wdata == expected_wdata, {label, " GPR write data"});
      end
      @(negedge clk);
      core_debug.gpr_req_ready = 1'b1;
      core_debug.gpr_rsp_valid = 1'b1;
      core_debug.gpr_rsp_rdata = response_data;
      core_debug.gpr_rsp_err = response_error;
      step_clock();
      core_debug.gpr_req_ready = 1'b0;
      core_debug.gpr_rsp_valid = 1'b0;
      core_debug.gpr_rsp_rdata = '0;
      core_debug.gpr_rsp_err = 1'b0;
    end
  endtask

  task automatic apply_reset;
    begin
      drive_core_idle();
      rst_n = 1'b0;
      trst_n = 1'b0;
      tck = 1'b0;
      tms = 1'b1;
      tdi = 1'b0;
      wait_debug_clocks(4);
      trst_n = 1'b1;
      rst_n = 1'b1;
      wait_debug_clocks(2);
      tap_reset_to_idle();
      check(!dmactive && !ndmreset && !core_debug.halt_req &&
            !core_debug.resume_req && !core_debug.step_req,
            "reset leaves debug inactive and core controls idle");
      reset_count++;
    end
  endtask

  initial begin
    logic [63:0] scan_out;
    logic [31:0] dtmcs;

    pass_count = 0;
    jtag_dmi_reads = 0;
    jtag_dmi_writes = 0;
    halt_count = 0;
    resume_count = 0;
    gpr_write_count = 0;
    gpr_read_count = 0;
    csr_read_count = 0;
    step_count = 0;
    reset_count = 0;
    rst_n = 1'b0;
    trst_n = 1'b0;
    tck = 1'b0;
    tms = 1'b1;
    tdi = 1'b0;
    drive_core_idle();

    apply_reset();

    // Default post-reset instruction is IDCODE.
    scan_dr(32, 64'h0, scan_out);
    check(scan_out[31:0] == IDCODE_VALUE, "JTAG IDCODE through integrated wrapper");

    set_ir(IR_DTMCS);
    scan_dr(32, 64'h0, scan_out);
    dtmcs = scan_out[31:0];
    check(dtmcs[3:0] == 4'd1, "integrated DTMCS version");
    check(dtmcs[9:4] == DMI_ABITS, "integrated DTMCS abits");
    check(dtmcs[11:10] == DMI_RESP_SUCCESS, "integrated DTMCS dmistat clear");

    // Activate the Debug Module and observe running hart status through JTAG DMI.
    jtag_dmi_write(DMI_ADDR_DMCONTROL, 32'h0000_0001, "activate DM over JTAG");
    check(dmactive && !ndmreset, "dmactive observable after JTAG write");
    jtag_dmi_read(DMI_ADDR_DMSTATUS, 32'h000C_0C82, 32'h000F_FFFF,
                  "running dmstatus over JTAG");

    // Halt and resume through the integrated JTAG path.
    jtag_dmi_write(DMI_ADDR_DMCONTROL, 32'h8000_0001, "halt over JTAG");
    check(core_debug.halt_req && !core_debug.resume_req, "halt request reaches core");
    core_debug.running = 1'b0;
    core_debug.halted = 1'b1;
    step_clock();
    check(!core_debug.halt_req, "halt request retires after halted");
    jtag_dmi_read(DMI_ADDR_DMSTATUS, 32'h000C_0382, 32'h000F_FFFF,
                  "halted dmstatus over JTAG");
    halt_count++;

    jtag_dmi_write(DMI_ADDR_DMCONTROL, 32'h4000_0001, "resume over JTAG");
    check(core_debug.resume_req && !core_debug.halt_req, "resume request reaches core");
    core_debug.halted = 1'b0;
    core_debug.running = 1'b1;
    step_clock();
    check(!core_debug.resume_req, "resume request retires after running");
    jtag_dmi_read(DMI_ADDR_DMSTATUS, 32'h000F_0C82, 32'h000F_FFFF,
                  "resumeack dmstatus over JTAG");
    resume_count++;

    // Access Register write x5 through JTAG DMI.
    core_debug.halted = 1'b1;
    core_debug.running = 1'b0;
    jtag_dmi_write(DMI_ADDR_DATA0, 32'h1357_2468, "write data0 over JTAG");
    jtag_dmi_write(DMI_ADDR_COMMAND,
                   make_access_command(ABSTRACT_AARSIZE_32, 1'b1, 1'b1,
                                       ABSTRACT_GPR_BASE + 16'd5),
                   "abstract GPR write x5 over JTAG");
    complete_gpr_access(1'b1, 5'd5, 32'h1357_2468, 32'h0, 1'b0, "JTAG GPR write");
    jtag_dmi_read(DMI_ADDR_ABSTRACTCS, 32'h0000_0002, 32'h0000_1F0F,
                  "abstractcs clean after JTAG write");
    gpr_write_count++;

    // Access Register read x6 through JTAG DMI.
    jtag_dmi_write(DMI_ADDR_COMMAND,
                   make_access_command(ABSTRACT_AARSIZE_32, 1'b1, 1'b0,
                                       ABSTRACT_GPR_BASE + 16'd6),
                   "abstract GPR read x6 over JTAG");
    complete_gpr_access(1'b0, 5'd6, 32'h0, 32'h2468_1357, 1'b0, "JTAG GPR read");
    jtag_dmi_read(DMI_ADDR_DATA0, 32'h2468_1357, 32'hFFFF_FFFF,
                  "data0 readback after JTAG GPR read");
    gpr_read_count++;

    // Access Register read of dpc through JTAG DMI returns the core-captured PC.
    core_debug.dpc = 32'h1000_0104;
    jtag_dmi_write(DMI_ADDR_COMMAND,
                   make_access_command(ABSTRACT_AARSIZE_32, 1'b1, 1'b0,
                                       ABSTRACT_CSR_DPC),
                   "abstract dpc read over JTAG");
    jtag_dmi_read(DMI_ADDR_DATA0, 32'h1000_0104, 32'hFFFF_FFFF,
                  "data0 readback after JTAG dpc read");
    csr_read_count++;

    // DCSR.step converts the next resume request into a core single-step.
    jtag_dmi_write(DMI_ADDR_DATA0,
                   ABSTRACT_CSR_DCSR_HALTED_M | ABSTRACT_CSR_DCSR_STEP_MASK,
                   "write stepped dcsr data0 over JTAG");
    jtag_dmi_write(DMI_ADDR_COMMAND,
                   make_access_command(ABSTRACT_AARSIZE_32, 1'b1, 1'b1,
                                       ABSTRACT_CSR_DCSR),
                   "abstract dcsr write over JTAG");
    wait_debug_clocks(4);
    jtag_dmi_write(DMI_ADDR_COMMAND,
                   make_access_command(ABSTRACT_AARSIZE_32, 1'b1, 1'b0,
                                       ABSTRACT_CSR_DCSR),
                   "abstract dcsr read over JTAG");
    jtag_dmi_read(DMI_ADDR_DATA0,
                  ABSTRACT_CSR_DCSR_HALTED_M | ABSTRACT_CSR_DCSR_STEP_MASK,
                  32'hFFFF_FFFF, "data0 readback after JTAG dcsr read");
    jtag_dmi_write(DMI_ADDR_DMCONTROL, 32'h4000_0001, "step resume over JTAG");
    check(core_debug.resume_req && core_debug.step_req && !core_debug.halt_req,
          "single-step request reaches core");
    core_debug.halted = 1'b0;
    core_debug.running = 1'b1;
    step_clock();
    check(!core_debug.resume_req && !core_debug.step_req,
          "single-step resume retires after running");
    core_debug.running = 1'b0;
    core_debug.halted = 1'b1;
    jtag_dmi_read(DMI_ADDR_DMSTATUS, 32'h000F_0382, 32'h000F_FFFF,
                  "halted resumeack after single-step over JTAG");
    jtag_dmi_write(DMI_ADDR_DATA0, ABSTRACT_CSR_DCSR_HALTED_M,
                   "clear stepped dcsr data0 over JTAG");
    jtag_dmi_write(DMI_ADDR_COMMAND,
                   make_access_command(ABSTRACT_AARSIZE_32, 1'b1, 1'b1,
                                       ABSTRACT_CSR_DCSR),
                   "clear dcsr step over JTAG");
    wait_debug_clocks(4);
    step_count++;

    // Hart reset sticky state and ackhavereset over JTAG.
    @(negedge clk);
    hart_reset_event = 1'b1;
    step_clock();
    hart_reset_event = 1'b0;
    jtag_dmi_read(DMI_ADDR_DMSTATUS, 32'h000C_0382, 32'h000F_FFFF,
                  "havereset set over JTAG");
    jtag_dmi_write(DMI_ADDR_DMCONTROL, 32'h1000_0001, "ack havereset over JTAG");
    jtag_dmi_read(DMI_ADDR_DMSTATUS, 32'h000C_0382 & ~32'h000C_0000,
                  32'h000C_0000, "havereset clear over JTAG");

    $display("tb_debug_jtag coverage: pass_count=%0d dmi_reads=%0d dmi_writes=%0d halt=%0d resume=%0d gpr_write=%0d gpr_read=%0d csr_read=%0d step=%0d reset=%0d",
             pass_count, jtag_dmi_reads, jtag_dmi_writes, halt_count,
             resume_count, gpr_write_count, gpr_read_count, csr_read_count,
             step_count, reset_count);
    $display("tb_debug_jtag PASS");
    $finish;
  end
endmodule
