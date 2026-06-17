`timescale 1ns/1ps

// frontend_ibuf is a small flushable instruction buffer.
//
// It decouples instruction fetch responses from core-side instruction
// consumption.  The buffer preserves PC, instruction, and fault metadata, and
// flushes all queued entries on redirect/trap/debug control changes.
module frontend_ibuf #(
  parameter int DEPTH = 2
) (
  input  logic        clk_i,              // Frontend clock for FIFO state.
  input  logic        rst_ni,             // Active-low asynchronous reset.
  input  logic        flush_i,            // Clear queued instructions immediately on next clock.

  input  logic        push_valid_i,       // Fetch response valid into the buffer.
  output logic        push_ready_o,       // Buffer can accept the fetch response.
  input  logic [31:0] push_pc_i,          // Fetch response PC.
  input  logic [31:0] push_instr_i,       // Fetch response instruction word.
  input  logic        push_fault_i,       // Fetch response fault flag.
  input  logic        push_misaligned_i,  // Fetch response misaligned-PC flag.

  output logic        pop_valid_o,        // Buffered instruction valid to the core side.
  input  logic        pop_ready_i,        // Core side accepted the buffered instruction.
  output logic [31:0] pop_pc_o,           // Buffered instruction PC.
  output logic [31:0] pop_instr_o,        // Buffered instruction word.
  output logic        pop_fault_o,        // Buffered instruction fault flag.
  output logic        pop_misaligned_o,   // Buffered instruction misaligned-PC flag.
  output logic        empty_o,            // Buffer is empty.
  output logic        full_o              // Buffer is full.
);
  localparam int PTR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam int CNT_WIDTH = $clog2(DEPTH + 1);
  localparam logic [CNT_WIDTH-1:0] DEPTH_COUNT = CNT_WIDTH'(DEPTH);
  localparam logic [PTR_WIDTH-1:0] LAST_PTR = PTR_WIDTH'(DEPTH - 1);

  logic [31:0] pc_q [DEPTH];       // FIFO PC storage.
  logic [31:0] instr_q [DEPTH];    // FIFO instruction storage.
  logic        fault_q [DEPTH];    // FIFO fetch fault storage.
  logic        misaligned_q [DEPTH];// FIFO misaligned-PC fault storage.
  logic [PTR_WIDTH-1:0] rd_ptr_q;  // Read pointer for pop side.
  logic [PTR_WIDTH-1:0] wr_ptr_q;  // Write pointer for push side.
  logic [CNT_WIDTH-1:0] count_q;   // Number of valid queued entries.
  logic push_fire;                 // Fetch response accepted this cycle.
  logic pop_fire;                  // Core response consumed this cycle.

  assign empty_o = (count_q == '0);
  assign full_o = (count_q == DEPTH_COUNT);
  assign push_ready_o = !full_o && !flush_i;
  assign pop_valid_o = !empty_o && !flush_i;
  assign pop_pc_o = pc_q[rd_ptr_q];
  assign pop_instr_o = instr_q[rd_ptr_q];
  assign pop_fault_o = fault_q[rd_ptr_q];
  assign pop_misaligned_o = misaligned_q[rd_ptr_q];
  assign push_fire = push_valid_i && push_ready_o;
  assign pop_fire = pop_valid_o && pop_ready_i;

  function automatic logic [PTR_WIDTH-1:0] ptr_inc(input logic [PTR_WIDTH-1:0] ptr);
    if (ptr == LAST_PTR) begin
      ptr_inc = '0;
    end else begin
      ptr_inc = ptr + 1'b1;
    end
  endfunction

  // Flush has highest priority and drops all queued data. Otherwise push and
  // pop handshakes update pointers independently while count tracks occupancy.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rd_ptr_q <= '0;
      wr_ptr_q <= '0;
      count_q <= '0;
    end else if (flush_i) begin
      rd_ptr_q <= '0;
      wr_ptr_q <= '0;
      count_q <= '0;
    end else begin
      if (push_fire) begin
        pc_q[wr_ptr_q] <= push_pc_i;
        instr_q[wr_ptr_q] <= push_instr_i;
        fault_q[wr_ptr_q] <= push_fault_i;
        misaligned_q[wr_ptr_q] <= push_misaligned_i;
        wr_ptr_q <= ptr_inc(wr_ptr_q);
      end

      if (pop_fire) begin
        rd_ptr_q <= ptr_inc(rd_ptr_q);
      end

      unique case ({push_fire, pop_fire})
        2'b10: count_q <= count_q + 1'b1;
        2'b01: count_q <= count_q - 1'b1;
        default: count_q <= count_q;
      endcase
    end
  end
endmodule
