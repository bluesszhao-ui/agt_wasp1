`timescale 1ns/1ps

// First executable integer datapath integration for the wasp1 core.
//
// This milestone wires the verified pipeline skeleton, decoder, register file,
// ALU, and writeback helper into one small executable path. It intentionally
// supports integer ALU, upper-immediate, branch/jump redirect, CSR/trap,
// valid/ready load/store requests, and load-use hazard control.
module core_int_datapath (
  input  logic        clk_i,              // Core pipeline/register clock.
  input  logic        rst_ni,             // Active-low asynchronous reset.

  input  logic        instr_valid_i,      // Frontend instruction stream valid.
  output logic        instr_ready_o,      // Datapath can accept instruction stream.
  input  logic [31:0] instr_pc_i,         // PC associated with instr_i.
  input  logic [31:0] instr_i,            // Fetched instruction word.
  input  logic        instr_fault_i,      // Fetch fault associated with instr_i.

  output logic        dmem_req_valid_o,   // Data memory request valid.
  input  logic        dmem_req_ready_i,   // Data memory accepted the request.
  output logic [31:0] dmem_req_addr_o,    // Data memory byte address.
  output logic        dmem_req_write_o,   // Data memory store qualifier.
  output logic [1:0]  dmem_req_size_o,    // Data memory access size.
  output logic [31:0] dmem_req_wdata_o,   // Data memory store data aligned to lanes.
  output logic [3:0]  dmem_req_wstrb_o,   // Data memory byte write strobes.
  input  logic        dmem_rsp_valid_i,   // Data memory response valid.
  output logic        dmem_rsp_ready_o,   // Core can accept the response.
  input  logic [31:0] dmem_rsp_rdata_i,   // Data memory read response data.
  input  logic        dmem_rsp_err_i,     // Data memory response error.
  input  logic        timer_irq_i,        // Machine timer interrupt pending.
  input  logic        external_irq_i,     // Machine external interrupt pending.
  debug_if.core       core_debug,         // Debug Module control and halted-core GPR channel.

  output logic        commit_valid_o,     // Register writeback happened this cycle.
  output logic [4:0]  commit_rd_o,        // Committed destination register.
  output logic [31:0] commit_data_o,      // Committed writeback data.
  output logic        ex_valid_o,         // Execute/writeback slot is valid.
  output logic [31:0] ex_pc_o,            // Execute/writeback slot PC.
  output logic [31:0] ex_instr_o,         // Execute/writeback slot instruction.
  output logic        illegal_o,          // Decode reported illegal instruction.
  output logic        lsu_fault_o,        // Load/store misalignment or response fault.
  output logic        trap_valid_o,       // Trap entry selected for current EX slot.
  output logic        trap_interrupt_o,   // Trap is an interrupt when asserted.
  output logic [4:0]  trap_cause_o,       // Trap cause without interrupt MSB.
  output logic [31:0] trap_tval_o,        // Trap value written to mtval.
  output logic [31:0] trap_pc_o,          // Trap PC written to mepc.
  output logic        mret_taken_o,       // MRET redirect selected.
  output logic        redirect_valid_o,   // Redirect request toward frontend.
  output logic [31:0] redirect_pc_o,      // Redirect target toward frontend.
  output logic [31:0] csr_rdata_o,        // CSR read data observed by writeback.
  output logic        hazard_load_use_o,  // Decode slot is stalled behind EX load.
  output logic        hazard_fwd_rs1_ex_o,// Hazard unit rs1 EX-forward decision.
  output logic        hazard_fwd_rs1_wb_o,// Hazard unit rs1 WB-forward decision.
  output logic        hazard_fwd_rs2_ex_o,// Hazard unit rs2 EX-forward decision.
  output logic        hazard_fwd_rs2_wb_o,// Hazard unit rs2 WB-forward decision.
  output logic        unsupported_o       // Instruction class is not integrated yet.
);
  import core_types_pkg::*;

  localparam int DEBUG_TRIGGER_COUNT = 2;

  logic        id_valid;          // IF/ID valid from core_pipe; not decoded here yet.
  logic [31:0] id_pc;             // IF/ID PC from core_pipe.
  logic [31:0] id_instr;          // IF/ID instruction from core_pipe.
  logic        id_fetch_fault;    // IF/ID fetch fault from core_pipe.
  logic        ex_valid;          // EX/WB valid from core_pipe.
  logic [31:0] ex_pc;             // EX/WB PC from core_pipe.
  logic [31:0] ex_instr;          // EX/WB instruction from core_pipe.
  logic        ex_fetch_fault;    // EX/WB fetch fault from core_pipe.

  logic [4:0]  id_dec_rd;         // Destination register decoded from ID instruction.
  logic [4:0]  id_dec_rs1;        // Source register 1 decoded from ID instruction.
  logic [4:0]  id_dec_rs2;        // Source register 2 decoded from ID instruction.
  logic [31:0] id_dec_imm;        // ID immediate, unused by hazard.
  core_imm_sel_e id_dec_imm_sel;  // ID immediate format, unused by hazard.
  logic        id_dec_uses_rs1;   // ID instruction consumes rs1.
  logic        id_dec_uses_rs2;   // ID instruction consumes rs2.
  logic        id_dec_writes_rd;  // ID instruction writes rd.
  logic        id_dec_alu_valid;  // ID ALU qualifier, unused by hazard.
  core_alu_op_e id_dec_alu_op;    // ID ALU op, unused by hazard.
  logic        id_dec_alu_src_imm;// ID ALU immediate flag, unused by hazard.
  logic        id_dec_load;       // ID load qualifier, unused by hazard.
  logic        id_dec_store;      // ID store qualifier, unused by hazard.
  core_lsu_size_e id_dec_lsu_size;// ID LSU size, unused by hazard.
  logic        id_dec_lsu_unsigned;// ID LSU unsigned flag, unused by hazard.
  logic        id_dec_branch;     // ID branch qualifier, unused by hazard.
  core_branch_e id_dec_branch_op; // ID branch op, unused by hazard.
  logic        id_dec_jal;        // ID JAL qualifier, unused by hazard.
  logic        id_dec_jalr;       // ID JALR qualifier, unused by hazard.
  logic        id_dec_lui;        // ID LUI qualifier, unused by hazard.
  logic        id_dec_auipc;      // ID AUIPC qualifier, unused by hazard.
  logic        id_dec_csr;        // ID CSR qualifier, unused by hazard.
  core_csr_cmd_e id_dec_csr_cmd;  // ID CSR command, unused by hazard.
  logic [11:0] id_dec_csr_addr;   // ID CSR address, unused by hazard.
  logic        id_dec_ecall;      // ID ECALL qualifier, unused by hazard.
  logic        id_dec_ebreak;     // ID EBREAK qualifier, unused by hazard.
  logic        id_dec_mret;       // ID MRET qualifier, unused by hazard.
  logic        id_dec_illegal;    // ID illegal decode, unused by hazard.

  logic [4:0]  dec_rd;            // Destination register decoded from EX instruction.
  logic [4:0]  dec_rs1;           // Source register 1 decoded from EX instruction.
  logic [4:0]  dec_rs2;           // Source register 2 decoded from EX instruction.
  logic [31:0] dec_imm;           // Decoded immediate for EX instruction.
  core_imm_sel_e dec_imm_sel;     // Immediate format, exposed for completeness.
  logic        dec_uses_rs1;      // EX instruction consumes rs1.
  logic        dec_uses_rs2;      // EX instruction consumes rs2.
  logic        dec_writes_rd;     // EX instruction writes rd in the full ISA.
  logic        dec_alu_valid;     // EX instruction uses ALU op encoding.
  core_alu_op_e dec_alu_op;       // ALU operation selector.
  logic        dec_alu_src_imm;   // ALU rhs immediate selector.
  logic        dec_load;          // Load class, not integrated in this milestone.
  logic        dec_store;         // Store class, not integrated in this milestone.
  core_lsu_size_e dec_lsu_size;   // LSU size, unused until LSU integration.
  logic        dec_lsu_unsigned;  // LSU unsigned flag, unused until LSU integration.
  logic        dec_branch;        // Branch class, redirect not integrated yet.
  core_branch_e dec_branch_op;    // Branch op, unused until branch integration.
  logic        dec_jal;           // JAL class; link writeback is integrated.
  logic        dec_jalr;          // JALR class; link writeback is integrated.
  logic        dec_lui;           // LUI class.
  logic        dec_auipc;         // AUIPC class.
  logic        dec_csr;           // CSR class, not integrated in this milestone.
  core_csr_cmd_e dec_csr_cmd;     // CSR command, unused until CSR integration.
  logic [11:0] dec_csr_addr;      // CSR address, unused until CSR integration.
  logic        dec_ecall;         // ECALL, not integrated in this milestone.
  logic        dec_ebreak;        // EBREAK, not integrated in this milestone.
  logic        dec_mret;          // MRET, not integrated in this milestone.
  logic        dec_illegal;       // Illegal instruction indication from decode.

  logic [31:0] rs1_data;          // Register file rs1 read data.
  logic [31:0] rs2_data;          // Register file rs2 read data.
  logic [31:0] alu_lhs;           // ALU left operand.
  logic [31:0] alu_rhs;           // ALU right operand.
  logic [31:0] alu_result;        // ALU result.
  logic        branch_taken;      // Branch helper redirect request.
  logic [31:0] branch_target;     // Branch helper redirect target.
  logic [31:0] branch_link;       // Branch helper link value, ex_pc + 4.
  logic        redirect_valid;    // Redirect request after fault/illegal gating.
  logic        pipe_redirect_valid;// Final redirect request into core_pipe.
  logic [31:0] pipe_redirect_pc;   // Final redirect target into core_pipe.
  logic [31:0] lsu_load_data;     // Load data after byte/half extension.
  logic        lsu_misaligned;    // Load/store alignment fault from LSU.
  logic        lsu_fault;         // Combined local/memory LSU helper fault.
  logic        lsu_active_fault;  // LSU fault qualified by a load/store op.
  logic        lsu_mem_op;        // Current EX slot is an aligned LSU candidate.
  logic        lsu_req_valid_raw; // LSU helper request before outstanding gating.
  logic [31:0] lsu_req_addr;      // LSU helper byte address before debug muxing.
  logic        lsu_req_write;     // LSU helper write qualifier before debug muxing.
  logic [1:0]  lsu_req_size;      // LSU helper size before debug muxing.
  logic [31:0] lsu_req_wdata;     // LSU helper write data before debug muxing.
  logic [3:0]  lsu_req_wstrb;     // LSU helper byte strobes before debug muxing.
  logic        lsu_req_outstanding_q;// Data request accepted, waiting response.
  logic        lsu_req_fire;      // Data request handshake completed.
  logic        lsu_rsp_fire;      // Data response handshake completed.
  logic        lsu_wait_stall;    // Hold pipeline while LSU request/response waits.
  logic        lsu_complete;      // LSU op is complete for retire/writeback.
  logic        retire_valid;      // Current EX instruction can retire this cycle.
  logic [31:0] csr_wdata;         // CSR write data from rs1 or zero-extended zimm.
  logic [31:0] csr_rdata;         // CSR old value returned for rd writeback.
  logic        csr_illegal;       // CSR access fault from core_csr.
  logic [31:0] mtvec;             // Trap vector base from core_csr.
  logic [31:0] mepc;              // MRET target from core_csr.
  logic        mie_global;        // Global M-mode interrupt enable.
  logic        mtie;              // Timer interrupt enable.
  logic        meie;              // External interrupt enable.
  logic        mtip;              // Timer interrupt pending reflection.
  logic        meip;              // External interrupt pending reflection.
  logic        trap_valid;        // Trap selected by core_trap.
  logic        trap_interrupt;    // Trap is interrupt.
  logic [4:0]  trap_cause;        // Trap cause without interrupt MSB.
  logic [31:0] trap_tval;         // Trap value for mtval.
  logic [31:0] trap_pc;           // Trap PC for mepc.
  logic        mret_taken;        // MRET redirect selected.
  logic        trap_redirect;     // Trap/MRET redirect selected by core_trap.
  logic [31:0] trap_redirect_pc;  // Trap/MRET redirect target.
  logic [31:0] auipc_result;      // PC-relative AUIPC result.
  core_wb_sel_e wb_sel;           // Writeback source selector.
  logic        wb_rd_write;       // Final write intent before x0/fault suppression.
  logic        rf_we;             // Register file write enable from writeback helper.
  logic [4:0]  rf_waddr;          // Register file write address.
  logic [31:0] rf_wdata;          // Register file write data.
  logic        unsupported;       // Instruction class not connected yet.
  logic        write_fault;       // Any condition that suppresses architectural writeback.
  logic        hazard_rs1_fwd_ex; // Hazard unit rs1 EX-forward indication.
  logic        hazard_rs1_fwd_wb; // Hazard unit rs1 WB-forward indication.
  logic        hazard_rs2_fwd_ex; // Hazard unit rs2 EX-forward indication.
  logic        hazard_rs2_fwd_wb; // Hazard unit rs2 WB-forward indication.
  logic        hazard_load_use;   // Load-use hazard between ID and EX.
  logic        hazard_fetch_stall;// Fetch stall from hazard unit.
  logic        hazard_decode_stall;// Decode stall from hazard unit.
  logic        hazard_execute_bubble;// Execute bubble from hazard unit.
  logic        pipe_fetch_stall;  // Final fetch stall into core_pipe.
  logic        pipe_decode_stall; // Final decode stall into core_pipe.
  logic        pipe_execute_bubble;// Final execute bubble into core_pipe.
  logic        debug_stop_fetch;   // Debug halt request stops new frontend accepts.
  logic        debug_freeze_pipe;  // Debug halted state freezes the drained pipe.
  logic        debug_halted;       // Core is halted and can accept GPR debug access.
  logic        debug_running;      // Core is running or executing a debug step.
  logic        debug_pipe_idle;    // IF/ID, EX/WB, and LSU outstanding state are empty.
  logic        debug_gpr_req_fire; // Halted GPR request handshake.
  logic        debug_gpr_write_fire;// Halted GPR write request accepted.
  logic        debug_gpr_rsp_valid_q;// Registered GPR response valid.
  logic [31:0] debug_gpr_rsp_rdata_q;// Registered GPR read response payload.
  logic        debug_gpr_rsp_err_q; // Registered GPR response error.
  logic        debug_mem_req_fire;  // Halted debug memory request accepted by dmem.
  logic        debug_mem_rsp_fire;  // Dmem response belongs to debug memory request.
  logic        debug_mem_req_active;// Debug memory channel currently drives dmem.
  logic        debug_mem_rsp_valid_q;// Registered debug memory response valid.
  logic [31:0] debug_mem_rsp_rdata_q;// Registered debug memory response payload.
  logic        debug_mem_rsp_err_q; // Registered debug memory response error.
  logic        debug_mem_req_outstanding_q;// Debug memory request waits for dmem rsp.
  logic        debug_busy;         // Debug GPR response is pending or being created.
  logic        debug_resume_redirect;// Resume/step redirects frontend to captured DPC.
  logic [DEBUG_TRIGGER_COUNT-1:0] debug_trigger_match; // Per-slot execute trigger compare hit.
  logic        debug_trigger_halt;  // Execute-address trigger requests Debug Mode entry.
  logic [31:0] debug_trigger_pc;    // Matched trigger PC captured into DPC.
  logic [31:0] debug_next_pc_q;    // Resume PC candidate updated by accepted fetches/retire.
  logic [31:0] debug_dpc_q;        // DPC value captured while the hart is halted.
  logic [2:0]  debug_dcsr_cause_q; // DCSR cause for the latest Debug Mode entry.
  logic [31:0] debug_retire_next_pc;// Next PC implied by the retiring instruction.
  logic [4:0]  regfile_raddr1;     // Read port 1 address after debug muxing.
  logic        regfile_we;         // Register file write enable after debug muxing.
  logic [4:0]  regfile_waddr;      // Register file write address after debug muxing.
  logic [31:0] regfile_wdata;      // Register file write data after debug muxing.

  assign lsu_mem_op = ex_valid && (dec_load || dec_store) &&
                      !ex_fetch_fault && !dec_illegal;
  assign lsu_req_fire = lsu_req_valid_raw && !lsu_req_outstanding_q &&
                        !debug_mem_req_active && dmem_req_ready_i;
  assign dmem_rsp_ready_o = lsu_req_outstanding_q || lsu_req_fire ||
                            debug_mem_req_outstanding_q || debug_mem_req_fire;
  assign lsu_rsp_fire = dmem_rsp_valid_i &&
                        (lsu_req_outstanding_q || lsu_req_fire);
  assign lsu_complete = !lsu_mem_op || lsu_misaligned || lsu_rsp_fire;
  assign lsu_wait_stall = lsu_mem_op && !lsu_misaligned && !lsu_rsp_fire;
  assign retire_valid = ex_valid && lsu_complete;
  assign debug_pipe_idle = !id_valid && !ex_valid && !lsu_req_outstanding_q;
  assign debug_gpr_req_fire = core_debug.gpr_req_valid &&
                              core_debug.gpr_req_ready;
  assign debug_gpr_write_fire = debug_gpr_req_fire &&
                                core_debug.gpr_req_write;
  assign debug_mem_req_active = debug_halted && core_debug.mem_req_valid &&
                                !debug_mem_rsp_valid_q &&
                                !debug_mem_req_outstanding_q;
  assign debug_mem_req_fire = debug_mem_req_active && dmem_req_ready_i;
  assign debug_mem_rsp_fire = dmem_rsp_valid_i &&
                              (debug_mem_req_outstanding_q ||
                               debug_mem_req_fire);
  assign debug_busy = debug_gpr_rsp_valid_q || debug_gpr_req_fire ||
                      debug_mem_rsp_valid_q || debug_mem_req_active ||
                      debug_mem_req_outstanding_q;
  assign debug_resume_redirect = debug_halted && core_debug.resume_req &&
                                 !core_debug.halt_req && !debug_busy;
  assign debug_trigger_pc = id_pc;
  for (genvar trig_idx = 0; trig_idx < DEBUG_TRIGGER_COUNT; trig_idx++) begin : gen_debug_trigger_match
    assign debug_trigger_match[trig_idx] =
        core_debug.trigger_execute_valid[trig_idx] &&
        (id_pc == core_debug.trigger_execute_addr[trig_idx]);
  end
  assign debug_trigger_halt = id_valid && (|debug_trigger_match) &&
                              !debug_halted && !core_debug.halt_req &&
                              !debug_freeze_pipe && !lsu_req_outstanding_q &&
                              (!ex_valid || retire_valid);
  assign pipe_fetch_stall = hazard_fetch_stall || lsu_wait_stall ||
                            debug_stop_fetch;
  assign pipe_decode_stall = hazard_decode_stall || lsu_wait_stall ||
                             debug_freeze_pipe;
  assign pipe_execute_bubble = hazard_execute_bubble && !lsu_wait_stall &&
                               !debug_freeze_pipe;

  core_debug_ctrl debug_ctrl_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .halt_req_i(core_debug.halt_req),
    .trigger_req_i(debug_trigger_halt),
    .resume_req_i(core_debug.resume_req),
    .step_req_i(core_debug.step_req),
    .pipe_idle_i(debug_pipe_idle),
    .retire_valid_i(retire_valid),
    .debug_busy_i(debug_busy),
    .stop_fetch_o(debug_stop_fetch),
    .freeze_pipe_o(debug_freeze_pipe),
    .halted_o(debug_halted),
    .running_o(debug_running)
  );

  assign core_debug.halted = debug_halted;
  assign core_debug.running = debug_running;
  assign core_debug.dpc = debug_dpc_q;
  assign core_debug.dcsr_cause = debug_dcsr_cause_q;
  assign core_debug.gpr_req_ready = debug_halted && !debug_gpr_rsp_valid_q;
  assign core_debug.gpr_rsp_valid = debug_gpr_rsp_valid_q;
  assign core_debug.gpr_rsp_rdata = debug_gpr_rsp_rdata_q;
  assign core_debug.gpr_rsp_err = debug_gpr_rsp_err_q;
  assign core_debug.mem_req_ready = debug_mem_req_active && dmem_req_ready_i;
  assign core_debug.mem_rsp_valid = debug_mem_rsp_valid_q;
  assign core_debug.mem_rsp_rdata = debug_mem_rsp_rdata_q;
  assign core_debug.mem_rsp_err = debug_mem_rsp_err_q;
  assign regfile_raddr1 = debug_halted ? core_debug.gpr_req_addr : dec_rs1;
  assign regfile_we = debug_gpr_write_fire ? 1'b1 : rf_we;
  assign regfile_waddr = debug_gpr_write_fire ? core_debug.gpr_req_addr :
                                                rf_waddr;
  assign regfile_wdata = debug_gpr_write_fire ? core_debug.gpr_req_wdata :
                                                rf_wdata;

  // DPC tracks the PC at which execution would resume after Debug Mode. Fetch
  // acceptance seeds the value before the first retirement, while each retiring
  // instruction updates it with the architectural next PC including redirects.
  assign debug_retire_next_pc = trap_redirect ? trap_redirect_pc :
                                (redirect_valid ? branch_target :
                                                  (ex_pc + 32'd4));

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      debug_next_pc_q <= 32'h0000_0000;
      debug_dpc_q <= 32'h0000_0000;
      debug_dcsr_cause_q <= 3'd3;
    end else begin
      if (debug_trigger_halt) begin
        debug_next_pc_q <= debug_trigger_pc;
        debug_dcsr_cause_q <= 3'd2;
      end else if (instr_valid_i && instr_ready_o && !id_valid && !ex_valid &&
          !lsu_req_outstanding_q) begin
        debug_next_pc_q <= instr_pc_i;
      end

      if (!debug_trigger_halt && retire_valid) begin
        debug_next_pc_q <= debug_retire_next_pc;
      end

      if (debug_halted && core_debug.step_req && !debug_busy) begin
        debug_dcsr_cause_q <= 3'd4;
      end else if (!debug_halted && core_debug.halt_req) begin
        debug_dcsr_cause_q <= 3'd3;
      end

      // Capture DPC both while halted and on the edge that enters Debug Mode.
      // OpenOCD may read DPC immediately after dmstatus.allhalted becomes set.
      if (debug_halted || (debug_stop_fetch && debug_pipe_idle && !debug_busy)) begin
        debug_dpc_q <= debug_next_pc_q;
      end
    end
  end

  // The halted-memory debug channel returns one registered response per
  // accepted request. Requests reuse the normal D-cache/core AHB path only
  // while the pipeline is drained and Debug Mode is active.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      debug_mem_req_outstanding_q <= 1'b0;
      debug_mem_rsp_valid_q <= 1'b0;
      debug_mem_rsp_rdata_q <= 32'h0000_0000;
      debug_mem_rsp_err_q <= 1'b0;
    end else begin
      if (debug_mem_rsp_valid_q && core_debug.mem_rsp_ready) begin
        debug_mem_rsp_valid_q <= 1'b0;
      end

      if (debug_mem_rsp_fire) begin
        debug_mem_req_outstanding_q <= 1'b0;
        debug_mem_rsp_valid_q <= 1'b1;
        debug_mem_rsp_rdata_q <= dmem_rsp_rdata_i;
        debug_mem_rsp_err_q <= dmem_rsp_err_i;
      end else if (debug_mem_req_fire) begin
        debug_mem_req_outstanding_q <= 1'b1;
      end
    end
  end

  // The halted GPR channel returns one registered response per accepted
  // request. Reads capture the muxed regfile read port; writes use the same
  // rising edge as the response capture and report success unless reset wins.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      debug_gpr_rsp_valid_q <= 1'b0;
      debug_gpr_rsp_rdata_q <= 32'h0000_0000;
      debug_gpr_rsp_err_q <= 1'b0;
    end else begin
      if (debug_gpr_rsp_valid_q && core_debug.gpr_rsp_ready) begin
        debug_gpr_rsp_valid_q <= 1'b0;
      end

      if (debug_gpr_req_fire) begin
        debug_gpr_rsp_valid_q <= 1'b1;
        debug_gpr_rsp_rdata_q <= core_debug.gpr_req_write ? 32'h0000_0000 :
                                                            rs1_data;
        debug_gpr_rsp_err_q <= 1'b0;
      end
    end
  end

  // Track the single outstanding data transaction owned by this in-order
  // datapath. The pipeline is held while this bit is set, so no second data
  // request can be issued until the response returns.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lsu_req_outstanding_q <= 1'b0;
    end else if (lsu_rsp_fire) begin
      lsu_req_outstanding_q <= 1'b0;
    end else if (lsu_req_fire) begin
      lsu_req_outstanding_q <= 1'b1;
    end
  end

  core_pipe pipe_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .instr_valid_i(instr_valid_i),
    .instr_ready_o(instr_ready_o),
    .instr_pc_i(instr_pc_i),
    .instr_i(instr_i),
    .instr_fault_i(instr_fault_i),
    .fetch_stall_i(pipe_fetch_stall),
    .decode_stall_i(pipe_decode_stall),
    .execute_bubble_i(pipe_execute_bubble),
    .redirect_valid_i(pipe_redirect_valid),
    .redirect_pc_i(pipe_redirect_pc),
    .redirect_valid_o(redirect_valid_o),
    .redirect_pc_o(redirect_pc_o),
    .id_valid_o(id_valid),
    .id_pc_o(id_pc),
    .id_instr_o(id_instr),
    .id_fetch_fault_o(id_fetch_fault),
    .ex_valid_o(ex_valid),
    .ex_pc_o(ex_pc),
    .ex_instr_o(ex_instr),
    .ex_fetch_fault_o(ex_fetch_fault)
  );

  core_decode decode_u (
    .instr_i(ex_instr),
    .rd_o(dec_rd),
    .rs1_o(dec_rs1),
    .rs2_o(dec_rs2),
    .imm_o(dec_imm),
    .imm_sel_o(dec_imm_sel),
    .uses_rs1_o(dec_uses_rs1),
    .uses_rs2_o(dec_uses_rs2),
    .writes_rd_o(dec_writes_rd),
    .alu_valid_o(dec_alu_valid),
    .alu_op_o(dec_alu_op),
    .alu_src_imm_o(dec_alu_src_imm),
    .load_o(dec_load),
    .store_o(dec_store),
    .lsu_size_o(dec_lsu_size),
    .lsu_unsigned_o(dec_lsu_unsigned),
    .branch_o(dec_branch),
    .branch_op_o(dec_branch_op),
    .jal_o(dec_jal),
    .jalr_o(dec_jalr),
    .lui_o(dec_lui),
    .auipc_o(dec_auipc),
    .csr_o(dec_csr),
    .csr_cmd_o(dec_csr_cmd),
    .csr_addr_o(dec_csr_addr),
    .ecall_o(dec_ecall),
    .ebreak_o(dec_ebreak),
    .mret_o(dec_mret),
    .illegal_o(dec_illegal)
  );

  core_decode id_decode_u (
    .instr_i(id_instr),
    .rd_o(id_dec_rd),
    .rs1_o(id_dec_rs1),
    .rs2_o(id_dec_rs2),
    .imm_o(id_dec_imm),
    .imm_sel_o(id_dec_imm_sel),
    .uses_rs1_o(id_dec_uses_rs1),
    .uses_rs2_o(id_dec_uses_rs2),
    .writes_rd_o(id_dec_writes_rd),
    .alu_valid_o(id_dec_alu_valid),
    .alu_op_o(id_dec_alu_op),
    .alu_src_imm_o(id_dec_alu_src_imm),
    .load_o(id_dec_load),
    .store_o(id_dec_store),
    .lsu_size_o(id_dec_lsu_size),
    .lsu_unsigned_o(id_dec_lsu_unsigned),
    .branch_o(id_dec_branch),
    .branch_op_o(id_dec_branch_op),
    .jal_o(id_dec_jal),
    .jalr_o(id_dec_jalr),
    .lui_o(id_dec_lui),
    .auipc_o(id_dec_auipc),
    .csr_o(id_dec_csr),
    .csr_cmd_o(id_dec_csr_cmd),
    .csr_addr_o(id_dec_csr_addr),
    .ecall_o(id_dec_ecall),
    .ebreak_o(id_dec_ebreak),
    .mret_o(id_dec_mret),
    .illegal_o(id_dec_illegal)
  );

  core_hazard hazard_u (
    .id_valid_i(id_valid && !id_fetch_fault),
    .id_rs1_i(id_dec_rs1),
    .id_uses_rs1_i(id_dec_uses_rs1),
    .id_rs2_i(id_dec_rs2),
    .id_uses_rs2_i(id_dec_uses_rs2),
    .ex_valid_i(ex_valid && !ex_fetch_fault),
    .ex_rd_i(dec_rd),
    .ex_writes_rd_i(wb_rd_write && !write_fault && !trap_valid && !mret_taken),
    .ex_is_load_i(dec_load),
    .wb_valid_i(rf_we),
    .wb_rd_i(rf_waddr),
    .wb_writes_rd_i(rf_we),
    .rs1_forward_ex_o(hazard_rs1_fwd_ex),
    .rs1_forward_wb_o(hazard_rs1_fwd_wb),
    .rs2_forward_ex_o(hazard_rs2_fwd_ex),
    .rs2_forward_wb_o(hazard_rs2_fwd_wb),
    .load_use_stall_o(hazard_load_use),
    .fetch_stall_o(hazard_fetch_stall),
    .decode_stall_o(hazard_decode_stall),
    .execute_bubble_o(hazard_execute_bubble)
  );

  core_regfile #(
    .BYPASS_EN(1'b0)
  ) regfile_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .raddr1_i(regfile_raddr1),
    .rdata1_o(rs1_data),
    .raddr2_i(dec_rs2),
    .rdata2_o(rs2_data),
    .we_i(regfile_we),
    .waddr_i(regfile_waddr),
    .wdata_i(regfile_wdata)
  );

  // AUIPC uses the PC as the left operand even though decode does not mark it
  // as a normal ALU instruction. JAL/JALR link writes use core_wb PC+4 path.
  assign alu_lhs = dec_auipc ? ex_pc : rs1_data;
  assign alu_rhs = (dec_alu_src_imm || dec_auipc) ? dec_imm : rs2_data;

  core_alu alu_u (
    .op_i(dec_alu_op),
    .lhs_i(alu_lhs),
    .rhs_i(alu_rhs),
    .result_o(alu_result)
  );

  core_branch branch_u (
    .pc_i(ex_pc),
    .rs1_i(rs1_data),
    .rs2_i(rs2_data),
    .imm_i(dec_imm),
    .branch_i(dec_branch),
    .branch_op_i(dec_branch_op),
    .jal_i(dec_jal),
    .jalr_i(dec_jalr),
    .taken_o(branch_taken),
    .target_o(branch_target),
    .link_o(branch_link)
  );

  core_lsu lsu_u (
    .base_i(rs1_data),
    .imm_i(dec_imm),
    .store_data_i(rs2_data),
    .size_i(dec_lsu_size),
    .unsigned_i(dec_lsu_unsigned),
    .load_i(lsu_mem_op && dec_load),
    .store_i(lsu_mem_op && dec_store),
    .rsp_rdata_i(dmem_rsp_rdata_i),
    .rsp_err_i(dmem_rsp_err_i && lsu_rsp_fire),
    .req_valid_o(lsu_req_valid_raw),
    .req_addr_o(lsu_req_addr),
    .req_write_o(lsu_req_write),
    .req_size_o(lsu_req_size),
    .req_wdata_o(lsu_req_wdata),
    .req_wstrb_o(lsu_req_wstrb),
    .load_data_o(lsu_load_data),
    .misaligned_o(lsu_misaligned),
    .fault_o(lsu_fault)
  );

  assign dmem_req_valid_o = debug_mem_req_active ||
                            (lsu_req_valid_raw && !lsu_req_outstanding_q);
  assign dmem_req_addr_o = debug_mem_req_active ? core_debug.mem_req_addr :
                                                  lsu_req_addr;
  assign dmem_req_write_o = debug_mem_req_active ? core_debug.mem_req_write :
                                                   lsu_req_write;
  assign dmem_req_size_o = debug_mem_req_active ? core_debug.mem_req_size :
                                                  lsu_req_size;
  assign dmem_req_wdata_o = debug_mem_req_active ? core_debug.mem_req_wdata :
                                                   lsu_req_wdata;
  assign dmem_req_wstrb_o = debug_mem_req_active ? core_debug.mem_req_wstrb :
                                                   lsu_req_wstrb;

  assign csr_wdata = dec_csr_cmd[2] ? dec_imm : rs1_data;

  core_csr csr_u (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .csr_valid_i(ex_valid && dec_csr && !ex_fetch_fault && !dec_illegal),
    .csr_cmd_i(dec_csr_cmd),
    .csr_addr_i(dec_csr_addr),
    .csr_wdata_i(csr_wdata),
    .csr_rdata_o(csr_rdata),
    .csr_illegal_o(csr_illegal),
    .retire_i(retire_valid && !write_fault && !trap_valid),
    .trap_valid_i(trap_valid),
    .trap_interrupt_i(trap_interrupt),
    .trap_cause_i(trap_cause),
    .trap_pc_i(trap_pc),
    .trap_tval_i(trap_tval),
    .mret_i(ex_valid && mret_taken),
    .timer_irq_i(timer_irq_i),
    .external_irq_i(external_irq_i),
    .mtvec_o(mtvec),
    .mepc_o(mepc),
    .mie_global_o(mie_global),
    .mtie_o(mtie),
    .meie_o(meie),
    .mtip_o(mtip),
    .meip_o(meip)
  );

  core_trap trap_u (
    .valid_i(retire_valid),
    .pc_i(ex_pc),
    .instr_i(ex_instr),
    .instr_misaligned_i(1'b0),
    .instr_fault_addr_i(32'h0000_0000),
    .illegal_instr_i(dec_illegal),
    .csr_illegal_i(csr_illegal),
    .ecall_i(dec_ecall),
    .ebreak_i(dec_ebreak),
    .load_i(dec_load),
    .store_i(dec_store),
    .lsu_misaligned_i(lsu_misaligned),
    .lsu_fault_addr_i(dmem_req_addr_o),
    .mret_i(dec_mret),
    .mie_global_i(mie_global),
    .mtie_i(mtie),
    .meie_i(meie),
    .mtip_i(mtip),
    .meip_i(meip),
    .mtvec_i(mtvec),
    .mepc_i(mepc),
    .trap_valid_o(trap_valid),
    .trap_interrupt_o(trap_interrupt),
    .trap_cause_o(trap_cause),
    .trap_tval_o(trap_tval),
    .trap_pc_o(trap_pc),
    .mret_taken_o(mret_taken),
    .redirect_valid_o(trap_redirect),
    .redirect_pc_o(trap_redirect_pc)
  );

  assign auipc_result = ex_pc + dec_imm;
  assign lsu_active_fault = lsu_mem_op && lsu_fault;
  assign redirect_valid = retire_valid && branch_taken && !ex_fetch_fault &&
                          !dec_illegal && !lsu_active_fault;
  assign pipe_redirect_valid = trap_redirect || redirect_valid ||
                               debug_resume_redirect || debug_trigger_halt;
  assign pipe_redirect_pc = trap_redirect ? trap_redirect_pc :
                            (redirect_valid ? branch_target :
                             (debug_trigger_halt ? debug_trigger_pc :
                                                   debug_dpc_q));

  // Select writeback source for the instruction classes integrated in this
  // milestone. Unsupported classes are allowed through decode for observability
  // but suppress architectural writeback below.
  always_comb begin
    wb_sel = CORE_WB_ALU;
    if (dec_lui) begin
      wb_sel = CORE_WB_IMM;
    end else if (dec_load) begin
      wb_sel = CORE_WB_LOAD;
    end else if (dec_csr) begin
      wb_sel = CORE_WB_CSR;
    end else if (dec_jal || dec_jalr) begin
      wb_sel = CORE_WB_PC4;
    end else begin
      wb_sel = CORE_WB_ALU;
    end
  end

  assign unsupported = 1'b0;
  assign wb_rd_write = dec_writes_rd && (dec_alu_valid || dec_lui ||
                       dec_auipc || dec_jal || dec_jalr || dec_load ||
                       dec_csr);
  assign write_fault = ex_fetch_fault || dec_illegal || unsupported ||
                       lsu_active_fault || csr_illegal;

  core_wb wb_u (
    .wb_valid_i(retire_valid),
    .rd_i(dec_rd),
    .rd_write_i(wb_rd_write),
    .wb_sel_i(wb_sel),
    .trap_i(trap_valid || mret_taken),
    .fault_i(write_fault),
    .alu_result_i(dec_auipc ? auipc_result : alu_result),
    .load_data_i(lsu_load_data),
    .csr_rdata_i(csr_rdata),
    .pc_plus4_i(branch_link),
    .imm_u_i(dec_imm),
    .rf_we_o(rf_we),
    .rf_waddr_o(rf_waddr),
    .rf_wdata_o(rf_wdata)
  );

  assign commit_valid_o = rf_we;
  assign commit_rd_o = rf_waddr;
  assign commit_data_o = rf_wdata;
  assign ex_valid_o = ex_valid;
  assign ex_pc_o = ex_pc;
  assign ex_instr_o = ex_instr;
  assign illegal_o = retire_valid && dec_illegal;
  assign lsu_fault_o = retire_valid && lsu_active_fault;
  assign trap_valid_o = trap_valid;
  assign trap_interrupt_o = trap_interrupt;
  assign trap_cause_o = trap_cause;
  assign trap_tval_o = trap_tval;
  assign trap_pc_o = trap_pc;
  assign mret_taken_o = mret_taken;
  assign csr_rdata_o = csr_rdata;
  assign hazard_load_use_o = hazard_load_use;
  assign hazard_fwd_rs1_ex_o = hazard_rs1_fwd_ex;
  assign hazard_fwd_rs1_wb_o = hazard_rs1_fwd_wb;
  assign hazard_fwd_rs2_ex_o = hazard_rs2_fwd_ex;
  assign hazard_fwd_rs2_wb_o = hazard_rs2_fwd_wb;
  assign unsupported_o = retire_valid && unsupported;

  // These decoded controls are intentionally unused in this staged datapath.
  // Keeping them named documents the integration boundary for the next steps.
  logic unused_decode_controls;
  assign unused_decode_controls = id_pc[0] ^ id_dec_rd[0] ^ id_dec_imm[0] ^
                                  id_dec_imm_sel[0] ^ id_dec_writes_rd ^
                                  id_dec_alu_valid ^ id_dec_alu_op[0] ^
                                  id_dec_alu_src_imm ^ id_dec_load ^
                                  id_dec_store ^ id_dec_lsu_size[0] ^
                                  id_dec_lsu_unsigned ^ id_dec_branch ^
                                  id_dec_branch_op[0] ^ id_dec_jal ^
                                  id_dec_jalr ^ id_dec_lui ^
                                  id_dec_auipc ^ id_dec_csr ^
                                  id_dec_csr_cmd[0] ^ id_dec_csr_addr[0] ^
                                  id_dec_ecall ^ id_dec_ebreak ^
                                  id_dec_mret ^ id_dec_illegal ^
                                  dec_uses_rs1 ^ dec_uses_rs2 ^
                                  lsu_misaligned ^ dec_csr_cmd[0] ^
                                  dec_csr_addr[0] ^ dec_imm_sel[0] ^
                                  dmem_rsp_err_i;
endmodule
