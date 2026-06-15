`timescale 1ns/1ps

// frontend_pc owns the frontend program-counter register.
//
// The block is deliberately small: reset loads the boot PC, redirect has the
// highest runtime priority, and an accepted fetch advances the PC by one RV32I
// instruction word. Misaligned PCs are reported instead of silently corrected so
// later fetch/fault logic can preserve architectural exception behavior.
module frontend_pc (
  input  logic        clk_i,           // Frontend clock for the PC register.
  input  logic        rst_ni,          // Active-low asynchronous reset.

  input  logic [31:0] boot_pc_i,       // PC value loaded while reset is active.
  input  logic        stall_i,         // Holds request valid low and blocks sequential advance.
  input  logic        fetch_ready_i,   // Downstream fetch/cache accepted the current PC.
  input  logic        redirect_valid_i,// Redirect request from branch/trap/debug control.
  input  logic [31:0] redirect_pc_i,   // Redirect target captured when redirect is valid.

  output logic        pc_valid_o,      // Current PC request is valid when high.
  output logic [31:0] pc_o,            // Current frontend PC request address.
  output logic        pc_misaligned_o  // Current PC has non-zero low address bits.
);
  logic [31:0] pc_q;       // Registered current PC address.
  logic        valid_q;    // Becomes high after reset release and remains high.
  logic        fetch_fire; // Sequential advance event for an accepted request.

  assign pc_o = pc_q;
  assign pc_valid_o = valid_q && !stall_i;
  assign pc_misaligned_o = |pc_q[1:0];
  assign fetch_fire = pc_valid_o && fetch_ready_i;

  // PC update priority is reset, redirect, sequential accepted fetch, hold.
  // Redirect is allowed during stall so traps/branches/debug can retarget the
  // frontend immediately while the request side is backpressured.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pc_q <= boot_pc_i;
      valid_q <= 1'b0;
    end else begin
      valid_q <= 1'b1;
      if (redirect_valid_i) begin
        pc_q <= redirect_pc_i;
      end else if (fetch_fire) begin
        pc_q <= pc_q + 32'd4;
      end
    end
  end
endmodule
