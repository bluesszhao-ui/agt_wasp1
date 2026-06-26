`timescale 1ns/1ps

// Self-checking AHB I2C master testbench.
//
// The bench drives single-beat AHB-Lite accesses and models a tiny I2C slave
// by controlling the sampled SDA line during ACK and read-data phases. The
// checks cover reset, register access, transmit ACK/NACK, receive data,
// controller ACK policy, busy rejection, bad AHB accesses, and deterministic
// random transmit bytes.
module tb_ahb_i2c;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = I2C_BASE;
  localparam int REGION_BYTES = PERIPH_SIZE;

  localparam logic [3:0] ST_IDLE     = 4'd0;
  localparam logic [3:0] ST_BIT_HIGH = 4'd4;
  localparam logic [3:0] ST_ACK_HIGH = 4'd6;

  logic                  hclk;              // 100 MHz verification clock.
  logic                  hresetn;           // Active-low reset driven by TB.
  logic                  hsel;              // AHB slave select.
  logic [ADDR_WIDTH-1:0] haddr;             // AHB byte address.
  logic [1:0]            htrans;            // AHB transfer type.
  logic                  hwrite;            // AHB write indicator.
  logic [2:0]            hsize;             // AHB transfer size.
  logic [DATA_WIDTH-1:0] hwdata;            // AHB write data.
  logic [DATA_WIDTH-1:0] hrdata;            // AHB read data.
  logic                  hready;            // DUT always-ready response.
  logic                  hresp;             // DUT response; high is ERROR.
  logic                  i2c_scl_in;        // Observed SCL line level.
  logic                  i2c_sda_in;        // Observed SDA line level.
  logic                  i2c_scl_out;       // Open-drain SCL drive value.
  logic                  i2c_scl_oe;        // SCL low-drive enable.
  logic                  i2c_sda_out;       // Open-drain SDA drive value.
  logic                  i2c_sda_oe;        // SDA low-drive enable.
  logic                  i2c_irq;           // Done interrupt output.

  logic                  slave_sda_level;   // Default external SDA sample.
  logic                  read_model_en;     // Enables read-bit injection.
  logic [7:0]            read_pattern;      // Byte returned by slave model.

  int unsigned pass_count;
  int unsigned reg_count;
  int unsigned write_tx_count;
  int unsigned read_rx_count;
  int unsigned error_count;
  int unsigned random_count;
  int unsigned line_check_count;

  assign i2c_scl_in = 1'b1;
  assign i2c_sda_in = (read_model_en && (u_ahb_i2c.state_q == ST_BIT_HIGH)) ?
                      read_pattern[u_ahb_i2c.bit_idx_q] : slave_sda_level;

  ahb_i2c #(
    .BASE_ADDR(BASE_ADDR),
    .REGION_BYTES(REGION_BYTES)
  ) u_ahb_i2c (
    .hclk_i(hclk),
    .hresetn_i(hresetn),
    .hsel_i(hsel),
    .haddr_i(haddr),
    .htrans_i(htrans),
    .hwrite_i(hwrite),
    .hsize_i(hsize),
    .hwdata_i(hwdata),
    .hrdata_o(hrdata),
    .hready_o(hready),
    .hresp_o(hresp),
    .i2c_scl_i(i2c_scl_in),
    .i2c_sda_i(i2c_sda_in),
    .i2c_scl_o(i2c_scl_out),
    .i2c_scl_oe_o(i2c_scl_oe),
    .i2c_sda_o(i2c_sda_out),
    .i2c_sda_oe_o(i2c_sda_oe),
    .i2c_irq_o(i2c_irq)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

  // Drive an idle AHB address phase and benign write-data value.
  task automatic drive_idle;
    begin
      hsel = 1'b0;
      haddr = '0;
      htrans = AHB_HTRANS_IDLE;
      hwrite = 1'b0;
      hsize = AHB_HSIZE_WORD;
      hwdata = '0;
    end
  endtask

  // Apply reset and check externally visible reset values.
  task automatic apply_reset;
    begin
      hresetn = 1'b0;
      slave_sda_level = 1'b1;
      read_model_en = 1'b0;
      read_pattern = '0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1 || hresp !== AHB_HRESP_OKAY || hrdata !== '0 ||
          i2c_irq !== 1'b0 || i2c_scl_out !== 1'b0 || i2c_sda_out !== 1'b0 ||
          i2c_scl_oe !== 1'b0 || i2c_sda_oe !== 1'b0) begin
        $error("reset: hready=%0b hresp=%0b hrdata=0x%08h irq=%0b scl_oe=%0b sda_oe=%0b",
               hready, hresp, hrdata, i2c_irq, i2c_scl_oe, i2c_sda_oe);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  // Perform one AHB write and check the following data-phase response.
  task automatic ahb_write(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0] size,
    input logic [DATA_WIDTH-1:0] data,
    input logic expected_resp,
    input string label
  );
    begin
      @(negedge hclk);
      hsel = 1'b1;
      haddr = addr;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b1;
      hsize = size;
      hwdata = data;

      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1) begin
        $error("%s: write address phase expected hready=1", label);
        $fatal(1);
      end

      @(negedge hclk);
      drive_idle();
      hwdata = data;

      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: write response expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  // Perform one AHB read and compare both response and data.
  task automatic ahb_read(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0] size,
    input logic [DATA_WIDTH-1:0] expected_data,
    input logic expected_resp,
    input string label
  );
    begin
      @(negedge hclk);
      hsel = 1'b1;
      haddr = addr;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b0;
      hsize = size;
      hwdata = '0;

      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1) begin
        $error("%s: read address phase expected hready=1", label);
        $fatal(1);
      end

      @(negedge hclk);
      drive_idle();

      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: read response expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_OKAY && hrdata !== expected_data) begin
        $error("%s: read data expected=0x%08h got=0x%08h",
               label, expected_data, hrdata);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

  task automatic write_reg(
    input logic [31:0] offset,
    input logic [31:0] data,
    input string label
  );
    begin
      ahb_write(BASE_ADDR + offset, AHB_HSIZE_WORD, data, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic read_reg(
    input logic [31:0] offset,
    input logic [31:0] expected,
    input string label
  );
    begin
      ahb_read(BASE_ADDR + offset, AHB_HSIZE_WORD, expected, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic wait_state(input logic [3:0] state_value, input string label);
    int unsigned timeout;
    begin
      timeout = 0;
      while (u_ahb_i2c.state_q != state_value && timeout < 80) begin
        @(posedge hclk);
        #1ns;
        timeout++;
      end
      if (u_ahb_i2c.state_q != state_value) begin
        $error("%s: timed out waiting for state %0d, current=%0d",
               label, state_value, u_ahb_i2c.state_q);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_done(input string label);
    int unsigned timeout;
    begin
      timeout = 0;
      while (u_ahb_i2c.state_q != ST_IDLE && timeout < 120) begin
        @(posedge hclk);
        #1ns;
        timeout++;
      end
      if (u_ahb_i2c.state_q != ST_IDLE) begin
        $error("%s: transaction did not return to idle", label);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic clear_status(input string label);
    begin
      write_reg(I2C_CTRL_OFFSET,
                (32'h1 << I2C_CTRL_ENABLE_BIT) |
                (32'h1 << I2C_CTRL_IRQ_EN_BIT) |
                (32'h1 << I2C_CTRL_CLEAR_BIT),
                label);
    end
  endtask

  task automatic check_reset_registers;
    begin
      read_reg(I2C_DATA_OFFSET, 32'h0000_0000, "reset data");
      read_reg(I2C_STATUS_OFFSET, 32'h0000_0000, "reset status");
      read_reg(I2C_CTRL_OFFSET, 32'h0000_0000, "reset ctrl");
      read_reg(I2C_PRESCALE_OFFSET, 32'h0000_0004, "reset prescale");
      read_reg(I2C_CMD_OFFSET, 32'h0000_0000, "reset cmd");
    end
  endtask

  task automatic check_bad_accesses;
    begin
      ahb_write(BASE_ADDR + REGION_BYTES[31:0], AHB_HSIZE_WORD, 32'h1,
                AHB_HRESP_ERROR, "write outside region");
      ahb_read(BASE_ADDR + 32'h1, AHB_HSIZE_WORD, 32'h0,
               AHB_HRESP_ERROR, "misaligned read");
      ahb_write(BASE_ADDR + I2C_CTRL_OFFSET, AHB_HSIZE_BYTE, 32'h1,
                AHB_HRESP_ERROR, "byte write rejected");
      ahb_read(BASE_ADDR + 32'h40, AHB_HSIZE_WORD, 32'h0,
               AHB_HRESP_ERROR, "unknown register read");
    end
  endtask

  task automatic check_write_bit_drive(input logic [7:0] expected_byte);
    begin
      for (int bit_idx = 7; bit_idx >= 0; bit_idx--) begin
        wait_state(ST_BIT_HIGH, "write bit-high state");
        if (i2c_scl_oe !== 1'b0 ||
            i2c_sda_oe !== ~expected_byte[bit_idx]) begin
          $error("write bit %0d: byte=0x%02h expected sda_oe=%0b got scl_oe=%0b sda_oe=%0b",
                 bit_idx, expected_byte, ~expected_byte[bit_idx],
                 i2c_scl_oe, i2c_sda_oe);
          $fatal(1);
        end
        line_check_count++;
        while (u_ahb_i2c.state_q == ST_BIT_HIGH) begin
          @(posedge hclk);
          #1ns;
        end
      end
    end
  endtask

  task automatic run_write_transaction(
    input logic [7:0] tx_byte,
    input logic slave_ack,
    input logic [31:0] expected_status,
    input string label
  );
    begin
      read_model_en = 1'b0;
      slave_sda_level = !slave_ack;
      write_reg(I2C_DATA_OFFSET, {24'h0, tx_byte}, {label, " data"});
      ahb_write(BASE_ADDR + I2C_CMD_OFFSET, AHB_HSIZE_WORD,
                (32'h1 << I2C_CMD_START_BIT) |
                (32'h1 << I2C_CMD_STOP_BIT),
                AHB_HRESP_OKAY, {label, " cmd"});
      check_write_bit_drive(tx_byte);
      wait_done(label);
      read_reg(I2C_STATUS_OFFSET, expected_status, {label, " status"});
      write_tx_count++;
    end
  endtask

  task automatic run_read_transaction(
    input logic [7:0] rx_byte,
    input logic ack_value,
    input logic expected_sda_oe,
    input string label
  );
    begin
      read_model_en = 1'b1;
      read_pattern = rx_byte;
      slave_sda_level = 1'b1;
      ahb_write(BASE_ADDR + I2C_CMD_OFFSET, AHB_HSIZE_WORD,
                (32'h1 << I2C_CMD_START_BIT) |
                (32'h1 << I2C_CMD_READ_BIT) |
                (32'h1 << I2C_CMD_STOP_BIT) |
                ({31'h0, ack_value} << I2C_CMD_ACK_VALUE_BIT),
                AHB_HRESP_OKAY, {label, " cmd"});
      wait_state(ST_ACK_HIGH, {label, " ack-high"});
      if (i2c_sda_oe !== expected_sda_oe || i2c_scl_oe !== 1'b0) begin
        $error("%s: expected read ACK sda_oe=%0b got sda_oe=%0b scl_oe=%0b",
               label, expected_sda_oe, i2c_sda_oe, i2c_scl_oe);
        $fatal(1);
      end
      line_check_count++;
      wait_done(label);
      read_model_en = 1'b0;
      read_reg(I2C_DATA_OFFSET, {24'h0, rx_byte}, {label, " data"});
      read_reg(I2C_STATUS_OFFSET,
               (32'h1 << I2C_STATUS_DONE_BIT) |
               (32'h1 << I2C_STATUS_RX_VALID_BIT) |
               (32'h1 << I2C_STATUS_IRQ_BIT),
               {label, " status"});
      read_rx_count++;
    end
  endtask

  task automatic check_busy_command_reject;
    begin
      read_model_en = 1'b0;
      slave_sda_level = 1'b0;
      write_reg(I2C_DATA_OFFSET, 32'h0000_005a, "busy data");
      ahb_write(BASE_ADDR + I2C_CMD_OFFSET, AHB_HSIZE_WORD,
                (32'h1 << I2C_CMD_START_BIT) |
                (32'h1 << I2C_CMD_STOP_BIT),
                AHB_HRESP_OKAY, "busy first cmd");
      ahb_write(BASE_ADDR + I2C_CMD_OFFSET, AHB_HSIZE_WORD,
                (32'h1 << I2C_CMD_START_BIT),
                AHB_HRESP_ERROR, "busy second cmd rejected");
      wait_done("busy transaction completes");
      read_reg(I2C_STATUS_OFFSET,
               (32'h1 << I2C_STATUS_DONE_BIT) |
               (32'h1 << I2C_STATUS_IRQ_BIT),
               "busy final status");
    end
  endtask

  task automatic run_random_writes;
    logic [7:0] rand_byte;
    begin
      for (int unsigned idx = 0; idx < 4; idx++) begin
        rand_byte = 8'((idx * 8'h35) ^ 8'ha6);
        clear_status("random clear");
        run_write_transaction(rand_byte, 1'b1,
                              (32'h1 << I2C_STATUS_DONE_BIT) |
                              (32'h1 << I2C_STATUS_IRQ_BIT),
                              "random write");
        random_count++;
      end
    end
  endtask

  initial begin
    apply_reset();
    check_reset_registers();
    check_bad_accesses();

    write_reg(I2C_PRESCALE_OFFSET, 32'h0000_0000, "prescale zero");
    read_reg(I2C_PRESCALE_OFFSET, 32'h0000_0000, "prescale zero readback");
    write_reg(I2C_CTRL_OFFSET,
              (32'h1 << I2C_CTRL_ENABLE_BIT) |
              (32'h1 << I2C_CTRL_IRQ_EN_BIT),
              "enable controller");
    read_reg(I2C_CTRL_OFFSET, 32'h0000_0003, "ctrl readback");

    run_write_transaction(8'ha5, 1'b1,
                          (32'h1 << I2C_STATUS_DONE_BIT) |
                          (32'h1 << I2C_STATUS_IRQ_BIT),
                          "write ack");
    clear_status("clear after write ack");

    run_write_transaction(8'h3c, 1'b0,
                          (32'h1 << I2C_STATUS_DONE_BIT) |
                          (32'h1 << I2C_STATUS_ACKERR_BIT) |
                          (32'h1 << I2C_STATUS_IRQ_BIT),
                          "write nack");
    clear_status("clear after write nack");

    run_read_transaction(8'h5a, 1'b0, 1'b1, "read with master ack");
    clear_status("clear after read ack");

    run_read_transaction(8'hc3, 1'b1, 1'b0, "read with master nack");
    clear_status("clear after read nack");

    check_busy_command_reject();
    clear_status("clear after busy");
    run_random_writes();

    $display("tb_ahb_i2c PASS pass_count=%0d reg_count=%0d write_tx_count=%0d read_rx_count=%0d error_count=%0d random_count=%0d line_check_count=%0d",
             pass_count, reg_count, write_tx_count, read_rx_count, error_count,
             random_count, line_check_count);
    $finish;
  end
endmodule
