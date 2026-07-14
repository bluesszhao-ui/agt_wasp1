`timescale 1ns/1ps

// End-to-end software smoke for the I-SRAM UART OTP loader.
//
// A two-instruction OTP trampoline transfers control to a real RV32I loader
// image preloaded into I-SRAM. Requests enter through the serial RX pin. The
// bench observes bytes accepted by the UART TX FIFO, while uart_tx module-level
// tests separately cover bit serialization.
module tb_wasp1_uart_otp_loader;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int GPIO_WIDTH = 32;
  localparam int UART_BAUD_CYCLES = 4;
  localparam int MAX_PAYLOAD = 256;
  localparam int HEADER_SIZE = 16;
  localparam int CRC_SIZE = 4;
  localparam int MAX_FRAME = HEADER_SIZE + MAX_PAYLOAD + CRC_SIZE;
  localparam int PROGRAM_OFFSET = 32'h0000_3f80;
  localparam int PROGRAM_WORD_INDEX = PROGRAM_OFFSET >> 2;

  localparam logic [7:0] CMD_HELLO = 8'h01;
  localparam logic [7:0] CMD_READ = 8'h10;
  localparam logic [7:0] CMD_PROGRAM = 8'h11;
  localparam logic [7:0] CMD_STATUS = 8'h20;
  localparam logic [7:0] CMD_LOCK = 8'h21;
  localparam logic [7:0] STATUS_OK = 8'h00;
  localparam logic [7:0] STATUS_CRC_ERROR = 8'h06;
  localparam logic [7:0] STATUS_LOCKED = 8'h07;
  localparam logic [7:0] STATUS_ILLEGAL_TRANSITION = 8'h08;

  logic hclk;                         // 100 MHz SoC and loader clock.
  logic hresetn;                      // Active-low SoC reset.
  logic uart_rx;                      // Bit-serial host-to-target requests.
  logic uart_tx;                      // Target serial output, checked by UART unit DV.
  logic i2c_scl_in;                   // Inactive pulled-up I2C input.
  logic i2c_sda_in;                   // Inactive pulled-up I2C input.
  logic i2c_scl_out;                  // Unused I2C output observation.
  logic i2c_scl_oe;                   // Unused I2C output-enable observation.
  logic i2c_sda_out;                  // Unused I2C output observation.
  logic i2c_sda_oe;                   // Unused I2C output-enable observation.
  logic [GPIO_WIDTH-1:0] gpio_in;     // Inactive GPIO input value.
  logic [GPIO_WIDTH-1:0] gpio_out;    // Unused GPIO output observation.
  logic [GPIO_WIDTH-1:0] gpio_oe;     // Unused GPIO direction observation.
  logic wdg_reset_req;                // Watchdog reset request observation.
  logic trap_valid;                   // Trap observation used in timeout diagnostics.
  logic [4:0] trap_cause;             // Trap cause observation.
  logic bus_grant_idx;                // AHB master grant observation.
  logic jtag_tdo;                     // Inactive JTAG output observation.
  logic dbg_halted;                   // Debug state observation.
  logic dbg_running;                  // Debug state observation.
  logic dbg_dmactive;                 // Debug Module state observation.
  logic dbg_ndmreset;                 // Debug reset observation.
  logic dbg_dtm_hardreset;            // DTM reset observation.

  logic [7:0] request [0:MAX_FRAME-1];  // Request frame assembled by the host model.
  logic [7:0] response [0:MAX_FRAME-1]; // Response bytes accepted into the TX FIFO.
  int unsigned pass_count;             // Number of completed protocol checks.

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
    .jtag_tck_i(1'b0),
    .jtag_trst_ni(1'b0),
    .jtag_tms_i(1'b1),
    .jtag_tdi_i(1'b0),
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

  task automatic request_store_u16(input int offset, input logic [15:0] value);
    begin
      request[offset] = value[7:0];
      request[offset + 1] = value[15:8];
    end
  endtask

  task automatic request_store_u32(input int offset, input logic [31:0] value);
    begin
      request[offset] = value[7:0];
      request[offset + 1] = value[15:8];
      request[offset + 2] = value[23:16];
      request[offset + 3] = value[31:24];
    end
  endtask

  function automatic logic [15:0] response_load_u16(input int offset);
    response_load_u16 = {response[offset + 1], response[offset]};
  endfunction

  function automatic logic [31:0] response_load_u32(input int offset);
    response_load_u32 = {
      response[offset + 3], response[offset + 2],
      response[offset + 1], response[offset]
    };
  endfunction

  function automatic logic [31:0] request_crc32(input int length);
    logic [31:0] crc;
    logic [31:0] mask;
    begin
      crc = 32'hffff_ffff;
      for (int byte_idx = 0; byte_idx < length; byte_idx++) begin
        crc ^= {24'b0, request[byte_idx]};
        for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
          mask = 32'(0) - {31'b0, crc[0]};
          crc = (crc >> 1) ^ (32'hedb8_8320 & mask);
        end
      end
      request_crc32 = crc ^ 32'hffff_ffff;
    end
  endfunction

  function automatic logic [31:0] response_crc32(input int length);
    logic [31:0] crc;
    logic [31:0] mask;
    begin
      crc = 32'hffff_ffff;
      for (int byte_idx = 0; byte_idx < length; byte_idx++) begin
        crc ^= {24'b0, response[byte_idx]};
        for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
          mask = 32'(0) - {31'b0, crc[0]};
          crc = (crc >> 1) ^ (32'hedb8_8320 & mask);
        end
      end
      response_crc32 = crc ^ 32'hffff_ffff;
    end
  endfunction

  task automatic build_request(
    input logic [15:0] seq_id,
    input logic [7:0] command,
    input logic [31:0] address,
    input int payload_length,
    output int frame_length
  );
    logic [31:0] crc;
    begin
      request[0] = 8'h57;
      request[1] = 8'h31;
      request[2] = 8'h01;
      request[3] = 8'h00;
      request_store_u16(4, seq_id);
      request[6] = command;
      request[7] = STATUS_OK;
      request_store_u32(8, address);
      request_store_u16(12, 16'(payload_length));
      request_store_u16(14, 0);
      crc = request_crc32(HEADER_SIZE + payload_length);
      request_store_u32(HEADER_SIZE + payload_length, crc);
      frame_length = HEADER_SIZE + payload_length + CRC_SIZE;
    end
  endtask

  task automatic wait_actual_baud_tick;
    begin
      do begin
        @(posedge hclk);
        #1ps;
      end while (!u_wasp1.u_ahb_uart.baud_tick);
      // baud_tick is itself registered. uart_rx consumes the high value on the
      // following hclk edge, so defer the input transition until that edge.
      @(posedge hclk);
      #1ns;
    end
  endtask

  task automatic send_uart_byte(input logic [7:0] value);
    begin
      // Change symbols just after the registered baud tick. This removes
      // scheduler ambiguity at a tick edge while preserving exact bit periods.
      wait_actual_baud_tick();
      uart_rx = 1'b0;
      wait_actual_baud_tick();
      for (int bit_idx = 0; bit_idx < 8; bit_idx++) begin
        uart_rx = value[bit_idx];
        wait_actual_baud_tick();
      end
      uart_rx = 1'b1;
      wait_actual_baud_tick();
    end
  endtask

  task automatic exchange_frame(
    input int request_length,
    input int expected_response_length
  );
    int response_count;
    int timeout;
    begin
      response_count = 0;
      timeout = 0;
      fork
        begin
          for (int byte_idx = 0; byte_idx < request_length; byte_idx++) begin
            send_uart_byte(request[byte_idx]);
          end
        end
        begin
          while (response_count < expected_response_length && timeout < 5000000) begin
            @(posedge hclk);
            // tx_fifo_push is derived from the registered AHB data phase and
            // may deassert after this edge, so sample it before NBA updates.
            if (u_wasp1.u_ahb_uart.tx_fifo_push) begin
              response[response_count] = u_wasp1.u_ahb_uart.tx_fifo_wdata;
              response_count++;
            end
            timeout++;
          end
        end
      join
      if (response_count != expected_response_length) begin
        $error("UART OTP response timeout: got %0d expected %0d pc=0x%08h trap=%0b/%0d",
               response_count, expected_response_length,
               u_wasp1.ex_pc, trap_valid, trap_cause);
        $fatal(1);
      end
    end
  endtask

  task automatic check_response(
    input logic [15:0] seq_id,
    input logic [7:0] command,
    input logic [7:0] status,
    input int payload_length
  );
    logic [31:0] observed_crc;
    logic [31:0] expected_crc;
    begin
      if (response[0] !== 8'h57 || response[1] !== 8'h31 ||
          response[2] !== 8'h01 || response[3] !== 8'h01 ||
          response_load_u16(4) !== seq_id || response[6] !== command ||
          response[7] !== status ||
          response_load_u16(12) !== 16'(payload_length)) begin
        $error("bad UART OTP response header: seq=0x%04h cmd=0x%02h status=0x%02h length=%0d",
               response_load_u16(4), response[6], response[7],
               response_load_u16(12));
        $fatal(1);
      end
      observed_crc = response_load_u32(HEADER_SIZE + payload_length);
      expected_crc = response_crc32(HEADER_SIZE + payload_length);
      if (observed_crc !== expected_crc) begin
        $error("UART OTP response CRC mismatch: got=0x%08h expected=0x%08h",
               observed_crc, expected_crc);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  initial begin
    int frame_length;
    int timeout;

    hresetn = 1'b0;
    uart_rx = 1'b1;
    i2c_scl_in = 1'b1;
    i2c_sda_in = 1'b1;
    gpio_in = '0;
    pass_count = 0;

    // The trampoline models reset code already present in OTP; the loader ELF
    // models OpenOCD/JTAG injection into I-SRAM on a blank manufacturing part.
    #1ps;
    $readmemh("dv/uart_otp_loader_trampoline.hex",
              u_wasp1.u_ahb_otp.u_otp_macro.otp_mem_q);
    $readmemh("../llvm_s1/build/uart_otp_loader_sim/wasp1_uart_otp_loader_isram.hex",
              u_wasp1.u_ahb_isram.u_sram_macro.mem_q);
    repeat (8) @(posedge hclk);
    hresetn = 1'b1;

    timeout = 0;
    while ((!u_wasp1.u_ahb_uart.enable_q ||
            u_wasp1.u_ahb_uart.baud_div_q != 16'(UART_BAUD_CYCLES)) &&
           timeout < 200000) begin
      @(posedge hclk);
      timeout++;
    end
    if (timeout == 200000) begin
      $error("I-SRAM loader did not initialize UART: pc=0x%08h instr=0x%08h trap=%0b/%0d",
             u_wasp1.ex_pc, u_wasp1.ex_instr, trap_valid, trap_cause);
      $fatal(1);
    end

    build_request(16'h0001, CMD_HELLO, 0, 0, frame_length);
    exchange_frame(frame_length, 32);
    check_response(16'h0001, CMD_HELLO, STATUS_OK, 12);
    if (response_load_u32(16) !== OTP_DATA_SIZE ||
        response_load_u32(20) !== 32'h0000_0007 ||
        response_load_u16(24) !== 16'(MAX_PAYLOAD)) begin
      $error("HELLO payload mismatch: size=0x%08h caps=0x%08h max=%0d",
             response_load_u32(16), response_load_u32(20),
             response_load_u16(24));
      $fatal(1);
    end
    pass_count++;

    request[16] = 8'h78;
    request[17] = 8'h56;
    request[18] = 8'h34;
    request[19] = 8'h12;
    build_request(16'h0002, CMD_PROGRAM, PROGRAM_OFFSET, 4, frame_length);
    exchange_frame(frame_length, 20);
    check_response(16'h0002, CMD_PROGRAM, STATUS_OK, 0);
    if (u_wasp1.u_ahb_otp.u_otp_macro.otp_mem_q[PROGRAM_WORD_INDEX] !==
        32'h1234_5678) begin
      $error("OTP program data mismatch: got=0x%08h",
             u_wasp1.u_ahb_otp.u_otp_macro.otp_mem_q[PROGRAM_WORD_INDEX]);
      $fatal(1);
    end
    pass_count++;

    request[16] = 8'h04;
    request[17] = 8'h00;
    build_request(16'h0003, CMD_READ, PROGRAM_OFFSET, 2, frame_length);
    exchange_frame(frame_length, 24);
    check_response(16'h0003, CMD_READ, STATUS_OK, 4);
    if (response_load_u32(16) !== 32'h1234_5678) begin
      $error("OTP readback payload mismatch: got=0x%08h", response_load_u32(16));
      $fatal(1);
    end
    pass_count++;

    request[16] = 8'hff;
    request[17] = 8'hff;
    request[18] = 8'hff;
    request[19] = 8'hff;
    build_request(16'h0004, CMD_PROGRAM, PROGRAM_OFFSET, 4, frame_length);
    exchange_frame(frame_length, 20);
    check_response(16'h0004, CMD_PROGRAM, STATUS_ILLEGAL_TRANSITION, 0);
    if (u_wasp1.u_ahb_otp.u_otp_macro.otp_mem_q[PROGRAM_WORD_INDEX] !==
        32'h1234_5678) begin
      $error("illegal OTP request changed storage");
      $fatal(1);
    end
    pass_count++;

    request[16] = 8'h00;
    request[17] = 8'h00;
    request[18] = 8'h00;
    request[19] = 8'h00;
    build_request(16'h0005, CMD_PROGRAM, PROGRAM_OFFSET + 4, 4, frame_length);
    request[frame_length - 1] ^= 8'h01;
    exchange_frame(frame_length, 20);
    check_response(16'h0005, CMD_PROGRAM, STATUS_CRC_ERROR, 0);
    if (u_wasp1.u_ahb_otp.u_otp_macro.otp_mem_q[PROGRAM_WORD_INDEX + 1] !==
        32'hffff_ffff) begin
      $error("CRC-corrupt OTP request changed storage");
      $fatal(1);
    end
    pass_count++;

    build_request(16'h0006, CMD_LOCK, 0, 0, frame_length);
    exchange_frame(frame_length, 20);
    check_response(16'h0006, CMD_LOCK, STATUS_OK, 0);

    build_request(16'h0007, CMD_STATUS, 0, 0, frame_length);
    exchange_frame(frame_length, 24);
    check_response(16'h0007, CMD_STATUS, STATUS_OK, 4);
    if ((response_load_u32(16) & 32'h0000_0008) == 0) begin
      $error("OTP lock bit was not reported after LOCK");
      $fatal(1);
    end
    pass_count++;

    request[16] = 8'h00;
    request[17] = 8'h00;
    request[18] = 8'h00;
    request[19] = 8'h00;
    build_request(16'h0008, CMD_PROGRAM, PROGRAM_OFFSET + 4, 4, frame_length);
    exchange_frame(frame_length, 20);
    check_response(16'h0008, CMD_PROGRAM, STATUS_LOCKED, 0);
    if (u_wasp1.u_ahb_otp.u_otp_macro.otp_mem_q[PROGRAM_WORD_INDEX + 1] !==
        32'hffff_ffff) begin
      $error("locked OTP request changed storage");
      $fatal(1);
    end
    pass_count++;

    if (pass_count != 15) begin
      $error("UART OTP loader pass count mismatch: got=%0d expected=15", pass_count);
      $fatal(1);
    end
    $display("RESULT PASS tb_wasp1_uart_otp_loader checks=%0d", pass_count);
    $finish;
  end

endmodule
