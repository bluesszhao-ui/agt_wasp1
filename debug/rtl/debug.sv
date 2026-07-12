`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Stage-1 single-hart RISC-V Debug Module top.
//
// This wrapper connects the verified DMI register file, halt/resume
// controller, Access Register abstract-command decoder, and halted-core GPR
// access sequencer. The external JTAG DTM/TAP is intentionally not included in
// this boundary; it will drive the DMI ready/valid interface in a later stage.
module debug (
  input  logic       clk_i,              // Debug Module clock shared with DMI/core-debug channels.
  input  logic       rst_ni,             // Active-low asynchronous Debug Module reset.
  debug_dmi_if.dm    dmi,                // DMI request/response channel from the future JTAG DTM.
  debug_if.dm        core_debug,         // Halt/resume and GPR debug channel to the single core.
  input  logic       hart_reset_event_i, // One-cycle hart reset observation for dmstatus.havereset.
  output logic       dmactive_o,         // Debug Module active state, useful for SoC reset/debug glue.
  output logic       ndmreset_o          // Non-debug module reset request from dmcontrol.ndmreset.
);
  logic        dmactive;             // dmcontrol.dmactive from the register file.
  logic        ndmreset;             // dmcontrol.ndmreset after dmactive gating.
  logic        haltreq;              // Selected-hart halt request from dmcontrol.
  logic        resumereq;            // Selected-hart resume request from dmcontrol.
  logic        ackhavereset;         // Pulse clearing sticky havereset in halt_ctrl.
  logic        hart_halted;          // Halt-controller view of selected hart halted state.
  logic        hart_running;         // Halt-controller view of selected hart running state.
  logic        hart_resumeack;       // Sticky resume acknowledgement to dmstatus.
  logic        hart_havereset;       // Sticky reset observation to dmstatus.
  logic        core_halt_req;        // Halt request level driven to core_debug.
  logic        core_resume_req;      // Resume request level driven to core_debug.
  logic        dcsr_step;            // Latched DCSR.step bit for single-step resume.

  logic        command_valid;        // Accepted DMI command write pulse.
  logic [31:0] command;              // Raw abstract command register value.
  logic [31:0] data0;                // Shared abstract data register value.
  logic [31:0] data1;                // Shared abstract memory address register.
  logic [debug_dmi_pkg::PROGBUF_WORD_COUNT-1:0][31:0] progbuf_words; // Stored future Program Buffer image.
  logic        abstract_busy;        // Abstract command executor is not idle.
  logic        command_error_valid;  // Abstract executor has nonzero cmderr update.
  logic [2:0]  command_error;        // cmderr value from abstract executor.
  logic        data0_we;             // Abstract executor writes data0 on read success.
  logic [31:0] data0_wdata;          // Abstract executor read result for data0.
  logic        data1_we;             // Abstract executor writes data1 on postincrement.
  logic [31:0] data1_wdata;          // Abstract executor postincremented address.

  logic        reg_cmd_valid;        // Decoded GPR command request to reg_access.
  logic        reg_cmd_ready;        // reg_access accepted decoded GPR command.
  logic        reg_cmd_write;        // One writes GPR; zero reads GPR.
  logic [4:0]  reg_cmd_addr;         // Integer register index x0-x31.
  logic [31:0] reg_cmd_wdata;        // GPR write payload from data0.
  logic        reg_rsp_valid;        // GPR access completion is valid.
  logic        reg_rsp_ready;        // Abstract executor accepts GPR completion.
  logic [31:0] reg_rsp_rdata;        // GPR read data from reg_access.
  logic        reg_rsp_error;        // GPR access error from reg_access/core.
  logic        reg_flush;            // Abort/drain reg_access on DM or hart loss.
  logic        mem_cmd_valid;        // Abstract memory request toward halted core.
  logic        mem_cmd_ready;        // Halted core accepted abstract memory request.
  logic        mem_cmd_write;        // Abstract memory write qualifier.
  logic [31:0] mem_cmd_addr;         // Abstract memory byte address.
  logic [1:0]  mem_cmd_size;         // Abstract memory byte/half/word size.
  logic [31:0] mem_cmd_wdata;        // Abstract memory lane-aligned write data.
  logic [3:0]  mem_cmd_wstrb;        // Abstract memory write byte enables.
  logic        mem_rsp_valid;        // Halted core memory response valid.
  logic        mem_rsp_ready;        // Abstract command accepts memory response.
  logic [31:0] mem_rsp_rdata;        // Halted core memory response data.
  logic        mem_rsp_error;        // Halted core memory response error.
  logic        mem_flush;            // Abort/drain memory command on DM/hart loss.
  logic [debug_dmi_pkg::ABSTRACT_TRIGGER_COUNT-1:0] trigger_execute_valid; // Per-slot execute compare enables.
  logic [debug_dmi_pkg::ABSTRACT_TRIGGER_COUNT-1:0][31:0] trigger_execute_addr; // Per-slot execute compare addresses.
  logic [debug_dmi_pkg::ABSTRACT_TRIGGER_COUNT-1:0] trigger_load_valid; // Per-slot load compare enables.
  logic [debug_dmi_pkg::ABSTRACT_TRIGGER_COUNT-1:0] trigger_store_valid; // Per-slot store compare enables.
  logic [debug_dmi_pkg::ABSTRACT_TRIGGER_COUNT-1:0][31:0] trigger_data_addr; // Per-slot load/store compare addresses.

  debug_if gpr_debug (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  assign dmactive_o = dmactive;
  assign ndmreset_o = ndmreset;

  // Hart control outputs are the only top-level drivers for these core-debug
  // controls. DCSR.step turns a resume transaction into one-instruction step.
  assign core_debug.halt_req = core_halt_req;
  assign core_debug.resume_req = core_resume_req;
  assign core_debug.step_req = core_resume_req && dcsr_step;

  // Bridge the abstract-access internal modport to the full core_debug port.
  assign gpr_debug.gpr_req_ready = core_debug.gpr_req_ready;
  assign gpr_debug.gpr_rsp_valid = core_debug.gpr_rsp_valid;
  assign gpr_debug.gpr_rsp_rdata = core_debug.gpr_rsp_rdata;
  assign gpr_debug.gpr_rsp_err = core_debug.gpr_rsp_err;
  assign core_debug.gpr_req_valid = gpr_debug.gpr_req_valid;
  assign core_debug.gpr_req_write = gpr_debug.gpr_req_write;
  assign core_debug.gpr_req_addr = gpr_debug.gpr_req_addr;
  assign core_debug.gpr_req_wdata = gpr_debug.gpr_req_wdata;
  assign core_debug.gpr_rsp_ready = gpr_debug.gpr_rsp_ready;
  assign mem_cmd_ready = core_debug.mem_req_ready;
  assign mem_rsp_valid = core_debug.mem_rsp_valid;
  assign mem_rsp_rdata = core_debug.mem_rsp_rdata;
  assign mem_rsp_error = core_debug.mem_rsp_err;
  assign core_debug.mem_req_valid = mem_cmd_valid;
  assign core_debug.mem_req_write = mem_cmd_write;
  assign core_debug.mem_req_addr = mem_cmd_addr;
  assign core_debug.mem_req_size = mem_cmd_size;
  assign core_debug.mem_req_wdata = mem_cmd_wdata;
  assign core_debug.mem_req_wstrb = mem_cmd_wstrb;
  assign core_debug.mem_rsp_ready = mem_rsp_ready;
  assign core_debug.trigger_execute_valid = trigger_execute_valid;
  assign core_debug.trigger_execute_addr = trigger_execute_addr;
  assign core_debug.trigger_load_valid = trigger_load_valid;
  assign core_debug.trigger_store_valid = trigger_store_valid;
  assign core_debug.trigger_data_addr = trigger_data_addr;

  debug_dmi_regs u_debug_dmi_regs (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
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

  debug_halt_ctrl u_debug_halt_ctrl (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .dmactive_i(dmactive),
    .haltreq_i(haltreq),
    .resumereq_i(resumereq),
    .ackhavereset_i(ackhavereset),
    .hart_reset_event_i(hart_reset_event_i),
    .core_halted_i(core_debug.halted),
    .core_running_i(core_debug.running),
    .core_halt_req_o(core_halt_req),
    .core_resume_req_o(core_resume_req),
    .hart_halted_o(hart_halted),
    .hart_running_o(hart_running),
    .hart_resumeack_o(hart_resumeack),
    .hart_havereset_o(hart_havereset)
  );

  debug_abstract_cmd u_debug_abstract_cmd (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .dmactive_i(dmactive),
    .hart_halted_i(hart_halted),
    .command_valid_i(command_valid),
    .command_i(command),
    .data0_i(data0),
    .data1_i(data1),
    .hart_dpc_i(core_debug.dpc),
    .hart_dcsr_cause_i(core_debug.dcsr_cause),
    .busy_o(abstract_busy),
    .command_error_valid_o(command_error_valid),
    .command_error_o(command_error),
    .data0_we_o(data0_we),
    .data0_wdata_o(data0_wdata),
    .data1_we_o(data1_we),
    .data1_wdata_o(data1_wdata),
    .reg_cmd_valid_o(reg_cmd_valid),
    .reg_cmd_ready_i(reg_cmd_ready),
    .reg_cmd_write_o(reg_cmd_write),
    .reg_cmd_addr_o(reg_cmd_addr),
    .reg_cmd_wdata_o(reg_cmd_wdata),
    .reg_rsp_valid_i(reg_rsp_valid),
    .reg_rsp_ready_o(reg_rsp_ready),
    .reg_rsp_rdata_i(reg_rsp_rdata),
    .reg_rsp_error_i(reg_rsp_error),
    .mem_cmd_valid_o(mem_cmd_valid),
    .mem_cmd_ready_i(mem_cmd_ready),
    .mem_cmd_write_o(mem_cmd_write),
    .mem_cmd_addr_o(mem_cmd_addr),
    .mem_cmd_size_o(mem_cmd_size),
    .mem_cmd_wdata_o(mem_cmd_wdata),
    .mem_cmd_wstrb_o(mem_cmd_wstrb),
    .mem_rsp_valid_i(mem_rsp_valid),
    .mem_rsp_ready_o(mem_rsp_ready),
    .mem_rsp_rdata_i(mem_rsp_rdata),
    .mem_rsp_error_i(mem_rsp_error),
    .dcsr_step_o(dcsr_step),
    .trigger_execute_valid_o(trigger_execute_valid),
    .trigger_execute_addr_o(trigger_execute_addr),
    .trigger_load_valid_o(trigger_load_valid),
    .trigger_store_valid_o(trigger_store_valid),
    .trigger_data_addr_o(trigger_data_addr),
    .reg_flush_o(reg_flush),
    .mem_flush_o(mem_flush)
  );

  debug_reg_access u_debug_reg_access (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(reg_flush),
    .cmd_valid_i(reg_cmd_valid),
    .cmd_ready_o(reg_cmd_ready),
    .cmd_write_i(reg_cmd_write),
    .cmd_addr_i(reg_cmd_addr),
    .cmd_wdata_i(reg_cmd_wdata),
    .rsp_valid_o(reg_rsp_valid),
    .rsp_ready_i(reg_rsp_ready),
    .rsp_rdata_o(reg_rsp_rdata),
    .rsp_error_o(reg_rsp_error),
    .core_debug(gpr_debug)
  );
endmodule
