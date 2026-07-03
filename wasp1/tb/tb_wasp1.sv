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
  bit          otp_image_loaded;            // Set when +WASP1_OTP_HEX loaded a firmware image.
  bit          sw_trace;                    // Enables verbose firmware execution diagnostics.
  string       otp_hex_path;                // Runtime plusarg path to readmemh OTP image.
  int unsigned uart_addr_count;             // Number of UART AHB address phases observed.
  int unsigned uart_tx_push_count;          // Number of bytes accepted into the UART TX FIFO.
  logic [31:0] last_ex_pc;                  // Most recent execute-stage PC for timeout diagnostics.
  logic [31:0] last_ex_instr;               // Most recent execute-stage instruction for diagnostics.
  int unsigned core_rsp_count;              // Number of core bridge responses observed.

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

  // Lightweight software-run trace counters. They stay quiet during passing
  // runs except for a TX FIFO push, and provide enough context to debug a
  // firmware-loaded timeout without opening a waveform first.
  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      uart_addr_count <= 0;
      uart_tx_push_count <= 0;
      last_ex_pc <= '0;
      last_ex_instr <= '0;
      core_rsp_count <= 0;
    end else begin
      if (u_wasp1.ex_valid) begin
        last_ex_pc <= u_wasp1.ex_pc;
        last_ex_instr <= u_wasp1.ex_instr;
      end
      if (u_wasp1.slave_hsel[AHB_SLAVE_UART] && u_wasp1.slave_htrans[1]) begin
        uart_addr_count <= uart_addr_count + 1;
      end
      if (u_wasp1.u_ahb_uart.tx_fifo_push) begin
        uart_tx_push_count <= uart_tx_push_count + 1;
        if (sw_trace) begin
          $display("[%0t] tb_wasp1 UART TX FIFO push data=0x%02h",
                   $time, u_wasp1.u_ahb_uart.tx_fifo_wdata);
        end
      end
      if (u_wasp1.u_core_ahb_bridge.state_q == u_wasp1.u_core_ahb_bridge.BR_RESP) begin
        core_rsp_count <= core_rsp_count + 1;
        if (sw_trace && core_rsp_count < 8) begin
          $display("[%0t] tb_wasp1 core bridge rsp addr=0x%08h write=%0b rdata=0x%08h hresp=%0b",
                   $time, u_wasp1.u_core_ahb_bridge.req_addr_q,
                   u_wasp1.u_core_ahb_bridge.req_write_q,
                   u_wasp1.core_hrdata, u_wasp1.core_hresp);
        end
      end
    end
  end

  // Load an optional software image into the executable OTP data array before
  // reset is released. The generated hex is word-oriented little-endian data
  // from llvm_s1/scripts/wasp1_make_otp_image.py.
  initial begin
    otp_image_loaded = 1'b0;
    sw_trace = $test$plusargs("WASP1_SW_TRACE");
    otp_hex_path = "";
    if ($value$plusargs("WASP1_OTP_HEX=%s", otp_hex_path)) begin
      #1ps;
      $readmemh(otp_hex_path, u_wasp1.u_ahb_otp.otp_mem_q);
      otp_image_loaded = 1'b1;
      $display("tb_wasp1 loaded OTP image: %s", otp_hex_path);
      if (sw_trace) begin
        $display("tb_wasp1 OTP word[0]=0x%08h word[1]=0x%08h word[2]=0x%08h word[3]=0x%08h",
                 u_wasp1.u_ahb_otp.otp_mem_q[0], u_wasp1.u_ahb_otp.otp_mem_q[1],
                 u_wasp1.u_ahb_otp.otp_mem_q[2], u_wasp1.u_ahb_otp.otp_mem_q[3]);
      end
    end
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

  task automatic dump_sw_timeout_diagnostics;
    begin
      $display("tb_wasp1 SW timeout diagnostics:");
      $display("  core: ex_valid=%0b last_pc=0x%08h last_instr=0x%08h commit_valid=%0b commit_rd=%0d commit_data=0x%08h",
               u_wasp1.ex_valid, last_ex_pc, last_ex_instr,
               u_wasp1.commit_valid, u_wasp1.commit_rd, u_wasp1.commit_data);
      $display("  frontend: pc_valid=%0b pc_ready=%0b pc=0x%08h fetch_valid=%0b fetch_ready=%0b instr_valid=%0b instr_ready=%0b instr_pc=0x%08h instr=0x%08h ibuf_empty=%0b ibuf_full=%0b",
               u_wasp1.u_tile.u_frontend.pc_valid,
               u_wasp1.u_tile.u_frontend.pc_ready,
               u_wasp1.u_tile.u_frontend.pc,
               u_wasp1.u_tile.u_frontend.fetch_valid,
               u_wasp1.u_tile.u_frontend.fetch_ready,
               u_wasp1.u_tile.instr_valid,
               u_wasp1.u_tile.instr_ready,
               u_wasp1.u_tile.instr_pc,
               u_wasp1.u_tile.instr,
               u_wasp1.u_tile.u_frontend.ibuf_empty,
               u_wasp1.u_tile.u_frontend.ibuf_full);
      $display("  frontend_detail: fetch_state=%0d fetch_kill=%0b imem_rsp_valid=%0b imem_rsp_ready=%0b imem_rsp_data=0x%08h ibuf_push=%0b ibuf_pop=%0b ibuf_count=%0d",
               u_wasp1.u_tile.u_frontend.fetch_u.state_q,
               u_wasp1.u_tile.u_frontend.fetch_u.kill_q,
               u_wasp1.u_tile.frontend_imem_if.rsp_valid,
               u_wasp1.u_tile.frontend_imem_if.rsp_ready,
               u_wasp1.u_tile.frontend_imem_if.rsp_rdata,
               u_wasp1.u_tile.u_frontend.ibuf_u.push_fire,
               u_wasp1.u_tile.u_frontend.ibuf_u.pop_fire,
               u_wasp1.u_tile.u_frontend.ibuf_u.count_q);
      $display("  icache: ctrl_state=%0d miss_addr=0x%08h rsp_data=0x%08h rsp_err=%0b refill_state=%0d beat=%0d line_valid=%0b line_ready=%0b line_addr=0x%08h line_error=%0b",
               u_wasp1.u_tile.u_icache.u_ctrl.state_q,
               u_wasp1.u_tile.u_icache.u_ctrl.miss_addr_q,
               u_wasp1.u_tile.u_icache.u_ctrl.rsp_data_q,
               u_wasp1.u_tile.u_icache.u_ctrl.rsp_err_q,
               u_wasp1.u_tile.u_icache.u_refill.state_q,
               u_wasp1.u_tile.u_icache.u_refill.beat_q,
               u_wasp1.u_tile.u_icache.refill_line_valid,
               u_wasp1.u_tile.u_icache.refill_line_ready,
               u_wasp1.u_tile.u_icache.refill_line_addr,
               u_wasp1.u_tile.u_icache.refill_line_error);
      $display("  trap: valid=%0b cause=0x%02h tval=0x%08h pc=0x%08h redirect=%0b redirect_pc=0x%08h dbg_running=%0b dbg_halted=%0b",
               trap_valid, trap_cause, u_wasp1.trap_tval, u_wasp1.trap_pc,
               u_wasp1.redirect_valid, u_wasp1.redirect_pc, dbg_running, dbg_halted);
      $display("  core_ahb: htrans=%0b haddr=0x%08h hwrite=%0b hsize=%0d hwdata=0x%08h hrdata=0x%08h hready=%0b hresp=%0b bridge_state=%0d",
               u_wasp1.core_htrans, u_wasp1.core_haddr, u_wasp1.core_hwrite,
               u_wasp1.core_hsize, u_wasp1.core_hwdata, u_wasp1.core_hrdata,
               u_wasp1.core_hready, u_wasp1.core_hresp,
               u_wasp1.u_core_ahb_bridge.state_q);
      $display("  fabric: slave_hsel=0x%0h slave_haddr=0x%08h slave_htrans=%0b slave_hwrite=%0b slave_hsize=%0d grant=%0b default_sel=%0b select_err=%0b",
               u_wasp1.slave_hsel, u_wasp1.slave_haddr, u_wasp1.slave_htrans,
               u_wasp1.slave_hwrite, u_wasp1.slave_hsize, bus_grant_idx,
               u_wasp1.default_sel, u_wasp1.slave_select_err);
      $display("  dcache: ctrl_state=%0d req_valid=%0b req_ready=%0b req_addr=0x%08h req_write=%0b rsp_valid=%0b rsp_ready=%0b rsp_err=%0b refill_state=%0d store_state=%0d",
               u_wasp1.u_tile.u_dcache.u_ctrl.state_q,
               u_wasp1.u_tile.core_dmem_if.req_valid,
               u_wasp1.u_tile.core_dmem_if.req_ready,
               u_wasp1.u_tile.core_dmem_if.req_addr,
               u_wasp1.u_tile.core_dmem_if.req_write,
               u_wasp1.u_tile.core_dmem_if.rsp_valid,
               u_wasp1.u_tile.core_dmem_if.rsp_ready,
               u_wasp1.u_tile.core_dmem_if.rsp_err,
               u_wasp1.u_tile.u_dcache.u_refill.state_q,
               u_wasp1.u_tile.u_dcache.u_store.state_q);
      $display("  uart: addr_count=%0d tx_push_count=%0d enable=%0b tx_en=%0b baud_div=%0d tx_ready=%0b tx_busy=%0b tx_valid=%0b tx_fifo_ready=%0b tx_fifo_wdata=0x%02h",
               uart_addr_count, uart_tx_push_count, u_wasp1.u_ahb_uart.enable_q,
               u_wasp1.u_ahb_uart.tx_en_q, u_wasp1.u_ahb_uart.baud_div_q,
               u_wasp1.u_ahb_uart.tx_ready, u_wasp1.u_ahb_uart.tx_busy,
               u_wasp1.u_ahb_uart.tx_fifo_valid, u_wasp1.u_ahb_uart.tx_fifo_ready,
               u_wasp1.u_ahb_uart.tx_fifo_wdata);
    end
  endtask

  task automatic wait_for_uart_tx_activity;
    int unsigned timeout;
    begin
      timeout = 0;
      while ((uart_tx !== 1'b0) && timeout < 20000) begin
        @(posedge hclk);
        #1ns;
        timeout++;
      end
      if (uart_tx !== 1'b0) begin
        dump_sw_timeout_diagnostics();
        $error("loaded OTP firmware did not drive a UART TX start bit");
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
    if (otp_image_loaded) begin
      wait_for_uart_tx_activity();
    end

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
