`timescale 1ns/1ps

// wasp1 CPU tile integration wrapper.
//
// The tile structurally connects the frontend, RV32I+Zicsr core, instruction
// cache, and data cache. It owns no architectural or protocol state: all SEQ
// behavior remains in the child modules and this wrapper contains only COMB
// field mapping between their valid/ready interfaces.
module tile #(
  parameter int IBUF_DEPTH = 2,          // Frontend instruction FIFO depth.
  parameter int ICACHE_LINE_COUNT = 16, // Number of direct-mapped I-cache lines.
  parameter int DCACHE_LINE_COUNT = 16, // Number of direct-mapped D-cache lines.
  parameter int CACHE_LINE_BYTES = 16   // Bytes held in each I/D cache line.
) (
  input  logic        clk_i,               // Tile clock for every child SEQ block.
  input  logic        rst_ni,              // Active-low asynchronous tile reset.
  input  logic [31:0] boot_pc_i,           // Frontend reset PC, normally executable OTP base.
  input  logic        timer_irq_i,         // Machine timer interrupt pending input.
  input  logic        external_irq_i,      // Machine external interrupt pending input.
  input  logic        icache_flush_i,      // Abort active I-cache work without invalidating tags.
  input  logic        icache_invalidate_i, // Clear all I-cache tag valid bits.
  input  logic        dcache_flush_i,      // Abort active D-cache work without invalidating tags.
  input  logic        dcache_invalidate_i, // Clear all D-cache tag valid bits.

  output logic        commit_valid_o,      // Architectural register writeback valid.
  output logic [4:0]  commit_rd_o,         // Architectural destination register.
  output logic [31:0] commit_data_o,       // Architectural writeback data.
  output logic        ex_valid_o,          // Core execute/writeback slot valid.
  output logic [31:0] ex_pc_o,             // Execute/writeback instruction PC.
  output logic [31:0] ex_instr_o,          // Execute/writeback instruction word.
  output logic        illegal_o,           // Illegal instruction indication.
  output logic        lsu_fault_o,         // Load/store alignment or response fault.
  output logic        trap_valid_o,        // Core trap entry selected this cycle.
  output logic        trap_interrupt_o,    // Trap is an interrupt when high.
  output logic [4:0]  trap_cause_o,        // Trap cause without interrupt MSB.
  output logic [31:0] trap_tval_o,         // Trap value written to mtval.
  output logic [31:0] trap_pc_o,           // Trap PC written to mepc.
  output logic        mret_taken_o,        // MRET redirect selected by the core.
  output logic        redirect_valid_o,    // Core redirect valid observation.
  output logic [31:0] redirect_pc_o,       // Core redirect target observation.
  output logic [31:0] csr_rdata_o,         // Core CSR read data observation.
  output logic        hazard_load_use_o,   // Core load-use stall indication.
  output logic        hazard_fwd_rs1_ex_o, // Core rs1 EX-forward decision.
  output logic        hazard_fwd_rs1_wb_o, // Core rs1 WB-forward decision.
  output logic        hazard_fwd_rs2_ex_o, // Core rs2 EX-forward decision.
  output logic        hazard_fwd_rs2_wb_o, // Core rs2 WB-forward decision.
  output logic        unsupported_o,       // Unsupported instruction class indication.

  debug_if.core       core_debug,          // External debug control and halted GPR channel.
  mem_req_rsp_if.initiator imem_if,        // I-cache downstream instruction-memory port.
  mem_req_rsp_if.initiator dmem_if         // D-cache downstream data-memory port.
);
  logic        instr_valid;       // Buffered frontend instruction valid to core.
  logic        instr_ready;       // Core accepts the buffered frontend instruction.
  logic [31:0] instr_pc;          // PC paired with the buffered instruction.
  logic [31:0] instr;             // Buffered 32-bit instruction word.
  logic        instr_fault;       // Fetch access or alignment fault delivered to core.
  logic        instr_misaligned;  // Frontend diagnostic; already included in instr_fault.

  logic        dmem_req_valid;    // Core data request valid before D-cache.
  logic        dmem_req_ready;    // D-cache accepted the core data request.
  logic [31:0] dmem_req_addr;     // Core data request byte address.
  logic        dmem_req_write;    // Core data request direction.
  logic [1:0]  dmem_req_size;     // Core data request byte/halfword/word size.
  logic [31:0] dmem_req_wdata;    // Core store data aligned to byte lanes.
  logic [3:0]  dmem_req_wstrb;    // Core store byte write strobes.
  logic        dmem_rsp_valid;    // D-cache response valid to core.
  logic        dmem_rsp_ready;    // Core accepts the D-cache response.
  logic [31:0] dmem_rsp_rdata;    // D-cache response read data.
  logic        dmem_rsp_err;      // D-cache response error status.

  mem_req_rsp_if frontend_imem_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  mem_req_rsp_if core_dmem_if (
    .clk(clk_i),
    .rst_n(rst_ni)
  );

  // COMB mapping from discrete core LSU signals into the structured D-cache
  // target interface. The instruction qualifier is always low on this path.
  always_comb begin
    core_dmem_if.req_valid = dmem_req_valid;
    core_dmem_if.req_addr = dmem_req_addr;
    core_dmem_if.req_write = dmem_req_write;
    core_dmem_if.req_size = dmem_req_size;
    core_dmem_if.req_wdata = dmem_req_wdata;
    core_dmem_if.req_wstrb = dmem_req_wstrb;
    core_dmem_if.req_instr = 1'b0;
    core_dmem_if.rsp_ready = dmem_rsp_ready;

    dmem_req_ready = core_dmem_if.req_ready;
    dmem_rsp_valid = core_dmem_if.rsp_valid;
    dmem_rsp_rdata = core_dmem_if.rsp_rdata;
    dmem_rsp_err = core_dmem_if.rsp_err;
  end

  frontend #(
    .IBUF_DEPTH(IBUF_DEPTH)
  ) u_frontend (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .boot_pc_i(boot_pc_i),
    .stall_i(1'b0),
    .redirect_valid_i(redirect_valid_o),
    .redirect_pc_i(redirect_pc_o),
    .instr_valid_o(instr_valid),
    .instr_ready_i(instr_ready),
    .instr_pc_o(instr_pc),
    .instr_o(instr),
    .instr_fault_o(instr_fault),
    .instr_misaligned_o(instr_misaligned),
    .imem_if(frontend_imem_if)
  );

  icache #(
    .LINE_COUNT(ICACHE_LINE_COUNT),
    .LINE_BYTES(CACHE_LINE_BYTES)
  ) u_icache (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(icache_flush_i),
    .invalidate_i(icache_invalidate_i),
    .front_if(frontend_imem_if),
    .mem_if(imem_if)
  );

  core u_core (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .instr_valid_i(instr_valid),
    .instr_ready_o(instr_ready),
    .instr_pc_i(instr_pc),
    .instr_i(instr),
    .instr_fault_i(instr_fault),
    .dmem_req_valid_o(dmem_req_valid),
    .dmem_req_ready_i(dmem_req_ready),
    .dmem_req_addr_o(dmem_req_addr),
    .dmem_req_write_o(dmem_req_write),
    .dmem_req_size_o(dmem_req_size),
    .dmem_req_wdata_o(dmem_req_wdata),
    .dmem_req_wstrb_o(dmem_req_wstrb),
    .dmem_rsp_valid_i(dmem_rsp_valid),
    .dmem_rsp_ready_o(dmem_rsp_ready),
    .dmem_rsp_rdata_i(dmem_rsp_rdata),
    .dmem_rsp_err_i(dmem_rsp_err),
    .timer_irq_i(timer_irq_i),
    .external_irq_i(external_irq_i),
    .core_debug(core_debug),
    .commit_valid_o(commit_valid_o),
    .commit_rd_o(commit_rd_o),
    .commit_data_o(commit_data_o),
    .ex_valid_o(ex_valid_o),
    .ex_pc_o(ex_pc_o),
    .ex_instr_o(ex_instr_o),
    .illegal_o(illegal_o),
    .lsu_fault_o(lsu_fault_o),
    .trap_valid_o(trap_valid_o),
    .trap_interrupt_o(trap_interrupt_o),
    .trap_cause_o(trap_cause_o),
    .trap_tval_o(trap_tval_o),
    .trap_pc_o(trap_pc_o),
    .mret_taken_o(mret_taken_o),
    .redirect_valid_o(redirect_valid_o),
    .redirect_pc_o(redirect_pc_o),
    .csr_rdata_o(csr_rdata_o),
    .hazard_load_use_o(hazard_load_use_o),
    .hazard_fwd_rs1_ex_o(hazard_fwd_rs1_ex_o),
    .hazard_fwd_rs1_wb_o(hazard_fwd_rs1_wb_o),
    .hazard_fwd_rs2_ex_o(hazard_fwd_rs2_ex_o),
    .hazard_fwd_rs2_wb_o(hazard_fwd_rs2_wb_o),
    .unsupported_o(unsupported_o)
  );

  dcache #(
    .LINE_COUNT(DCACHE_LINE_COUNT),
    .LINE_BYTES(CACHE_LINE_BYTES)
  ) u_dcache (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .flush_i(dcache_flush_i),
    .invalidate_i(dcache_invalidate_i),
    .core_if(core_dmem_if),
    .mem_if(dmem_if)
  );
endmodule
