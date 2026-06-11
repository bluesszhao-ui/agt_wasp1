`timescale 1ns/1ps

module uart_baud #(
  parameter int DIV_WIDTH = 16
) (
  input  logic                 clk_i,
  input  logic                 rst_ni,
  input  logic                 enable_i,
  input  logic [DIV_WIDTH-1:0] divisor_i,
  output logic                 tick_o
);
  logic [DIV_WIDTH-1:0] count_q;
  logic [DIV_WIDTH-1:0] terminal_count;

  assign terminal_count = (divisor_i == '0) ? DIV_WIDTH'(1) : divisor_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      count_q <= '0;
      tick_o  <= 1'b0;
    end else begin
      tick_o <= 1'b0;
      if (!enable_i) begin
        count_q <= '0;
      end else if (count_q == terminal_count - 1'b1) begin
        count_q <= '0;
        tick_o  <= 1'b1;
      end else begin
        count_q <= count_q + 1'b1;
      end
    end
  end
endmodule
