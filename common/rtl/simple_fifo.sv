`timescale 1ns/1ps

module simple_fifo #(
  parameter int WIDTH = 32,
  parameter int DEPTH = 2
) (
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             push_valid_i,
  output logic             push_ready_o,
  input  logic [WIDTH-1:0] push_data_i,
  output logic             pop_valid_o,
  input  logic             pop_ready_i,
  output logic [WIDTH-1:0] pop_data_o
);
  localparam int PTR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam int CNT_WIDTH = $clog2(DEPTH + 1);
  localparam logic [CNT_WIDTH-1:0] DEPTH_COUNT = CNT_WIDTH'(DEPTH);
  localparam logic [PTR_WIDTH-1:0] LAST_PTR = PTR_WIDTH'(DEPTH - 1);

  logic [WIDTH-1:0]     mem_q [DEPTH];
  logic [PTR_WIDTH-1:0] rd_ptr_q;
  logic [PTR_WIDTH-1:0] wr_ptr_q;
  logic [CNT_WIDTH-1:0] count_q;

  logic push_fire;
  logic pop_fire;

  assign push_ready_o = (count_q < DEPTH_COUNT);
  assign pop_valid_o  = (count_q != '0);
  assign pop_data_o   = mem_q[rd_ptr_q];
  assign push_fire    = push_valid_i && push_ready_o;
  assign pop_fire     = pop_valid_o && pop_ready_i;

  function automatic logic [PTR_WIDTH-1:0] ptr_inc(input logic [PTR_WIDTH-1:0] ptr);
    if (ptr == LAST_PTR) begin
      ptr_inc = '0;
    end else begin
      ptr_inc = ptr + 1'b1;
    end
  endfunction

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rd_ptr_q <= '0;
      wr_ptr_q <= '0;
      count_q  <= '0;
    end else begin
      if (push_fire) begin
        mem_q[wr_ptr_q] <= push_data_i;
        wr_ptr_q        <= ptr_inc(wr_ptr_q);
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
