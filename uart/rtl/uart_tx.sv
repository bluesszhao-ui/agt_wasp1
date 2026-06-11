`timescale 1ns/1ps

module uart_tx (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       enable_i,
  input  logic       baud_tick_i,
  input  logic       data_valid_i,
  output logic       data_ready_o,
  input  logic [7:0] data_i,
  output logic       tx_o,
  output logic       busy_o
);
  logic [9:0] shifter_q;
  logic [3:0] bit_count_q;

  assign busy_o = (bit_count_q != '0);
  assign data_ready_o = enable_i && !busy_o;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      shifter_q   <= 10'h3FF;
      bit_count_q <= '0;
      tx_o        <= 1'b1;
    end else begin
      if (!enable_i) begin
        shifter_q   <= 10'h3FF;
        bit_count_q <= '0;
        tx_o        <= 1'b1;
      end else if (!busy_o && data_valid_i) begin
        shifter_q   <= {1'b1, data_i, 1'b0};
        bit_count_q <= 4'd10;
      end else if (busy_o && baud_tick_i) begin
        tx_o        <= shifter_q[0];
        shifter_q   <= {1'b1, shifter_q[9:1]};
        bit_count_q <= bit_count_q - 1'b1;
      end
    end
  end
endmodule
