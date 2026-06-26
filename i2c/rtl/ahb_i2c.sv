`timescale 1ns/1ps
`include "wasp1_target_defs.svh"

// Minimal AHB-Lite I2C master.
//
// The controller executes one 8-bit I2C byte transaction per CMD write. It is
// intentionally small: software supplies START/READ/STOP/ACK policy in CMD,
// writes TX DATA for transmit bytes, and reads RX DATA after read completion.
// SCL/SDA are open-drain style outputs: *_oe_o=1 drives the line low, and
// *_oe_o=0 releases the line to an external pull-up.
module ahb_i2c #(
  parameter int ADDR_WIDTH = wasp1_pkg::ADDR_WIDTH,
  parameter int DATA_WIDTH = wasp1_pkg::DATA_WIDTH,
  parameter logic [31:0] BASE_ADDR = wasp1_pkg::I2C_BASE,
  parameter int REGION_BYTES = wasp1_pkg::PERIPH_SIZE
) (
  input  logic                  hclk_i,       // AHB and I2C controller clock.
  input  logic                  hresetn_i,    // Active-low asynchronous reset.
  input  logic                  hsel_i,       // AHB slave select.
  input  logic [ADDR_WIDTH-1:0] haddr_i,      // AHB byte address.
  input  logic [1:0]            htrans_i,     // AHB transfer type.
  input  logic                  hwrite_i,     // AHB write indicator.
  input  logic [2:0]            hsize_i,      // AHB transfer size; word only.
  input  logic [DATA_WIDTH-1:0] hwdata_i,     // AHB write data.
  output logic [DATA_WIDTH-1:0] hrdata_o,     // AHB read data.
  output logic                  hready_o,     // Always-ready response.
  output logic                  hresp_o,      // AHB response; high means ERROR.
  input  logic                  i2c_scl_i,    // Observed SCL line level.
  input  logic                  i2c_sda_i,    // Observed SDA line level.
  output logic                  i2c_scl_o,    // Constant low drive value for SCL.
  output logic                  i2c_scl_oe_o, // Drive SCL low when asserted.
  output logic                  i2c_sda_o,    // Constant low drive value for SDA.
  output logic                  i2c_sda_oe_o, // Drive SDA low when asserted.
  output logic                  i2c_irq_o     // Done interrupt when enabled.
);
  import wasp1_pkg::*;

  typedef enum logic [3:0] {
    I2C_IDLE,
    I2C_START_A,
    I2C_START_B,
    I2C_BIT_LOW,
    I2C_BIT_HIGH,
    I2C_ACK_LOW,
    I2C_ACK_HIGH,
    I2C_STOP_LOW,
    I2C_STOP_HIGH,
    I2C_DONE
  } i2c_state_e;

  // Captured AHB address phase for the following response/data phase.
  logic                  req_valid_q;
  logic                  req_write_q;
  logic                  req_err_q;
  logic [ADDR_WIDTH-1:0] req_offset_q;
  logic [2:0]            req_size_q;

  // AHB address-phase decode.
  logic [ADDR_WIDTH-1:0] addr_offset;
  logic                  addr_in_range;
  logic                  addr_phase_valid;
  logic                  addr_phase_err;
  logic [DATA_WIDTH-1:0] read_data_next;

  // Software-visible configuration and status.
  logic                  enable_q;
  logic                  irq_en_q;
  logic [15:0]           prescale_q;
  logic [15:0]           div_q;
  logic [7:0]            tx_data_q;
  logic [7:0]            rx_data_q;
  logic                  done_q;
  logic                  ackerr_q;
  logic                  rx_valid_q;

  // I2C byte engine state.
  i2c_state_e            state_q;
  logic [2:0]            bit_idx_q;
  logic                  read_cmd_q;
  logic                  stop_cmd_q;
  logic                  ack_value_q;
  logic [7:0]            rx_shift_q;
  logic                  tick;

  assign hready_o = 1'b1;
  assign i2c_irq_o = done_q && irq_en_q;
  assign i2c_scl_o = 1'b0;
  assign i2c_sda_o = 1'b0;

  assign addr_offset = haddr_i - ADDR_WIDTH'(BASE_ADDR);
  assign addr_in_range = (haddr_i >= ADDR_WIDTH'(BASE_ADDR)) &&
                         (addr_offset < ADDR_WIDTH'(REGION_BYTES));
  assign addr_phase_valid = hsel_i && htrans_i[1];
  assign addr_phase_err = addr_phase_valid &&
                          (!addr_in_range || |haddr_i[1:0] || (hsize_i != AHB_HSIZE_WORD));

  assign tick = (div_q == 16'h0000);

  // Decode line drive policy from the current engine state. Open-drain high is
  // represented by output-enable deassertion.
  always_comb begin
    i2c_scl_oe_o = 1'b0;
    i2c_sda_oe_o = 1'b0;

    unique case (state_q)
      I2C_START_B: begin
        i2c_sda_oe_o = 1'b1;
      end
      I2C_BIT_LOW: begin
        i2c_scl_oe_o = 1'b1;
        if (!read_cmd_q && !tx_data_q[bit_idx_q]) begin
          i2c_sda_oe_o = 1'b1;
        end
      end
      I2C_BIT_HIGH: begin
        if (!read_cmd_q && !tx_data_q[bit_idx_q]) begin
          i2c_sda_oe_o = 1'b1;
        end
      end
      I2C_ACK_LOW: begin
        i2c_scl_oe_o = 1'b1;
        if (read_cmd_q && !ack_value_q) begin
          i2c_sda_oe_o = 1'b1;
        end
      end
      I2C_ACK_HIGH: begin
        if (read_cmd_q && !ack_value_q) begin
          i2c_sda_oe_o = 1'b1;
        end
      end
      I2C_STOP_LOW: begin
        i2c_scl_oe_o = 1'b1;
        i2c_sda_oe_o = 1'b1;
      end
      I2C_STOP_HIGH: begin
        i2c_sda_oe_o = 1'b1;
      end
      default: begin
        i2c_scl_oe_o = 1'b0;
        i2c_sda_oe_o = 1'b0;
      end
    endcase
  end

  function automatic logic is_known_reg(input logic [31:0] reg_offset);
    begin
      unique case (reg_offset)
        I2C_DATA_OFFSET,
        I2C_STATUS_OFFSET,
        I2C_CTRL_OFFSET,
        I2C_PRESCALE_OFFSET,
        I2C_CMD_OFFSET: is_known_reg = 1'b1;
        default:        is_known_reg = 1'b0;
      endcase
    end
  endfunction

  function automatic logic [31:0] make_status;
    logic [31:0] status;
    begin
      status = '0;
      status[I2C_STATUS_BUSY_BIT] = (state_q != I2C_IDLE);
      status[I2C_STATUS_DONE_BIT] = done_q;
      status[I2C_STATUS_ACKERR_BIT] = ackerr_q;
      status[I2C_STATUS_RX_VALID_BIT] = rx_valid_q;
      status[I2C_STATUS_IRQ_BIT] = i2c_irq_o;
      make_status = status;
    end
  endfunction

  always_comb begin
    read_data_next = '0;
    if (req_valid_q && !req_write_q && !req_err_q) begin
      unique case (req_offset_q)
        I2C_DATA_OFFSET:     read_data_next = {24'h0, rx_data_q};
        I2C_STATUS_OFFSET:   read_data_next = make_status();
        I2C_CTRL_OFFSET: begin
          read_data_next[I2C_CTRL_ENABLE_BIT] = enable_q;
          read_data_next[I2C_CTRL_IRQ_EN_BIT] = irq_en_q;
        end
        I2C_PRESCALE_OFFSET: read_data_next = {16'h0, prescale_q};
        I2C_CMD_OFFSET:      read_data_next = '0;
        default:             read_data_next = '0;
      endcase
    end
  end

  always_ff @(posedge hclk_i or negedge hresetn_i) begin
    if (!hresetn_i) begin
      req_valid_q  <= 1'b0;
      req_write_q  <= 1'b0;
      req_err_q    <= 1'b0;
      req_offset_q <= '0;
      req_size_q   <= AHB_HSIZE_WORD;
      enable_q     <= 1'b0;
      irq_en_q     <= 1'b0;
      prescale_q   <= 16'd4;
      div_q        <= 16'd4;
      tx_data_q    <= '0;
      rx_data_q    <= '0;
      done_q       <= 1'b0;
      ackerr_q     <= 1'b0;
      rx_valid_q   <= 1'b0;
      state_q      <= I2C_IDLE;
      bit_idx_q    <= 3'd7;
      read_cmd_q   <= 1'b0;
      stop_cmd_q   <= 1'b0;
      ack_value_q  <= 1'b1;
      rx_shift_q   <= '0;
      hrdata_o     <= '0;
      hresp_o      <= AHB_HRESP_OKAY;
    end else begin
      hrdata_o <= read_data_next;
      hresp_o <= req_err_q ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;

      if (state_q != I2C_IDLE) begin
        div_q <= tick ? prescale_q : (div_q - 16'd1);
      end else begin
        div_q <= prescale_q;
      end

      if (tick) begin
        unique case (state_q)
          I2C_START_A: begin
            state_q <= I2C_START_B;
          end
          I2C_START_B: begin
            state_q <= I2C_BIT_LOW;
          end
          I2C_BIT_LOW: begin
            state_q <= I2C_BIT_HIGH;
          end
          I2C_BIT_HIGH: begin
            if (read_cmd_q) begin
              rx_shift_q[bit_idx_q] <= i2c_sda_i;
            end
            if (bit_idx_q == 3'd0) begin
              state_q <= I2C_ACK_LOW;
            end else begin
              bit_idx_q <= bit_idx_q - 3'd1;
              state_q <= I2C_BIT_LOW;
            end
          end
          I2C_ACK_LOW: begin
            state_q <= I2C_ACK_HIGH;
          end
          I2C_ACK_HIGH: begin
            if (!read_cmd_q) begin
              ackerr_q <= i2c_sda_i;
            end else begin
              rx_data_q <= rx_shift_q;
              rx_valid_q <= 1'b1;
            end
            state_q <= stop_cmd_q ? I2C_STOP_LOW : I2C_DONE;
          end
          I2C_STOP_LOW: begin
            state_q <= I2C_STOP_HIGH;
          end
          I2C_STOP_HIGH: begin
            state_q <= I2C_DONE;
          end
          I2C_DONE: begin
            state_q <= I2C_IDLE;
            done_q <= 1'b1;
          end
          default: begin
            state_q <= state_q;
          end
        endcase
      end

      if (req_valid_q && !req_err_q) begin
        if (!is_known_reg(req_offset_q[31:0])) begin
          hresp_o <= AHB_HRESP_ERROR;
        end else if (req_write_q) begin
          unique case (req_offset_q)
            I2C_DATA_OFFSET: begin
              tx_data_q <= hwdata_i[7:0];
            end
            I2C_CTRL_OFFSET: begin
              enable_q <= hwdata_i[I2C_CTRL_ENABLE_BIT];
              irq_en_q <= hwdata_i[I2C_CTRL_IRQ_EN_BIT];
              if (hwdata_i[I2C_CTRL_CLEAR_BIT]) begin
                done_q <= 1'b0;
                ackerr_q <= 1'b0;
                rx_valid_q <= 1'b0;
              end
            end
            I2C_PRESCALE_OFFSET: begin
              prescale_q <= hwdata_i[15:0];
            end
            I2C_CMD_OFFSET: begin
              if (!enable_q || (state_q != I2C_IDLE)) begin
                hresp_o <= AHB_HRESP_ERROR;
              end else begin
                done_q <= 1'b0;
                ackerr_q <= 1'b0;
                rx_valid_q <= 1'b0;
                bit_idx_q <= 3'd7;
                read_cmd_q <= hwdata_i[I2C_CMD_READ_BIT];
                stop_cmd_q <= hwdata_i[I2C_CMD_STOP_BIT];
                ack_value_q <= hwdata_i[I2C_CMD_ACK_VALUE_BIT];
                rx_shift_q <= '0;
                div_q <= prescale_q;
                state_q <= hwdata_i[I2C_CMD_START_BIT] ? I2C_START_A : I2C_BIT_LOW;
              end
            end
            default: begin
              hresp_o <= AHB_HRESP_ERROR;
            end
          endcase
        end
      end

      req_valid_q  <= addr_phase_valid;
      req_write_q  <= hwrite_i;
      req_err_q    <= addr_phase_err;
      req_offset_q <= addr_offset;
      req_size_q   <= hsize_i;
    end
  end

  logic unused_scl;
  logic unused_req_size;
  assign unused_scl = i2c_scl_i;
  assign unused_req_size = ^req_size_q;
endmodule
