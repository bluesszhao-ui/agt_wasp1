`timescale 1ns/1ps

// tb_tile verifies the complete frontend/core/I-cache/D-cache integration.
//
// Two independent downstream memory models apply deterministic request
// backpressure and response latency. Tests execute real RV32I programs and
// check architectural commits together with cache-side transactions, so the
// verification covers both structural wiring and end-to-end behavior.
module tb_tile;
  localparam int MAIN_PROGRAM = 0;
  localparam int LOAD_LOOP_PROGRAM = 1;
  localparam int FAULT_PROGRAM = 2;
  localparam int FETCH_FAULT_PROGRAM = 3;
  localparam int IRQ_PROGRAM = 4;

  logic clk;                // 100 MHz verification clock.
  logic rst_n;              // Active-low tile reset stimulus.
  logic [31:0] boot_pc;     // Boot PC selected for each test phase.
  logic timer_irq;          // Timer interrupt stimulus, inactive in this milestone.
  logic external_irq;       // External interrupt stimulus, inactive in this milestone.
  logic icache_flush;       // I-cache active-work abort stimulus.
  logic icache_invalidate;  // I-cache tag invalidate stimulus.
  logic dcache_flush;       // D-cache active-work abort stimulus.
  logic dcache_invalidate;  // D-cache tag invalidate stimulus.

  logic        commit_valid;      // Tile architectural commit observation.
  logic [4:0]  commit_rd;         // Committed destination register.
  logic [31:0] commit_data;       // Committed register data.
  logic        ex_valid;          // Execute slot valid observation.
  logic [31:0] ex_pc;             // Execute slot PC observation.
  logic [31:0] ex_instr;          // Execute slot instruction observation.
  logic        illegal;           // Illegal-instruction observation.
  logic        lsu_fault;         // LSU response/alignment fault observation.
  logic        trap_valid;        // Trap observation.
  logic        trap_interrupt;    // Interrupt trap qualifier.
  logic [4:0]  trap_cause;        // Trap cause observation.
  logic [31:0] trap_tval;         // Trap value observation.
  logic [31:0] trap_pc;           // Trap PC observation.
  logic        mret_taken;        // MRET observation.
  logic        redirect_valid;    // Core redirect observation.
  logic [31:0] redirect_pc;       // Core redirect target observation.
  logic [31:0] csr_rdata;         // CSR read-data observation.
  logic        hazard_load_use;   // Load-use hazard observation.
  logic        hazard_fwd_rs1_ex; // EX forwarding observation for rs1.
  logic        hazard_fwd_rs1_wb; // WB forwarding observation for rs1.
  logic        hazard_fwd_rs2_ex; // EX forwarding observation for rs2.
  logic        hazard_fwd_rs2_wb; // WB forwarding observation for rs2.
  logic        unsupported;       // Unsupported instruction observation.

  integer program_select;       // Instruction image selected by current phase.
  integer imem_latency_cfg;     // Accepted I-memory request response delay.
  integer dmem_latency_cfg;     // Accepted D-memory request response delay.
  logic   dmem_error_enable;    // Inject an error on the selected D-memory beat.
  logic [31:0] dmem_error_addr; // D-memory byte address that returns an error.
  logic   imem_error_enable;    // Inject one I-memory refill-beat error.
  logic [31:0] imem_error_addr; // I-memory byte address selected for error.
  logic   imem_error_consumed;  // One-shot I-memory error has completed.
  logic   allow_interrupt_phase;// Checker permits expected IRQ traps when high.

  logic        imem_busy_q;       // I-memory model has one outstanding request.
  logic [31:0] imem_addr_q;       // Captured I-memory request address.
  integer      imem_delay_q;      // Cycles remaining before I-memory response.
  logic        dmem_busy_q;       // D-memory model has one outstanding request.
  logic [31:0] dmem_addr_q;       // Captured D-memory request address.
  logic        dmem_write_q;      // Captured D-memory request direction.
  logic [1:0]  dmem_size_q;       // Captured D-memory request size.
  logic [31:0] dmem_wdata_q;      // Captured D-memory write data.
  logic [3:0]  dmem_wstrb_q;      // Captured D-memory write strobes.
  integer      dmem_delay_q;      // Cycles remaining before D-memory response.
  logic [31:0] dmem_word_100_q;   // Backing-memory word at address 0x100.
  logic [31:0] dmem_word_104_q;   // Backing-memory word at address 0x104.
  logic [31:0] dmem_word_108_q;   // Backing-memory word at address 0x108.
  logic [31:0] dmem_word_10c_q;   // Backing-memory word at address 0x10c.

  integer cycle_count;            // Free-running cycle count used for deterministic stalls.
  integer pass_count;             // Total self-checking assertions passed.
  integer commit_count;           // Commits observed in the current reset phase.
  integer redirect_count;         // Redirects observed in the current reset phase.
  integer hazard_count;           // Load-use hazard cycles in the current phase.
  integer imem_req_count;         // Accepted downstream I-memory requests.
  integer dmem_read_req_count;    // Accepted downstream D-memory read requests.
  integer dmem_write_req_count;   // Accepted downstream D-memory write requests.
  integer imem_backpressure_count;// I-memory request stall cycles.
  integer dmem_backpressure_count;// D-memory request stall cycles.
  integer fault_count;            // LSU fault pulses observed across tests.
  integer invalidate_count;       // Proven I/D invalidate-and-refill cases.
  integer flush_count;            // Active-refill flush cases.
  integer fetch_fault_count;      // Proven fetch-error/writeback-suppression cases.
  integer interrupt_count;        // Proven timer/external interrupt propagation cases.
  integer total_commit_count;     // Commits accumulated across reset phases.
  integer total_redirect_count;   // Redirects accumulated across reset phases.
  integer total_hazard_count;     // Load-use hazard cycles accumulated across phases.
  integer total_imem_req_count;   // I-memory requests accumulated across phases.
  integer total_dmem_read_count;  // D-memory read requests accumulated across phases.
  integer total_dmem_write_count; // D-memory write requests accumulated across phases.
  integer total_imem_bp_count;    // I-memory request stalls accumulated across phases.
  integer total_dmem_bp_count;    // D-memory request stalls accumulated across phases.

  mem_req_rsp_if imem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  mem_req_rsp_if dmem_if (
    .clk(clk),
    .rst_n(rst_n)
  );

  debug_if core_debug (
    .clk(clk),
    .rst_n(rst_n)
  );

  tile #(
    .IBUF_DEPTH(2),
    .ICACHE_LINE_COUNT(16),
    .DCACHE_LINE_COUNT(16),
    .CACHE_LINE_BYTES(16)
  ) dut (
    .clk_i(clk),
    .rst_ni(rst_n),
    .boot_pc_i(boot_pc),
    .timer_irq_i(timer_irq),
    .external_irq_i(external_irq),
    .icache_flush_i(icache_flush),
    .icache_invalidate_i(icache_invalidate),
    .dcache_flush_i(dcache_flush),
    .dcache_invalidate_i(dcache_invalidate),
    .commit_valid_o(commit_valid),
    .commit_rd_o(commit_rd),
    .commit_data_o(commit_data),
    .ex_valid_o(ex_valid),
    .ex_pc_o(ex_pc),
    .ex_instr_o(ex_instr),
    .illegal_o(illegal),
    .lsu_fault_o(lsu_fault),
    .trap_valid_o(trap_valid),
    .trap_interrupt_o(trap_interrupt),
    .trap_cause_o(trap_cause),
    .trap_tval_o(trap_tval),
    .trap_pc_o(trap_pc),
    .mret_taken_o(mret_taken),
    .redirect_valid_o(redirect_valid),
    .redirect_pc_o(redirect_pc),
    .csr_rdata_o(csr_rdata),
    .hazard_load_use_o(hazard_load_use),
    .hazard_fwd_rs1_ex_o(hazard_fwd_rs1_ex),
    .hazard_fwd_rs1_wb_o(hazard_fwd_rs1_wb),
    .hazard_fwd_rs2_ex_o(hazard_fwd_rs2_ex),
    .hazard_fwd_rs2_wb_o(hazard_fwd_rs2_wb),
    .unsupported_o(unsupported),
    .core_debug(core_debug),
    .imem_if(imem_if),
    .dmem_if(dmem_if)
  );

  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  // RV32I encoders keep the program image readable and reduce transcription
  // risk when branch targets or register choices change.
  function automatic logic [31:0] enc_i(
    input logic [11:0] imm,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    enc_i = {imm, rs1, funct3, rd, opcode};
  endfunction

  function automatic logic [31:0] enc_s(
    input logic [11:0] imm,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3
  );
    enc_s = {imm[11:5], rs2, rs1, funct3, imm[4:0], 7'b0100011};
  endfunction

  function automatic logic [31:0] enc_b(
    input logic [12:0] imm,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3
  );
    enc_b = {imm[12], imm[10:5], rs2, rs1, funct3,
             imm[4:1], imm[11], 7'b1100011};
  endfunction

  function automatic logic [31:0] enc_j(
    input logic [20:0] imm,
    input logic [4:0] rd
  );
    enc_j = {imm[20], imm[10:1], imm[11], imm[19:12], rd, 7'b1101111};
  endfunction

  // The main image exercises both caches and a taken redirect. The load-loop
  // image is used to prove D-cache invalidation forces a second refill.
  function automatic logic [31:0] instruction_word(input logic [31:0] addr);
    begin
      unique case (program_select)
        LOAD_LOOP_PROGRAM: begin
          unique case (addr)
            32'h0000_0000: instruction_word = enc_i(12'h100, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,x0,0x100
            32'h0000_0004: instruction_word = enc_i(12'h000, 5'd1, 3'b010, 5'd2, 7'b0000011); // lw x2,0(x1)
            32'h0000_0008: instruction_word = enc_j(21'h1f_fffc, 5'd0);                       // jal x0,-4
            default:       instruction_word = 32'h0000_0013;
          endcase
        end
        FAULT_PROGRAM: begin
          unique case (addr)
            32'h0000_0000: instruction_word = enc_i(12'h100, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,x0,0x100
            32'h0000_0004: instruction_word = enc_i(12'h000, 5'd1, 3'b010, 5'd2, 7'b0000011); // lw x2,0(x1)
            32'h0000_0008: instruction_word = enc_j(21'h000000, 5'd0);                         // jal x0,0
            default:       instruction_word = 32'h0000_0013;
          endcase
        end
        FETCH_FAULT_PROGRAM: begin
          unique case (addr)
            32'h0000_0000: instruction_word = enc_i(12'h006, 5'd0, 3'b000, 5'd6, 7'b0010011); // faulted addi x6,x0,6
            32'h0000_0004: instruction_word = enc_i(12'h007, 5'd0, 3'b000, 5'd7, 7'b0010011); // recovery addi x7,x0,7
            32'h0000_0008: instruction_word = enc_j(21'h000000, 5'd0);                         // jal x0,0
            default:       instruction_word = 32'h0000_0013;
          endcase
        end
        IRQ_PROGRAM: begin
          unique case (addr)
            32'h0000_0000: instruction_word = enc_i(12'h008, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,x0,MIE
            32'h0000_0004: instruction_word = 32'h0000_0013;                                  // dependency gap
            32'h0000_0008: instruction_word = enc_i(12'h300, 5'd1, 3'b010, 5'd0, 7'b1110011); // csrrs x0,mstatus,x1
            32'h0000_000c: instruction_word = enc_i(12'h880, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,x0,-1920
            32'h0000_0010: instruction_word = 32'h0000_0013;                                  // dependency gap
            32'h0000_0014: instruction_word = enc_i(12'h304, 5'd1, 3'b010, 5'd0, 7'b1110011); // csrrs x0,mie,x1
            32'h0000_0018: instruction_word = 32'h0000_0013;
            32'h0000_001c: instruction_word = enc_j(21'h000000, 5'd0);                         // jal x0,0
            default:       instruction_word = 32'h0000_0013;
          endcase
        end
        default: begin
          unique case (addr)
            32'h0000_0000: instruction_word = enc_i(12'h100, 5'd0, 3'b000, 5'd1, 7'b0010011); // addi x1,x0,0x100
            32'h0000_0004: instruction_word = enc_i(12'h000, 5'd1, 3'b010, 5'd2, 7'b0000011); // lw x2,0(x1)
            32'h0000_0008: instruction_word = enc_i(12'h001, 5'd2, 3'b000, 5'd3, 7'b0010011); // addi x3,x2,1
            32'h0000_000c: instruction_word = enc_s(12'h004, 5'd3, 5'd1, 3'b010);              // sw x3,4(x1)
            32'h0000_0010: instruction_word = enc_i(12'h004, 5'd1, 3'b010, 5'd4, 7'b0000011); // lw x4,4(x1)
            32'h0000_0014: instruction_word = enc_b(13'd8, 5'd3, 5'd4, 3'b000);               // beq x4,x3,+8
            32'h0000_0018: instruction_word = enc_i(12'h055, 5'd0, 3'b000, 5'd5, 7'b0010011); // skipped addi
            32'h0000_001c: instruction_word = enc_i(12'h02a, 5'd0, 3'b000, 5'd5, 7'b0010011); // addi x5,x0,42
            32'h0000_0020: instruction_word = enc_j(21'h000000, 5'd0);                         // jal x0,0
            default:       instruction_word = 32'h0000_0013;
          endcase
        end
      endcase
    end
  endfunction

  function automatic logic [31:0] dmem_read_word(input logic [31:0] addr);
    begin
      unique case ({addr[31:2], 2'b00})
        32'h0000_0100: dmem_read_word = dmem_word_100_q;
        32'h0000_0104: dmem_read_word = dmem_word_104_q;
        32'h0000_0108: dmem_read_word = dmem_word_108_q;
        32'h0000_010c: dmem_read_word = dmem_word_10c_q;
        default:       dmem_read_word = 32'ha500_0000 ^ {addr[31:2], 2'b00};
      endcase
    end
  endfunction

  // COMB memory-target outputs. The cycle pattern deliberately denies one in
  // four otherwise-ready requests, proving that cache request payloads remain
  // stable and no request is duplicated under downstream backpressure.
  always_comb begin
    imem_if.req_ready = rst_n && !imem_busy_q && (cycle_count[1:0] != 2'b01);
    imem_if.rsp_valid = rst_n && imem_busy_q && (imem_delay_q == 0);
    imem_if.rsp_rdata = instruction_word(imem_addr_q);
    imem_if.rsp_err = imem_error_enable && !imem_error_consumed &&
                      (imem_addr_q == imem_error_addr);

    dmem_if.req_ready = rst_n && !dmem_busy_q && (cycle_count[1:0] != 2'b10);
    dmem_if.rsp_valid = rst_n && dmem_busy_q && (dmem_delay_q == 0);
    dmem_if.rsp_rdata = dmem_read_word(dmem_addr_q);
    dmem_if.rsp_err = dmem_error_enable && (dmem_addr_q == dmem_error_addr);
  end

  // I-memory model owns one request slot and holds response data/valid until
  // the I-cache refill sequencer accepts it.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      imem_busy_q <= 1'b0;
      imem_addr_q <= 32'h0000_0000;
      imem_delay_q <= 0;
      imem_error_consumed <= 1'b0;
    end else begin
      if (imem_if.req_valid && imem_if.req_ready) begin
        imem_busy_q <= 1'b1;
        imem_addr_q <= imem_if.req_addr;
        imem_delay_q <= imem_latency_cfg;
      end else if (imem_busy_q && (imem_delay_q > 0)) begin
        imem_delay_q <= imem_delay_q - 1;
      end
      if (imem_if.rsp_valid && imem_if.rsp_ready) begin
        imem_busy_q <= 1'b0;
        if (imem_if.rsp_err) imem_error_consumed <= 1'b1;
      end
    end
  end

  // D-memory model applies successful write-through stores only when their
  // response is accepted. Error responses therefore leave backing data intact.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dmem_busy_q <= 1'b0;
      dmem_addr_q <= 32'h0000_0000;
      dmem_write_q <= 1'b0;
      dmem_size_q <= 2'd0;
      dmem_wdata_q <= 32'h0000_0000;
      dmem_wstrb_q <= 4'b0000;
      dmem_delay_q <= 0;
      dmem_word_100_q <= 32'd7;
      dmem_word_104_q <= 32'd0;
      dmem_word_108_q <= 32'h1122_3344;
      dmem_word_10c_q <= 32'h5566_7788;
    end else begin
      if (dmem_if.req_valid && dmem_if.req_ready) begin
        dmem_busy_q <= 1'b1;
        dmem_addr_q <= dmem_if.req_addr;
        dmem_write_q <= dmem_if.req_write;
        dmem_size_q <= dmem_if.req_size;
        dmem_wdata_q <= dmem_if.req_wdata;
        dmem_wstrb_q <= dmem_if.req_wstrb;
        dmem_delay_q <= dmem_latency_cfg;
      end else if (dmem_busy_q && (dmem_delay_q > 0)) begin
        dmem_delay_q <= dmem_delay_q - 1;
      end

      if (dmem_if.rsp_valid && dmem_if.rsp_ready) begin
        dmem_busy_q <= 1'b0;
        if (dmem_write_q && !dmem_if.rsp_err) begin
          for (int lane = 0; lane < 4; lane++) begin
            if (dmem_wstrb_q[lane]) begin
              unique case ({dmem_addr_q[31:2], 2'b00})
                32'h0000_0100: dmem_word_100_q[lane*8 +: 8] <= dmem_wdata_q[lane*8 +: 8];
                32'h0000_0104: dmem_word_104_q[lane*8 +: 8] <= dmem_wdata_q[lane*8 +: 8];
                32'h0000_0108: dmem_word_108_q[lane*8 +: 8] <= dmem_wdata_q[lane*8 +: 8];
                32'h0000_010c: dmem_word_10c_q[lane*8 +: 8] <= dmem_wdata_q[lane*8 +: 8];
                default: begin end
              endcase
            end
          end
        end
      end
    end
  end

  // Phase-local coverage monitor. Counters reset with the DUT so each scenario
  // can make exact transaction-count assertions without inherited traffic.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 0;
      commit_count <= 0;
      redirect_count <= 0;
      hazard_count <= 0;
      imem_req_count <= 0;
      dmem_read_req_count <= 0;
      dmem_write_req_count <= 0;
      imem_backpressure_count <= 0;
      dmem_backpressure_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (commit_valid) commit_count <= commit_count + 1;
      if (redirect_valid) redirect_count <= redirect_count + 1;
      if (hazard_load_use) hazard_count <= hazard_count + 1;
      if (imem_if.req_valid && imem_if.req_ready) imem_req_count <= imem_req_count + 1;
      if (dmem_if.req_valid && dmem_if.req_ready && !dmem_if.req_write) begin
        dmem_read_req_count <= dmem_read_req_count + 1;
      end
      if (dmem_if.req_valid && dmem_if.req_ready && dmem_if.req_write) begin
        dmem_write_req_count <= dmem_write_req_count + 1;
      end
      if (imem_if.req_valid && !imem_if.req_ready && !imem_busy_q) begin
        imem_backpressure_count <= imem_backpressure_count + 1;
      end
      if (dmem_if.req_valid && !dmem_if.req_ready && !dmem_busy_q) begin
        dmem_backpressure_count <= dmem_backpressure_count + 1;
      end
    end
  end

  task automatic apply_reset(input integer selected_program);
    begin
      rst_n = 1'b0;
      program_select = selected_program;
      boot_pc = 32'h0000_0000;
      timer_irq = 1'b0;
      external_irq = 1'b0;
      icache_flush = 1'b0;
      icache_invalidate = 1'b0;
      dcache_flush = 1'b0;
      dcache_invalidate = 1'b0;
      allow_interrupt_phase = 1'b0;
      core_debug.halt_req = 1'b0;
      core_debug.resume_req = 1'b0;
      core_debug.step_req = 1'b0;
      core_debug.trigger_execute_valid = 1'b0;
      core_debug.trigger_execute_addr = 32'h0000_0000;
      core_debug.gpr_req_valid = 1'b0;
      core_debug.gpr_req_write = 1'b0;
      core_debug.gpr_req_addr = 5'd0;
      core_debug.gpr_req_wdata = 32'h0000_0000;
      core_debug.gpr_rsp_ready = 1'b1;
      repeat (3) @(posedge clk);
      @(negedge clk);
      rst_n = 1'b1;
    end
  endtask

  // Capture phase-local counters before the next reset clears them.
  task automatic accumulate_phase_coverage;
    begin
      total_commit_count += commit_count;
      total_redirect_count += redirect_count;
      total_hazard_count += hazard_count;
      total_imem_req_count += imem_req_count;
      total_dmem_read_count += dmem_read_req_count;
      total_dmem_write_count += dmem_write_req_count;
      total_imem_bp_count += imem_backpressure_count;
      total_dmem_bp_count += dmem_backpressure_count;
    end
  endtask

  task automatic wait_for_commit(
    input string name,
    input logic [4:0] expected_rd,
    input logic [31:0] expected_data,
    input integer timeout_cycles
  );
    integer waited;
    begin
      waited = 0;
      while (waited < timeout_cycles) begin
        @(posedge clk);
        #1;
        if (commit_valid && (commit_rd == expected_rd) &&
            (commit_data === expected_data)) begin
          pass_count++;
          return;
        end
        waited++;
      end
      $fatal(1, "%s timed out waiting for x%0d=%08x", name, expected_rd, expected_data);
    end
  endtask

  task automatic wait_for_count_growth(
    input string name,
    input integer original_count,
    input integer required_growth,
    input logic select_dmem,
    input integer timeout_cycles
  );
    integer waited;
    begin
      waited = 0;
      while (waited < timeout_cycles) begin
        @(posedge clk);
        #1;
        if ((select_dmem && (dmem_read_req_count >= original_count + required_growth)) ||
            (!select_dmem && (imem_req_count >= original_count + required_growth))) begin
          pass_count++;
          return;
        end
        waited++;
      end
      $fatal(1, "%s timed out waiting for %0d refill beats", name, required_growth);
    end
  endtask

  initial begin
    integer before_count;
    integer waited;
    logic fault_seen;
    logic bad_load_commit;

    pass_count = 0;
    fault_count = 0;
    invalidate_count = 0;
    flush_count = 0;
    fetch_fault_count = 0;
    interrupt_count = 0;
    total_commit_count = 0;
    total_redirect_count = 0;
    total_hazard_count = 0;
    total_imem_req_count = 0;
    total_dmem_read_count = 0;
    total_dmem_write_count = 0;
    total_imem_bp_count = 0;
    total_dmem_bp_count = 0;
    imem_latency_cfg = 2;
    dmem_latency_cfg = 3;
    dmem_error_enable = 1'b0;
    dmem_error_addr = 32'h0000_0000;
    imem_error_enable = 1'b0;
    imem_error_addr = 32'h0000_0000;

    // Main program: verify architectural data and exact D-cache downstream
    // traffic. The second load must hit the line updated by the successful
    // write-through store, so only four refill reads and one store are legal.
    apply_reset(MAIN_PROGRAM);
    $display("tb_tile phase main start: %0t", $time);
    wait_for_commit("main addi x1", 5'd1, 32'h0000_0100, 160);
    wait_for_commit("main load x2", 5'd2, 32'd7, 200);
    wait_for_commit("main dependent addi x3", 5'd3, 32'd8, 120);
    wait_for_commit("main cached load x4", 5'd4, 32'd8, 200);
    wait_for_commit("main branch target x5", 5'd5, 32'd42, 200);
    if ((dmem_read_req_count != 4) || (dmem_write_req_count != 1)) begin
      $fatal(1, "main D-cache traffic reads=%0d writes=%0d expected=4/1",
             dmem_read_req_count, dmem_write_req_count);
    end
    if ((hazard_count == 0) || (redirect_count == 0) ||
        (imem_backpressure_count == 0) || (dmem_backpressure_count == 0)) begin
      $fatal(1, "main coverage hazard=%0d redirect=%0d ibp=%0d dbp=%0d",
             hazard_count, redirect_count, imem_backpressure_count,
             dmem_backpressure_count);
    end
    if (dmem_word_104_q !== 32'd8) begin
      $fatal(1, "write-through backing memory=%08x expected=00000008", dmem_word_104_q);
    end
    pass_count += 4;

    // A self-loop at 0x20 is resident after the main program. Invalidation
    // must force another four-beat instruction-line refill.
    before_count = imem_req_count;
    @(negedge clk);
    icache_invalidate = 1'b1;
    @(negedge clk);
    icache_invalidate = 1'b0;
    wait_for_count_growth("I-cache invalidate", before_count, 4, 1'b0, 180);
    invalidate_count++;
    $display("tb_tile phase main+icache-invalidate end: %0t", $time);
    accumulate_phase_coverage();

    // The load loop establishes a resident D-cache line, then repeatedly hits.
    // After invalidate, exactly another line refill must become visible.
    apply_reset(LOAD_LOOP_PROGRAM);
    $display("tb_tile phase dcache-invalidate start: %0t", $time);
    wait_for_commit("load loop first load", 5'd2, 32'd7, 220);
    before_count = dmem_read_req_count;
    repeat (30) @(posedge clk);
    if (dmem_read_req_count != before_count) begin
      $fatal(1, "load loop expected cache hits but read count grew %0d->%0d",
             before_count, dmem_read_req_count);
    end
    @(negedge clk);
    dcache_invalidate = 1'b1;
    @(negedge clk);
    dcache_invalidate = 1'b0;
    wait_for_count_growth("D-cache invalidate", before_count, 4, 1'b1, 220);
    invalidate_count++;
    $display("tb_tile phase dcache-invalidate end: %0t", $time);
    accumulate_phase_coverage();

    // Error on the first refill beat is sticky through D-cache completion. The
    // core must expose lsu_fault and suppress the destination-register commit.
    dmem_error_enable = 1'b1;
    dmem_error_addr = 32'h0000_0100;
    apply_reset(FAULT_PROGRAM);
    $display("tb_tile phase dcache-error start: %0t", $time);
    fault_seen = 1'b0;
    bad_load_commit = 1'b0;
    for (waited = 0; waited < 260; waited++) begin
      @(posedge clk);
      #1;
      if (lsu_fault) fault_seen = 1'b1;
      if (commit_valid && (commit_rd == 5'd2)) bad_load_commit = 1'b1;
      if (fault_seen) break;
    end
    if (!fault_seen || bad_load_commit) begin
      $fatal(1, "D-cache error fault_seen=%0b bad_load_commit=%0b",
             fault_seen, bad_load_commit);
    end
    fault_count++;
    pass_count += 2;
    dmem_error_enable = 1'b0;
    $display("tb_tile phase dcache-error end: %0t", $time);
    accumulate_phase_coverage();

    // A one-shot refill error faults the instruction at PC 0. Its x6 writeback
    // must be suppressed; after the failed line remains invalid, a clean refill
    // allows the PC 4 recovery instruction to commit x7=7.
    imem_error_enable = 1'b1;
    imem_error_addr = 32'h0000_0000;
    apply_reset(FETCH_FAULT_PROGRAM);
    $display("tb_tile phase fetch-error start: %0t", $time);
    bad_load_commit = 1'b0;
    for (waited = 0; waited < 260; waited++) begin
      @(posedge clk);
      #1;
      if (commit_valid && (commit_rd == 5'd6)) bad_load_commit = 1'b1;
      if (commit_valid && (commit_rd == 5'd7)) break;
    end
    if (bad_load_commit || !commit_valid || (commit_rd != 5'd7) ||
        (commit_data != 32'd7) || !imem_error_consumed) begin
      $fatal(1, "fetch error recovery bad_x6=%0b commit=%0b x%0d=%08x consumed=%0b",
             bad_load_commit, commit_valid, commit_rd, commit_data,
             imem_error_consumed);
    end
    fetch_fault_count++;
    pass_count += 2;
    imem_error_enable = 1'b0;
    $display("tb_tile phase fetch-error end: %0t", $time);
    accumulate_phase_coverage();

    // Program machine CSRs to enable both interrupt classes. First assert only
    // timer, then repeat with both inputs to prove external-over-timer priority.
    apply_reset(IRQ_PROGRAM);
    $display("tb_tile phase timer-irq start: %0t", $time);
    wait_for_commit("irq enable value", 5'd1, 32'hffff_f880, 260);
    repeat (30) @(posedge clk);
    allow_interrupt_phase = 1'b1;
    timer_irq = 1'b1;
    waited = 0;
    while (!trap_interrupt && (waited < 100)) begin
      @(posedge clk);
      #1;
      waited++;
    end
    if (!trap_interrupt || (trap_cause != 5'd7) || !redirect_valid ||
        (redirect_pc != 32'h0000_0000)) begin
      $fatal(1, "timer IRQ propagation trap=%0b cause=%0d redirect=%0b/%08x",
             trap_interrupt, trap_cause, redirect_valid, redirect_pc);
    end
    @(negedge clk);
    timer_irq = 1'b0;
    @(posedge clk);
    #1;
    allow_interrupt_phase = 1'b0;
    interrupt_count++;
    pass_count++;
    $display("tb_tile phase timer-irq end: %0t", $time);
    accumulate_phase_coverage();

    apply_reset(IRQ_PROGRAM);
    $display("tb_tile phase external-priority-irq start: %0t", $time);
    wait_for_commit("irq priority enable value", 5'd1, 32'hffff_f880, 260);
    repeat (30) @(posedge clk);
    allow_interrupt_phase = 1'b1;
    timer_irq = 1'b1;
    external_irq = 1'b1;
    waited = 0;
    while (!trap_interrupt && (waited < 100)) begin
      @(posedge clk);
      #1;
      waited++;
    end
    if (!trap_interrupt || (trap_cause != 5'd11) || !redirect_valid ||
        (redirect_pc != 32'h0000_0000)) begin
      $fatal(1, "external IRQ priority trap=%0b cause=%0d redirect=%0b/%08x",
             trap_interrupt, trap_cause, redirect_valid, redirect_pc);
    end
    @(negedge clk);
    timer_irq = 1'b0;
    external_irq = 1'b0;
    @(posedge clk);
    #1;
    allow_interrupt_phase = 1'b0;
    interrupt_count++;
    pass_count++;
    $display("tb_tile phase external-priority-irq end: %0t", $time);
    accumulate_phase_coverage();

    // Flush each cache during an active delayed refill. Abort behavior is
    // checked by absence of a response-derived commit/fault before reset.
    imem_latency_cfg = 20;
    apply_reset(MAIN_PROGRAM);
    $display("tb_tile phase icache-flush start: %0t", $time);
    wait (imem_busy_q);
    @(negedge clk);
    icache_flush = 1'b1;
    @(negedge clk);
    icache_flush = 1'b0;
    repeat (5) begin
      @(posedge clk);
      #1;
      if (commit_valid || trap_valid) $fatal(1, "I-cache flush leaked completion");
    end
    flush_count++;
    pass_count++;
    $display("tb_tile phase icache-flush end: %0t", $time);
    accumulate_phase_coverage();

    imem_latency_cfg = 1;
    dmem_latency_cfg = 20;
    apply_reset(LOAD_LOOP_PROGRAM);
    $display("tb_tile phase dcache-flush start: %0t", $time);
    wait (dmem_busy_q);
    @(negedge clk);
    dcache_flush = 1'b1;
    @(negedge clk);
    dcache_flush = 1'b0;
    repeat (5) begin
      @(posedge clk);
      #1;
      if (lsu_fault || (commit_valid && (commit_rd == 5'd2))) begin
        $fatal(1, "D-cache flush leaked load completion");
      end
    end
    flush_count++;
    pass_count++;
    $display("tb_tile phase dcache-flush end: %0t", $time);
    accumulate_phase_coverage();

    $display("tb_tile coverage: pass=%0d commit=%0d redirect=%0d hazard=%0d imem_req=%0d dmem_read=%0d dmem_write=%0d ibp=%0d dbp=%0d invalidate=%0d fault=%0d fetch_fault=%0d irq=%0d flush=%0d",
             pass_count, total_commit_count, total_redirect_count,
             total_hazard_count, total_imem_req_count,
             total_dmem_read_count, total_dmem_write_count,
             total_imem_bp_count, total_dmem_bp_count,
             invalidate_count, fault_count, fetch_fault_count,
             interrupt_count, flush_count);
    $display("tb_tile: PASS");
    $finish;
  end

  // Catch architecturally forbidden or unexpectedly exposed behavior during
  // all phases. x5=0x55 proves that the taken branch failed to flush fall-through.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // No checker action while reset is active.
    end else begin
      #1;
      if (commit_valid && (commit_rd == 5'd5) && (commit_data == 32'h0000_0055)) begin
        $fatal(1, "taken branch committed skipped x5 value");
      end
      if (illegal || unsupported || (trap_interrupt && !allow_interrupt_phase) || mret_taken) begin
        $fatal(1, "unexpected core observation illegal=%0b unsupported=%0b irq=%0b mret=%0b",
               illegal, unsupported, trap_interrupt, mret_taken);
      end
    end
  end
endmodule
