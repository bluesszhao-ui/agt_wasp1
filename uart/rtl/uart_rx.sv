`timescale 1ns/1ps

module uart_rx (
  input  logic       clk_i,
  input  logic       rst_ni,
  input  logic       enable_i,
  input  logic       baud_tick_i,
  input  logic       rx_i,
  output logic       data_valid_o,
  output logic [7:0] data_o,
  output logic       frame_error_o,
  output logic       busy_o
);
  typedef enum logic [1:0] {
    RX_IDLE,
    RX_START,
    RX_DATA,
    RX_STOP
  } rx_state_e;

  rx_state_e state_q;
  logic [2:0] bit_idx_q;
  logic [7:0] data_q;

  assign busy_o = (state_q != RX_IDLE);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q       <= RX_IDLE;
      bit_idx_q     <= '0;
      data_q        <= '0;
      data_o        <= '0;
      data_valid_o  <= 1'b0;
      frame_error_o <= 1'b0;
    end else begin
      data_valid_o  <= 1'b0;
      frame_error_o <= 1'b0;

      if (!enable_i) begin
        state_q   <= RX_IDLE;
        bit_idx_q <= '0;
      end else begin
        unique case (state_q)
          RX_IDLE: begin
            if (!rx_i) begin
              state_q   <= RX_START;
              bit_idx_q <= '0;
            end
          end
          RX_START: begin
            if (baud_tick_i) begin
              if (!rx_i) begin
                state_q <= RX_DATA;
              end else begin
                state_q <= RX_IDLE;
              end
            end
          end
          RX_DATA: begin
            if (baud_tick_i) begin
              data_q[bit_idx_q] <= rx_i;
              if (bit_idx_q == 3'd7) begin
                state_q <= RX_STOP;
              end
              bit_idx_q <= bit_idx_q + 1'b1;
            end
          end
          RX_STOP: begin
            if (baud_tick_i) begin
              if (rx_i) begin
                data_o       <= data_q;
                data_valid_o <= 1'b1;
              end else begin
                frame_error_o <= 1'b1;
              end
              state_q <= RX_IDLE;
            end
          end
          default: state_q <= RX_IDLE;
        endcase
      end
    end
  end
endmodule
