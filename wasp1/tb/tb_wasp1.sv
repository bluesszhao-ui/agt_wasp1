`timescale 1ns/1ps

// Smoke-level wasp1 SoC integration testbench.
//
// This bench does not replace module-level verification. It checks that the
// integrated top resets cleanly, exposes benign IO defaults, and allows the
// core-side instruction path to make progress through the OTP/fabric path.
module tb_wasp1;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int GPIO_WIDTH = 32;

  logic                  hclk;              // 100 MHz verification clock.
  logic                  hresetn;           // Active-low reset driven by TB.
  logic                  uart_rx;           // Idle-high UART RX stimulus.
  logic                  uart_tx;           // UART TX output.
  logic                  i2c_scl_in;        // Pulled-up I2C SCL sample.
  logic                  i2c_sda_in;        // Pulled-up I2C SDA sample.
  logic                  i2c_scl_out;       // I2C SCL low-drive value.
  logic                  i2c_scl_oe;        // I2C SCL low-drive enable.
  logic                  i2c_sda_out;       // I2C SDA low-drive value.
  logic                  i2c_sda_oe;        // I2C SDA low-drive enable.
  logic [GPIO_WIDTH-1:0] gpio_in;           // GPIO input pattern.
  logic [GPIO_WIDTH-1:0] gpio_out;          // GPIO output data.
  logic [GPIO_WIDTH-1:0] gpio_oe;           // GPIO output enables.
  logic                  wdg_reset_req;     // Watchdog reset request.
  logic                  trap_valid;        // Core trap observation.
  logic [4:0]            trap_cause;        // Core trap cause.
  logic                  bus_grant_idx;     // Fabric grant observation.
  logic                  dbg_halt_req;      // Debug halt stimulus.
  logic                  dbg_resume_req;    // Debug resume stimulus.
  logic                  dbg_step_req;      // Debug step stimulus.
  logic                  dbg_halted;        // Debug halted status.
  logic                  dbg_running;       // Debug running status.
  logic                  dbg_gpr_req_valid; // Debug GPR request valid.
  logic                  dbg_gpr_req_ready; // Debug GPR request ready.
  logic                  dbg_gpr_req_write; // Debug GPR request direction.
  logic [4:0]            dbg_gpr_req_addr;  // Debug GPR index.
  logic [31:0]           dbg_gpr_req_wdata; // Debug GPR write data.
  logic                  dbg_gpr_rsp_valid; // Debug GPR response valid.
  logic                  dbg_gpr_rsp_ready; // Debug GPR response ready.
  logic [31:0]           dbg_gpr_rsp_rdata; // Debug GPR read data.
  logic                  dbg_gpr_rsp_err;   // Debug GPR response error.

  int unsigned pass_count;

  wasp1 #(
    .GPIO_WIDTH(GPIO_WIDTH)
  ) u_wasp1 (
    .hclk_i(hclk),
    .hresetn_i(hresetn),
    .uart_rx_i(uart_rx),
    .uart_tx_o(uart_tx),
    .i2c_scl_i(i2c_scl_in),
    .i2c_sda_i(i2c_sda_in),
    .i2c_scl_o(i2c_scl_out),
    .i2c_scl_oe_o(i2c_scl_oe),
    .i2c_sda_o(i2c_sda_out),
    .i2c_sda_oe_o(i2c_sda_oe),
    .gpio_in_i(gpio_in),
    .gpio_out_o(gpio_out),
    .gpio_oe_o(gpio_oe),
    .wdg_reset_req_o(wdg_reset_req),
    .trap_valid_o(trap_valid),
    .trap_cause_o(trap_cause),
    .bus_grant_idx_o(bus_grant_idx),
    .dbg_halt_req_i(dbg_halt_req),
    .dbg_resume_req_i(dbg_resume_req),
    .dbg_step_req_i(dbg_step_req),
    .dbg_halted_o(dbg_halted),
    .dbg_running_o(dbg_running),
    .dbg_gpr_req_valid_i(dbg_gpr_req_valid),
    .dbg_gpr_req_ready_o(dbg_gpr_req_ready),
    .dbg_gpr_req_write_i(dbg_gpr_req_write),
    .dbg_gpr_req_addr_i(dbg_gpr_req_addr),
    .dbg_gpr_req_wdata_i(dbg_gpr_req_wdata),
    .dbg_gpr_rsp_valid_o(dbg_gpr_rsp_valid),
    .dbg_gpr_rsp_ready_i(dbg_gpr_rsp_ready),
    .dbg_gpr_rsp_rdata_o(dbg_gpr_rsp_rdata),
    .dbg_gpr_rsp_err_o(dbg_gpr_rsp_err)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

  // Drive inactive external pins and debug requests.
  task automatic drive_defaults;
    begin
      uart_rx = 1'b1;
      i2c_scl_in = 1'b1;
      i2c_sda_in = 1'b1;
      gpio_in = 32'ha5a5_5a5a;
      dbg_halt_req = 1'b0;
      dbg_resume_req = 1'b0;
      dbg_step_req = 1'b0;
      dbg_gpr_req_valid = 1'b0;
      dbg_gpr_req_write = 1'b0;
      dbg_gpr_req_addr = '0;
      dbg_gpr_req_wdata = '0;
      dbg_gpr_rsp_ready = 1'b1;
    end
  endtask

  task automatic expect_reset_outputs;
    begin
      #1ns;
      if (uart_tx !== 1'b1 || i2c_scl_out !== 1'b0 || i2c_sda_out !== 1'b0 ||
          i2c_scl_oe !== 1'b0 || i2c_sda_oe !== 1'b0 ||
          gpio_out !== '0 || gpio_oe !== '0 || wdg_reset_req !== 1'b0) begin
        $error("reset outputs: uart_tx=%0b i2c_oe=%0b/%0b gpio_out=0x%08h gpio_oe=0x%08h wdg_reset=%0b",
               uart_tx, i2c_scl_oe, i2c_sda_oe, gpio_out, gpio_oe, wdg_reset_req);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_for_core_fetch_activity;
    int unsigned timeout;
    begin
      timeout = 0;
      while ((u_wasp1.core_htrans[1] !== 1'b1) && timeout < 80) begin
        @(posedge hclk);
        #1ns;
        timeout++;
      end
      if (u_wasp1.core_htrans[1] !== 1'b1) begin
        $error("core AHB master did not issue a valid transfer after reset");
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_for_debug_running_known;
    int unsigned timeout;
    begin
      timeout = 0;
      while ((dbg_running !== 1'b1) && (dbg_halted !== 1'b1) && timeout < 80) begin
        @(posedge hclk);
        #1ns;
        timeout++;
      end
      if ((dbg_running !== 1'b1) && (dbg_halted !== 1'b1)) begin
        $error("debug status did not become running or halted");
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  initial begin
    drive_defaults();
    hresetn = 1'b0;
    repeat (4) @(posedge hclk);
    expect_reset_outputs();
    hresetn = 1'b1;
    @(posedge hclk);
    #1ns;
    pass_count++;

    wait_for_core_fetch_activity();
    wait_for_debug_running_known();

    repeat (20) @(posedge hclk);
    #1ns;
    if (wdg_reset_req !== 1'b0 || i2c_scl_oe !== 1'b0 || i2c_sda_oe !== 1'b0) begin
      $error("idle peripherals changed unexpectedly after smoke window");
      $fatal(1);
    end
    pass_count++;

    $display("tb_wasp1 PASS pass_count=%0d trap_valid=%0b trap_cause=0x%02h bus_grant_idx=%0b dbg_running=%0b dbg_halted=%0b",
             pass_count, trap_valid, trap_cause, bus_grant_idx, dbg_running, dbg_halted);
    $finish;
  end
endmodule
