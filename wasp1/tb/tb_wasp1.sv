`timescale 1ns/1ps

// Smoke-level wasp1 SoC integration testbench.
//
// This bench does not replace module-level verification. It checks that the
// integrated top resets cleanly, exposes benign IO defaults, and allows the
// core-side instruction path to make progress through the OTP/fabric path.
module tb_wasp1;
  import wasp1_pkg::*;
  import debug_dmi_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int GPIO_WIDTH = 32;
  localparam int DMI_DR_WIDTH = DMI_ADDR_WIDTH + 34;
  localparam logic [31:0] JTAG_IDCODE_VALUE = 32'h1000_01CF;
  localparam logic [4:0] JTAG_IR_DTMCS = 5'b10000;
  localparam logic [4:0] JTAG_IR_DMI = 5'b10001;
  localparam int unsigned OTP_PROGRAM_WORD_IDX = 32'h0000_3FA0;
  localparam logic [31:0] OTP_PROGRAM_EXPECTED_DATA = 32'h1357_2468;
  localparam int unsigned DMA_COPY_SRC_WORD_IDX = 32'h0000_3000 >> 2;
  localparam int unsigned DMA_COPY_DST_WORD_IDX = 32'h0000_3040 >> 2;
  localparam int unsigned DMA_COPY_WORDS = 4;
  localparam int unsigned DMA_IRQ_SRC_WORD_IDX = 32'h0000_3200 >> 2;
  localparam int unsigned DMA_IRQ_DST_WORD_IDX = 32'h0000_3240 >> 2;
  localparam int unsigned DMA_IRQ_WORDS = 4;
  localparam int unsigned DMA_IRQ_MAGIC_WORD_IDX = 32'h0000_3300 >> 2;
  localparam int unsigned DMA_IRQ_MCAUSE_WORD_IDX = 32'h0000_3304 >> 2;
  localparam int unsigned DMA_IRQ_CLAIM_WORD_IDX = 32'h0000_3308 >> 2;
  localparam int unsigned DMA_IRQ_DONE_WORD_IDX = 32'h0000_330c >> 2;
  localparam logic [31:0] DMA_IRQ_EXPECTED_MAGIC = 32'h444d_4149;
  localparam logic [31:0] DMA_IRQ_EXPECTED_DONE = 32'h4558_4954;
  localparam logic [31:0] DMA_IRQ_EXPECTED_MCAUSE = 32'h8000_000b;
  localparam logic [31:0] DMA_IRQ_EXPECTED_CLAIM = 32'h0000_0005;
  localparam int unsigned GPIO_IRQ_READY_WORD_IDX = 32'h0000_3400 >> 2;
  localparam int unsigned GPIO_IRQ_MAGIC_WORD_IDX = 32'h0000_3404 >> 2;
  localparam int unsigned GPIO_IRQ_MCAUSE_WORD_IDX = 32'h0000_3408 >> 2;
  localparam int unsigned GPIO_IRQ_CLAIM_WORD_IDX = 32'h0000_340c >> 2;
  localparam int unsigned GPIO_IRQ_LEVEL_WORD_IDX = 32'h0000_3410 >> 2;
  localparam int unsigned GPIO_IRQ_DONE_WORD_IDX = 32'h0000_3414 >> 2;
  localparam logic [31:0] GPIO_IRQ_EXPECTED_READY = 32'h4750_4459;
  localparam logic [31:0] GPIO_IRQ_EXPECTED_MAGIC = 32'h4750_4951;
  localparam logic [31:0] GPIO_IRQ_EXPECTED_DONE = 32'h4750_4f4b;
  localparam logic [31:0] GPIO_IRQ_EXPECTED_MCAUSE = 32'h8000_000b;
  localparam logic [31:0] GPIO_IRQ_EXPECTED_CLAIM = 32'h0000_0004;
  localparam int unsigned UART_IRQ_MAGIC_WORD_IDX = 32'h0000_3500 >> 2;
  localparam int unsigned UART_IRQ_MCAUSE_WORD_IDX = 32'h0000_3504 >> 2;
  localparam int unsigned UART_IRQ_CLAIM_WORD_IDX = 32'h0000_3508 >> 2;
  localparam int unsigned UART_IRQ_STATUS_WORD_IDX = 32'h0000_350c >> 2;
  localparam int unsigned UART_IRQ_DONE_WORD_IDX = 32'h0000_3510 >> 2;
  localparam logic [31:0] UART_IRQ_EXPECTED_MAGIC = 32'h5552_4951;
  localparam logic [31:0] UART_IRQ_EXPECTED_DONE = 32'h5552_4f4b;
  localparam logic [31:0] UART_IRQ_EXPECTED_MCAUSE = 32'h8000_000b;
  localparam logic [31:0] UART_IRQ_EXPECTED_CLAIM = 32'h0000_0002;
  localparam logic [31:0] UART_IRQ_EXPECTED_STATUS = 32'h0000_0001;
  localparam int unsigned TIMER_IRQ_MAGIC_WORD_IDX = 32'h0000_3100 >> 2;
  localparam int unsigned TIMER_IRQ_MCAUSE_WORD_IDX = 32'h0000_3104 >> 2;
  localparam int unsigned TIMER_IRQ_MEPC_WORD_IDX = 32'h0000_3108 >> 2;
  localparam int unsigned TIMER_IRQ_DONE_WORD_IDX = 32'h0000_310c >> 2;
  localparam logic [31:0] TIMER_IRQ_EXPECTED_MAGIC = 32'h5449_4d52;
  localparam logic [31:0] TIMER_IRQ_EXPECTED_DONE = 32'h4952_5121;
  localparam logic [31:0] TIMER_IRQ_EXPECTED_MCAUSE = 32'h8000_0007;
  localparam logic [31:0] DMA_COPY_EXPECTED [DMA_COPY_WORDS] = '{
    32'h1122_3344,
    32'h5566_7788,
    32'h99aa_bbcc,
    32'hddee_ff00
  };
  localparam logic [31:0] DMA_IRQ_EXPECTED [DMA_IRQ_WORDS] = '{
    32'h1020_3040,
    32'h5060_7080,
    32'h90a0_b0c0,
    32'hd0e0_f000
  };

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
  logic                  jtag_tck;          // JTAG test clock stimulus.
  logic                  jtag_trst_n;       // Active-low JTAG reset stimulus.
  logic                  jtag_tms;          // JTAG mode-select stimulus.
  logic                  jtag_tdi;          // JTAG serial input stimulus.
  logic                  jtag_tdo;          // JTAG serial output observation.
  logic                  dbg_halted;        // Debug halted status.
  logic                  dbg_running;       // Debug running status.
  logic                  dbg_dmactive;      // Debug Module active observation.
  logic                  dbg_ndmreset;      // Debug Module ndmreset observation.
  logic                  dbg_dtm_hardreset; // Debug DTM hard reset pulse.

  int unsigned pass_count;
  bit          otp_image_loaded;            // Set when +WASP1_OTP_HEX loaded a firmware image.
  bit          otp_program_check;           // Selects OTP programming firmware assertions.
  bit          dma_copy_check;              // Selects DMA real-memory-copy firmware assertions.
  bit          dma_irq_check;               // Selects DMA external interrupt firmware assertions.
  bit          gpio_irq_check;              // Selects GPIO external interrupt firmware assertions.
  bit          uart_irq_check;              // Selects UART external interrupt firmware assertions.
  bit          timer_irq_check;             // Selects timer interrupt firmware assertions.
  bit          sw_trace;                    // Enables verbose firmware execution diagnostics.
  bit          dma_trace;                   // Enables focused DMA/fabric diagnostics.
  bit          gpio_irq_trace;              // Enables focused GPIO/INTC interrupt diagnostics.
  string       otp_hex_path;                // Runtime plusarg path to readmemh OTP image.
  int unsigned uart_addr_count;             // Number of UART AHB address phases observed.
  int unsigned uart_tx_push_count;          // Number of bytes accepted into the UART TX FIFO.
  logic [31:0] last_ex_pc;                  // Most recent execute-stage PC for timeout diagnostics.
  logic [31:0] last_ex_instr;               // Most recent execute-stage instruction for diagnostics.
  int unsigned core_rsp_count;              // Number of core bridge responses observed.
  bit          otp_fasttext_seen;           // Set after execute PC enters I-SRAM for OTP programming.

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
    .jtag_tck_i(jtag_tck),
    .jtag_trst_ni(jtag_trst_n),
    .jtag_tms_i(jtag_tms),
    .jtag_tdi_i(jtag_tdi),
    .jtag_tdo_o(jtag_tdo),
    .dbg_halted_o(dbg_halted),
    .dbg_running_o(dbg_running),
    .dbg_dmactive_o(dbg_dmactive),
    .dbg_ndmreset_o(dbg_ndmreset),
    .dbg_dtm_hardreset_o(dbg_dtm_hardreset)
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
      otp_fasttext_seen <= 1'b0;
    end else begin
      if (u_wasp1.ex_valid) begin
        last_ex_pc <= u_wasp1.ex_pc;
        last_ex_instr <= u_wasp1.ex_instr;
        if (otp_program_check &&
            (u_wasp1.ex_pc >= ISRAM_BASE) &&
            (u_wasp1.ex_pc < (ISRAM_BASE + ISRAM_SIZE))) begin
          otp_fasttext_seen <= 1'b1;
        end
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
      if ((u_wasp1.u_core_ahb_bridge.state_q == u_wasp1.u_core_ahb_bridge.BR_DATA_WAIT) &&
          u_wasp1.core_hready) begin
        core_rsp_count <= core_rsp_count + 1;
        if (sw_trace && core_rsp_count < 8) begin
          $display("[%0t] tb_wasp1 core bridge rsp addr=0x%08h write=%0b rdata=0x%08h hresp=%0b",
                   $time, u_wasp1.u_core_ahb_bridge.req_addr_q,
                   u_wasp1.u_core_ahb_bridge.req_write_q,
                   u_wasp1.core_hrdata, u_wasp1.core_hresp);
        end
      end
      if ((sw_trace || dma_trace) && u_wasp1.u_ahb_dsram.req_valid_q &&
          u_wasp1.u_ahb_dsram.req_write_q && !u_wasp1.u_ahb_dsram.req_err_q) begin
        $display("[%0t] tb_wasp1 DSRAM write addr=0x%08h data=0x%08h grant=%0b dma_state=%0d",
                 $time,
                 DSRAM_BASE + u_wasp1.u_ahb_dsram.req_addr_q,
                 u_wasp1.slave_hwdata,
                 bus_grant_idx,
                 u_wasp1.u_ahb_dma.state_q);
      end
      if (dma_trace && (u_wasp1.u_ahb_dma.state_q != u_wasp1.u_ahb_dma.DMA_IDLE)) begin
        $display("[%0t] tb_wasp1 DMA state=%0d m_addr=0x%08h m_trans=%0b m_write=%0b m_wdata=0x%08h m_rdata=0x%08h m_ready=%0b m_resp=%0b grant=%0b slave_sel=0x%0h slave_addr=0x%08h slave_write=%0b",
                 $time,
                 u_wasp1.u_ahb_dma.state_q,
                 u_wasp1.dma_m_haddr,
                 u_wasp1.dma_m_htrans,
                 u_wasp1.dma_m_hwrite,
                 u_wasp1.dma_m_hwdata,
                 u_wasp1.dma_m_hrdata,
                 u_wasp1.dma_m_hready,
                 u_wasp1.dma_m_hresp,
                 bus_grant_idx,
                 u_wasp1.slave_hsel,
                 u_wasp1.slave_haddr,
                 u_wasp1.slave_hwrite);
      end
      if (gpio_irq_trace &&
          (u_wasp1.gpio_irq || u_wasp1.external_irq ||
           (u_wasp1.u_ahb_intc.pending_q != '0) ||
           (u_wasp1.u_ahb_intc.req_valid_q &&
            ((u_wasp1.u_ahb_intc.req_offset_q == INTC_CLAIM_OFFSET) ||
             (u_wasp1.u_ahb_intc.req_offset_q == INTC_PENDING_OFFSET) ||
             (u_wasp1.u_ahb_intc.req_offset_q == INTC_ENABLE_OFFSET))))) begin
        $display("[%0t] tb_wasp1 GPIO_IRQ gpio_in0=%0b gpio_sync=0x%08h gpio_prev=0x%08h gpio_status=0x%08h gpio_en=0x%08h gpio_irq=%0b intc_pending=0x%0h intc_en=0x%0h best=%0d meip=%0b req=%0b write=%0b off=0x%08h rdata=0x%08h hwdata=0x%08h",
                 $time,
                 gpio_in[0],
                 u_wasp1.u_ahb_gpio.in_sync_q,
                 u_wasp1.u_ahb_gpio.in_prev_q,
                 u_wasp1.u_ahb_gpio.irq_status_q,
                 u_wasp1.u_ahb_gpio.irq_en_q,
                 u_wasp1.gpio_irq,
                 u_wasp1.u_ahb_intc.pending_q,
                 u_wasp1.u_ahb_intc.enable_q,
                 u_wasp1.u_ahb_intc.best_id,
                 u_wasp1.u_ahb_intc.meip_o,
                 u_wasp1.u_ahb_intc.req_valid_q,
                 u_wasp1.u_ahb_intc.req_write_q,
                 u_wasp1.u_ahb_intc.req_offset_q,
                 u_wasp1.u_ahb_intc.hrdata_o,
                 u_wasp1.slave_hwdata);
      end
    end
  end

  // Load an optional software image into the executable OTP data array before
  // reset is released. The generated hex is word-oriented little-endian data
  // from llvm_s1/scripts/wasp1_make_otp_image.py.
  initial begin
    otp_image_loaded = 1'b0;
    otp_program_check = $test$plusargs("WASP1_OTP_PROGRAM_CHECK");
    dma_copy_check = $test$plusargs("WASP1_DMA_COPY_CHECK");
    dma_irq_check = $test$plusargs("WASP1_DMA_IRQ_CHECK");
    gpio_irq_check = $test$plusargs("WASP1_GPIO_IRQ_CHECK");
    uart_irq_check = $test$plusargs("WASP1_UART_IRQ_CHECK");
    timer_irq_check = $test$plusargs("WASP1_TIMER_IRQ_CHECK");
    sw_trace = $test$plusargs("WASP1_SW_TRACE");
    dma_trace = $test$plusargs("WASP1_DMA_TRACE");
    gpio_irq_trace = $test$plusargs("WASP1_GPIO_IRQ_TRACE");
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
      jtag_tck = 1'b0;
      jtag_trst_n = 1'b0;
      jtag_tms = 1'b1;
      jtag_tdi = 1'b0;
    end
  endtask

  function automatic logic [63:0] jtag_dmi_packet(
    input logic [1:0]                op,
    input logic [DMI_ADDR_WIDTH-1:0] addr,
    input logic [31:0]               data
  );
    begin
      jtag_dmi_packet = 64'h0;
      jtag_dmi_packet[1:0] = op;
      jtag_dmi_packet[33:2] = data;
      jtag_dmi_packet[DMI_DR_WIDTH-1:34] = addr;
    end
  endfunction

  task automatic jtag_cycle(
    input  logic tms_value,
    input  logic tdi_value,
    output logic tdo_sample
  );
    begin
      jtag_tms = tms_value;
      jtag_tdi = tdi_value;
      #3ns;
      jtag_tck = 1'b1;
      #1ns;
      tdo_sample = jtag_tdo;
      #4ns;
      jtag_tck = 1'b0;
      #2ns;
    end
  endtask

  task automatic jtag_cycle_ignore(input logic tms_value, input logic tdi_value);
    logic unused_tdo;
    begin
      jtag_cycle(tms_value, tdi_value, unused_tdo);
    end
  endtask

  task automatic jtag_reset_to_idle;
    int i;
    begin
      for (i = 0; i < 6; i++) begin
        jtag_cycle_ignore(1'b1, 1'b0);
      end
      jtag_cycle_ignore(1'b0, 1'b0);
    end
  endtask

  task automatic jtag_set_ir(input logic [4:0] ir_value);
    int i;
    logic unused_tdo;
    begin
      jtag_cycle_ignore(1'b1, 1'b0);
      jtag_cycle_ignore(1'b1, 1'b0);
      jtag_cycle_ignore(1'b0, 1'b0);
      jtag_cycle_ignore(1'b0, 1'b0);
      for (i = 0; i < 5; i++) begin
        jtag_cycle(i == 4, ir_value[i], unused_tdo);
      end
      jtag_cycle_ignore(1'b1, 1'b0);
      jtag_cycle_ignore(1'b0, 1'b0);
    end
  endtask

  task automatic jtag_scan_dr(
    input  int          width,
    input  logic [63:0] data_in,
    output logic [63:0] data_out
  );
    int i;
    logic tdo_bit;
    begin
      data_out = 64'h0;
      jtag_cycle_ignore(1'b1, 1'b0);
      jtag_cycle_ignore(1'b0, 1'b0);
      jtag_cycle_ignore(1'b0, 1'b0);
      for (i = 0; i < width; i++) begin
        jtag_cycle(i == (width - 1), data_in[i], tdo_bit);
        data_out[i] = tdo_bit;
      end
      jtag_cycle_ignore(1'b1, 1'b0);
      jtag_cycle_ignore(1'b0, 1'b0);
    end
  endtask

  task automatic jtag_idle_cycles(input int cycles);
    int i;
    begin
      for (i = 0; i < cycles; i++) begin
        jtag_cycle_ignore(1'b0, 1'b0);
      end
    end
  endtask

  task automatic jtag_dmi_transfer(
    input  logic [1:0]                op,
    input  logic [DMI_ADDR_WIDTH-1:0] addr,
    input  logic [31:0]               data,
    output logic [1:0]                rsp,
    output logic [31:0]               rsp_data,
    output logic [DMI_ADDR_WIDTH-1:0] rsp_addr
  );
    logic [63:0] scan_out;
    begin
      jtag_set_ir(JTAG_IR_DMI);
      jtag_scan_dr(DMI_DR_WIDTH, jtag_dmi_packet(op, addr, data), scan_out);
      repeat (8) @(posedge hclk);
      jtag_idle_cycles(4);
      jtag_scan_dr(DMI_DR_WIDTH, jtag_dmi_packet(DMI_OP_NOP, '0, 32'h0), scan_out);
      rsp = scan_out[1:0];
      rsp_data = scan_out[33:2];
      rsp_addr = scan_out[DMI_DR_WIDTH-1:34];
    end
  endtask

  task automatic check_jtag_dmstatus_smoke;
    logic [63:0] scan_out;
    logic [31:0] dtmcs;
    logic [1:0] rsp;
    logic [31:0] rsp_data;
    logic [DMI_ADDR_WIDTH-1:0] rsp_addr;
    begin
      jtag_reset_to_idle();

      jtag_scan_dr(32, 64'h0, scan_out);
      if (scan_out[31:0] !== JTAG_IDCODE_VALUE) begin
        $error("JTAG IDCODE mismatch: got=0x%08h expected=0x%08h",
               scan_out[31:0], JTAG_IDCODE_VALUE);
        $fatal(1);
      end
      pass_count++;

      jtag_set_ir(JTAG_IR_DTMCS);
      jtag_scan_dr(32, 64'h0, scan_out);
      dtmcs = scan_out[31:0];
      if ((dtmcs[3:0] !== 4'd1) || (dtmcs[9:4] !== 6'(DMI_ADDR_WIDTH)) ||
          (dtmcs[11:10] !== DMI_RESP_SUCCESS)) begin
        $error("JTAG DTMCS mismatch: dtmcs=0x%08h", dtmcs);
        $fatal(1);
      end
      pass_count++;

      jtag_dmi_transfer(DMI_OP_WRITE, DMI_ADDR_DMCONTROL, 32'h0000_0001,
                        rsp, rsp_data, rsp_addr);
      if ((rsp !== DMI_RESP_SUCCESS) || (rsp_addr !== DMI_ADDR_DMCONTROL) ||
          !dbg_dmactive || dbg_ndmreset) begin
        $error("JTAG dmcontrol activate failed: rsp=%0b addr=0x%02h dmactive=%0b ndmreset=%0b",
               rsp, rsp_addr, dbg_dmactive, dbg_ndmreset);
        $fatal(1);
      end
      pass_count++;

      jtag_dmi_transfer(DMI_OP_READ, DMI_ADDR_DMSTATUS, 32'h0, rsp, rsp_data, rsp_addr);
      if ((rsp !== DMI_RESP_SUCCESS) || (rsp_addr !== DMI_ADDR_DMSTATUS) ||
          ((rsp_data & 32'h0000_0C82) !== 32'h0000_0C82)) begin
        $error("JTAG dmstatus read failed: rsp=%0b addr=0x%02h data=0x%08h",
               rsp, rsp_addr, rsp_data);
        $fatal(1);
      end
      pass_count++;
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
      $display("  csr: mepc=0x%08h mcause=0x%08h mtval=0x%08h mtvec=0x%08h",
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mepc_q,
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q,
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mtval_q,
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mtvec_q);
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
      $display("  dma: state=%0d src=0x%08h dst=0x%08h len=%0d cur_src=0x%08h cur_dst=0x%08h rem=%0d data=0x%08h done=%0b err=%0b irq=%0b m_haddr=0x%08h m_htrans=%0b m_hwrite=%0b m_hready=%0b m_hresp=%0b",
               u_wasp1.u_ahb_dma.state_q,
               u_wasp1.u_ahb_dma.src_q,
               u_wasp1.u_ahb_dma.dst_q,
               u_wasp1.u_ahb_dma.len_q,
               u_wasp1.u_ahb_dma.cur_src_q,
               u_wasp1.u_ahb_dma.cur_dst_q,
               u_wasp1.u_ahb_dma.remaining_q,
               u_wasp1.u_ahb_dma.data_q,
               u_wasp1.u_ahb_dma.done_q,
               u_wasp1.u_ahb_dma.error_q,
               u_wasp1.dma_irq,
               u_wasp1.dma_m_haddr,
               u_wasp1.dma_m_htrans,
               u_wasp1.dma_m_hwrite,
               u_wasp1.dma_m_hready,
               u_wasp1.dma_m_hresp);
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

  task automatic wait_for_otp_program_activity;
    int unsigned timeout;
    begin
      timeout = 0;
      while ((u_wasp1.u_ahb_otp.otp_mem_q[OTP_PROGRAM_WORD_IDX] !==
              OTP_PROGRAM_EXPECTED_DATA) &&
             timeout < 30000) begin
        @(posedge hclk);
        #1ns;
        timeout++;
      end

      if (u_wasp1.u_ahb_otp.otp_mem_q[OTP_PROGRAM_WORD_IDX] !==
          OTP_PROGRAM_EXPECTED_DATA) begin
        dump_sw_timeout_diagnostics();
        $error("OTP programming firmware did not program word[%0d]: got=0x%08h expected=0x%08h",
               OTP_PROGRAM_WORD_IDX,
               u_wasp1.u_ahb_otp.otp_mem_q[OTP_PROGRAM_WORD_IDX],
               OTP_PROGRAM_EXPECTED_DATA);
        $fatal(1);
      end
      if (!otp_fasttext_seen) begin
        $error("OTP programming firmware did not execute from I-SRAM fasttext");
        $fatal(1);
      end
      if (u_wasp1.u_ahb_otp.done_q !== 1'b1 ||
          u_wasp1.u_ahb_otp.error_q !== 1'b0) begin
        $error("OTP programming status mismatch: done=%0b error=%0b",
               u_wasp1.u_ahb_otp.done_q, u_wasp1.u_ahb_otp.error_q);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_for_dma_copy_activity;
    int unsigned timeout;
    bit          copy_done;
    begin
      timeout = 0;
      copy_done = 1'b0;
      while (!copy_done && timeout < 40000) begin
        copy_done = 1'b1;
        for (int idx = 0; idx < DMA_COPY_WORDS; idx++) begin
          if (u_wasp1.u_ahb_dsram.mem_q[DMA_COPY_DST_WORD_IDX + idx] !==
              DMA_COPY_EXPECTED[idx]) begin
            copy_done = 1'b0;
          end
        end
        if (u_wasp1.u_ahb_dma.done_q !== 1'b1 ||
            u_wasp1.u_ahb_dma.error_q !== 1'b0 ||
            u_wasp1.dma_irq !== 1'b1) begin
          copy_done = 1'b0;
        end
        if (!copy_done) begin
          @(posedge hclk);
          #1ns;
          timeout++;
        end
      end

      if (!copy_done) begin
        dump_sw_timeout_diagnostics();
        for (int idx = 0; idx < DMA_COPY_WORDS; idx++) begin
          $display("  dma src[%0d] got=0x%08h expected=0x%08h",
                   idx,
                   u_wasp1.u_ahb_dsram.mem_q[DMA_COPY_SRC_WORD_IDX + idx],
                   DMA_COPY_EXPECTED[idx]);
          $display("  dma dst[%0d] got=0x%08h expected=0x%08h",
                   idx,
                   u_wasp1.u_ahb_dsram.mem_q[DMA_COPY_DST_WORD_IDX + idx],
                   DMA_COPY_EXPECTED[idx]);
        end
        $error("DMA copy firmware did not update D-SRAM destination buffer");
        $fatal(1);
      end
      for (int idx = 0; idx < DMA_COPY_WORDS; idx++) begin
        if (u_wasp1.u_ahb_dsram.mem_q[DMA_COPY_SRC_WORD_IDX + idx] !==
            DMA_COPY_EXPECTED[idx]) begin
          $error("DMA source word[%0d] changed: got=0x%08h expected=0x%08h",
                 idx,
                 u_wasp1.u_ahb_dsram.mem_q[DMA_COPY_SRC_WORD_IDX + idx],
                 DMA_COPY_EXPECTED[idx]);
          $fatal(1);
        end
      end
      if (u_wasp1.u_ahb_dma.done_q !== 1'b1 ||
          u_wasp1.u_ahb_dma.error_q !== 1'b0 ||
          u_wasp1.dma_irq !== 1'b1) begin
        $error("DMA status mismatch: done=%0b error=%0b irq=%0b",
               u_wasp1.u_ahb_dma.done_q, u_wasp1.u_ahb_dma.error_q, u_wasp1.dma_irq);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_for_dma_irq_activity;
    int unsigned timeout;
    logic [31:0] magic_word;
    logic [31:0] mcause_word;
    logic [31:0] claim_word;
    logic [31:0] done_word;
    bit          irq_done;
    begin
      timeout = 0;
      irq_done = 1'b0;
      magic_word = '0;
      done_word = '0;
      while (!irq_done && timeout < 50000) begin
        irq_done = 1'b1;
        magic_word = u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_MAGIC_WORD_IDX];
        done_word = u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_DONE_WORD_IDX];
        if ((magic_word !== DMA_IRQ_EXPECTED_MAGIC) ||
            (done_word !== DMA_IRQ_EXPECTED_DONE)) begin
          irq_done = 1'b0;
        end
        for (int idx = 0; idx < DMA_IRQ_WORDS; idx++) begin
          if (u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_DST_WORD_IDX + idx] !==
              DMA_IRQ_EXPECTED[idx]) begin
            irq_done = 1'b0;
          end
        end
        if (!irq_done) begin
          @(posedge hclk);
          #1ns;
          timeout++;
        end
      end

      mcause_word = u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_MCAUSE_WORD_IDX];
      claim_word = u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_CLAIM_WORD_IDX];
      if (!irq_done) begin
        dump_sw_timeout_diagnostics();
        for (int idx = 0; idx < DMA_IRQ_WORDS; idx++) begin
          $display("  dma_irq src[%0d] got=0x%08h expected=0x%08h",
                   idx,
                   u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_SRC_WORD_IDX + idx],
                   DMA_IRQ_EXPECTED[idx]);
          $display("  dma_irq dst[%0d] got=0x%08h expected=0x%08h",
                   idx,
                   u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_DST_WORD_IDX + idx],
                   DMA_IRQ_EXPECTED[idx]);
        end
        $error("DMA IRQ firmware did not complete: magic=0x%08h done=0x%08h mcause=0x%08h claim=0x%08h",
               magic_word, done_word, mcause_word, claim_word);
        $fatal(1);
      end
      if (mcause_word !== DMA_IRQ_EXPECTED_MCAUSE ||
          u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q !==
          DMA_IRQ_EXPECTED_MCAUSE) begin
        $error("DMA IRQ mcause mismatch: mailbox=0x%08h csr=0x%08h expected=0x%08h",
               mcause_word,
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q,
               DMA_IRQ_EXPECTED_MCAUSE);
        $fatal(1);
      end
      if (claim_word !== DMA_IRQ_EXPECTED_CLAIM) begin
        $error("DMA IRQ claim mismatch: got=0x%08h expected=0x%08h",
               claim_word, DMA_IRQ_EXPECTED_CLAIM);
        $fatal(1);
      end
      for (int idx = 0; idx < DMA_IRQ_WORDS; idx++) begin
        if (u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_SRC_WORD_IDX + idx] !==
            DMA_IRQ_EXPECTED[idx]) begin
          $error("DMA IRQ source word[%0d] changed: got=0x%08h expected=0x%08h",
                 idx,
                 u_wasp1.u_ahb_dsram.mem_q[DMA_IRQ_SRC_WORD_IDX + idx],
                 DMA_IRQ_EXPECTED[idx]);
          $fatal(1);
        end
      end
      if (u_wasp1.dma_irq !== 1'b0 || u_wasp1.external_irq !== 1'b0 ||
          u_wasp1.u_ahb_intc.meip_o !== 1'b0) begin
        $error("DMA external IRQ did not deassert: dma_irq=%0b external_irq=%0b meip=%0b",
               u_wasp1.dma_irq, u_wasp1.external_irq, u_wasp1.u_ahb_intc.meip_o);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_for_gpio_irq_activity;
    int unsigned timeout;
    logic [31:0] ready_word;
    logic [31:0] magic_word;
    logic [31:0] mcause_word;
    logic [31:0] claim_word;
    logic [31:0] level_word;
    logic [31:0] done_word;
    begin
      timeout = 0;
      ready_word = '0;
      while ((ready_word !== GPIO_IRQ_EXPECTED_READY) && timeout < 50000) begin
        ready_word = u_wasp1.u_ahb_dsram.mem_q[GPIO_IRQ_READY_WORD_IDX];
        if (ready_word !== GPIO_IRQ_EXPECTED_READY) begin
          @(posedge hclk);
          #1ns;
          timeout++;
        end
      end
      if (ready_word !== GPIO_IRQ_EXPECTED_READY) begin
        dump_sw_timeout_diagnostics();
        $error("GPIO IRQ firmware did not arm interrupt path");
        $fatal(1);
      end

      // The firmware has enabled GPIO bit 0 as a level-high INTC source.
      gpio_in[0] = 1'b1;

      timeout = 0;
      magic_word = '0;
      done_word = '0;
      while (((magic_word !== GPIO_IRQ_EXPECTED_MAGIC) ||
              (done_word !== GPIO_IRQ_EXPECTED_DONE)) &&
             timeout < 50000) begin
        magic_word = u_wasp1.u_ahb_dsram.mem_q[GPIO_IRQ_MAGIC_WORD_IDX];
        done_word = u_wasp1.u_ahb_dsram.mem_q[GPIO_IRQ_DONE_WORD_IDX];
        if ((magic_word !== GPIO_IRQ_EXPECTED_MAGIC) ||
            (done_word !== GPIO_IRQ_EXPECTED_DONE)) begin
          @(posedge hclk);
          #1ns;
          timeout++;
        end
      end

      mcause_word = u_wasp1.u_ahb_dsram.mem_q[GPIO_IRQ_MCAUSE_WORD_IDX];
      claim_word = u_wasp1.u_ahb_dsram.mem_q[GPIO_IRQ_CLAIM_WORD_IDX];
      level_word = u_wasp1.u_ahb_dsram.mem_q[GPIO_IRQ_LEVEL_WORD_IDX];
      if ((magic_word !== GPIO_IRQ_EXPECTED_MAGIC) ||
          (done_word !== GPIO_IRQ_EXPECTED_DONE)) begin
        dump_sw_timeout_diagnostics();
        $error("GPIO IRQ firmware did not complete: magic=0x%08h done=0x%08h mcause=0x%08h claim=0x%08h level=0x%08h",
               magic_word, done_word, mcause_word, claim_word, level_word);
        $fatal(1);
      end
      if (mcause_word !== GPIO_IRQ_EXPECTED_MCAUSE ||
          u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q !==
          GPIO_IRQ_EXPECTED_MCAUSE) begin
        $error("GPIO IRQ mcause mismatch: mailbox=0x%08h csr=0x%08h expected=0x%08h",
               mcause_word,
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q,
               GPIO_IRQ_EXPECTED_MCAUSE);
        $fatal(1);
      end
      if (claim_word !== GPIO_IRQ_EXPECTED_CLAIM) begin
        $error("GPIO IRQ claim mismatch: got=0x%08h expected=0x%08h",
               claim_word, GPIO_IRQ_EXPECTED_CLAIM);
        $fatal(1);
      end
      if ((level_word & 32'h0000_0001) !== 32'h0000_0001) begin
        $error("GPIO IRQ handler did not observe pin high: level=0x%08h", level_word);
        $fatal(1);
      end
      if (u_wasp1.gpio_irq !== 1'b0 || u_wasp1.external_irq !== 1'b0 ||
          u_wasp1.u_ahb_intc.meip_o !== 1'b0) begin
        $error("GPIO external IRQ did not deassert: gpio_irq=%0b external_irq=%0b meip=%0b",
               u_wasp1.gpio_irq, u_wasp1.external_irq, u_wasp1.u_ahb_intc.meip_o);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_for_uart_irq_activity;
    int unsigned timeout;
    logic [31:0] magic_word;
    logic [31:0] mcause_word;
    logic [31:0] claim_word;
    logic [31:0] status_word;
    logic [31:0] done_word;
    begin
      timeout = 0;
      magic_word = '0;
      done_word = '0;
      while (((magic_word !== UART_IRQ_EXPECTED_MAGIC) ||
              (done_word !== UART_IRQ_EXPECTED_DONE)) &&
             timeout < 50000) begin
        magic_word = u_wasp1.u_ahb_dsram.mem_q[UART_IRQ_MAGIC_WORD_IDX];
        done_word = u_wasp1.u_ahb_dsram.mem_q[UART_IRQ_DONE_WORD_IDX];
        if ((magic_word !== UART_IRQ_EXPECTED_MAGIC) ||
            (done_word !== UART_IRQ_EXPECTED_DONE)) begin
          @(posedge hclk);
          #1ns;
          timeout++;
        end
      end

      mcause_word = u_wasp1.u_ahb_dsram.mem_q[UART_IRQ_MCAUSE_WORD_IDX];
      claim_word = u_wasp1.u_ahb_dsram.mem_q[UART_IRQ_CLAIM_WORD_IDX];
      status_word = u_wasp1.u_ahb_dsram.mem_q[UART_IRQ_STATUS_WORD_IDX];
      if ((magic_word !== UART_IRQ_EXPECTED_MAGIC) ||
          (done_word !== UART_IRQ_EXPECTED_DONE)) begin
        dump_sw_timeout_diagnostics();
        $error("UART IRQ firmware did not complete: magic=0x%08h done=0x%08h mcause=0x%08h claim=0x%08h status=0x%08h",
               magic_word, done_word, mcause_word, claim_word, status_word);
        $fatal(1);
      end
      if (mcause_word !== UART_IRQ_EXPECTED_MCAUSE ||
          u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q !==
          UART_IRQ_EXPECTED_MCAUSE) begin
        $error("UART IRQ mcause mismatch: mailbox=0x%08h csr=0x%08h expected=0x%08h",
               mcause_word,
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q,
               UART_IRQ_EXPECTED_MCAUSE);
        $fatal(1);
      end
      if (claim_word !== UART_IRQ_EXPECTED_CLAIM) begin
        $error("UART IRQ claim mismatch: got=0x%08h expected=0x%08h",
               claim_word, UART_IRQ_EXPECTED_CLAIM);
        $fatal(1);
      end
      if ((status_word & UART_IRQ_EXPECTED_STATUS) !== UART_IRQ_EXPECTED_STATUS) begin
        $error("UART IRQ handler did not observe TX-empty status: status=0x%08h",
               status_word);
        $fatal(1);
      end
      if (u_wasp1.uart_irq !== 1'b0 || u_wasp1.external_irq !== 1'b0 ||
          u_wasp1.u_ahb_intc.meip_o !== 1'b0 ||
          u_wasp1.u_ahb_uart.irq_status_q[UART_IRQ_TX_EMPTY_BIT] !== 1'b0 ||
          u_wasp1.u_ahb_uart.tx_irq_en_q !== 1'b0) begin
        $error("UART external IRQ did not deassert: uart_irq=%0b external_irq=%0b meip=%0b irq_status=0x%0h tx_irq_en=%0b",
               u_wasp1.uart_irq, u_wasp1.external_irq,
               u_wasp1.u_ahb_intc.meip_o,
               u_wasp1.u_ahb_uart.irq_status_q,
               u_wasp1.u_ahb_uart.tx_irq_en_q);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic wait_for_timer_irq_activity;
    int unsigned timeout;
    logic [31:0] magic_word;
    logic [31:0] mcause_word;
    logic [31:0] mepc_word;
    logic [31:0] done_word;
    begin
      timeout = 0;
      magic_word = '0;
      done_word = '0;
      while (((magic_word !== TIMER_IRQ_EXPECTED_MAGIC) ||
              (done_word !== TIMER_IRQ_EXPECTED_DONE)) &&
             timeout < 40000) begin
        magic_word = u_wasp1.u_ahb_dsram.mem_q[TIMER_IRQ_MAGIC_WORD_IDX];
        done_word = u_wasp1.u_ahb_dsram.mem_q[TIMER_IRQ_DONE_WORD_IDX];
        if ((magic_word !== TIMER_IRQ_EXPECTED_MAGIC) ||
            (done_word !== TIMER_IRQ_EXPECTED_DONE)) begin
          @(posedge hclk);
          #1ns;
          timeout++;
        end
      end

      mcause_word = u_wasp1.u_ahb_dsram.mem_q[TIMER_IRQ_MCAUSE_WORD_IDX];
      mepc_word = u_wasp1.u_ahb_dsram.mem_q[TIMER_IRQ_MEPC_WORD_IDX];
      if ((magic_word !== TIMER_IRQ_EXPECTED_MAGIC) ||
          (done_word !== TIMER_IRQ_EXPECTED_DONE)) begin
        dump_sw_timeout_diagnostics();
        $error("timer IRQ firmware did not complete: magic=0x%08h done=0x%08h mcause=0x%08h mepc=0x%08h",
               magic_word, done_word, mcause_word, mepc_word);
        $fatal(1);
      end
      if (mcause_word !== TIMER_IRQ_EXPECTED_MCAUSE ||
          u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q !==
          TIMER_IRQ_EXPECTED_MCAUSE) begin
        $error("timer IRQ mcause mismatch: mailbox=0x%08h csr=0x%08h expected=0x%08h",
               mcause_word,
               u_wasp1.u_tile.u_core.datapath_u.csr_u.mcause_q,
               TIMER_IRQ_EXPECTED_MCAUSE);
        $fatal(1);
      end
      if ((mepc_word[1:0] !== 2'b00) || (mepc_word >= 32'h0000_ff00)) begin
        $error("timer IRQ mepc out of executable OTP range: 0x%08h", mepc_word);
        $fatal(1);
      end
      if (u_wasp1.timer_irq !== 1'b0) begin
        $error("timer IRQ still asserted after handler completion");
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
    jtag_trst_n = 1'b1;
    hresetn = 1'b1;
    @(posedge hclk);
    #1ns;
    pass_count++;

    wait_for_core_fetch_activity();
    wait_for_debug_running_known();
    check_jtag_dmstatus_smoke();
    if (otp_image_loaded) begin
      if (dma_copy_check) begin
        wait_for_dma_copy_activity();
      end else if (dma_irq_check) begin
        wait_for_dma_irq_activity();
      end else if (gpio_irq_check) begin
        wait_for_gpio_irq_activity();
      end else if (uart_irq_check) begin
        wait_for_uart_irq_activity();
      end else if (timer_irq_check) begin
        wait_for_timer_irq_activity();
      end else if (otp_program_check) begin
        wait_for_otp_program_activity();
      end else begin
        wait_for_uart_tx_activity();
      end
    end

    repeat (20) @(posedge hclk);
    #1ns;
    if (wdg_reset_req !== 1'b0 || i2c_scl_oe !== 1'b0 || i2c_sda_oe !== 1'b0) begin
      $error("idle peripherals changed unexpectedly after smoke window");
      $fatal(1);
    end
    pass_count++;

    $display("tb_wasp1 PASS pass_count=%0d trap_valid=%0b trap_cause=0x%02h bus_grant_idx=%0b dbg_running=%0b dbg_halted=%0b dbg_dmactive=%0b",
             pass_count, trap_valid, trap_cause, bus_grant_idx, dbg_running, dbg_halted,
             dbg_dmactive);
    $finish;
  end
endmodule
