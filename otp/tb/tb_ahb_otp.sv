`timescale 1ns/1ps

module tb_ahb_otp;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = OTP_BASE;
  localparam int MEM_BYTES = 1024;
  localparam int REG_WINDOW_BYTES = 256;
  localparam int DATA_BYTES = MEM_BYTES - REG_WINDOW_BYTES;
  localparam int DATA_WORDS = DATA_BYTES / 4;
  localparam logic [31:0] REG_BASE = BASE_ADDR + DATA_BYTES;

  logic                  hclk;
  logic                  hresetn;
  logic                  hsel;
  logic [ADDR_WIDTH-1:0] haddr;
  logic [1:0]            htrans;
  logic                  hwrite;
  logic [2:0]            hsize;
  logic [DATA_WIDTH-1:0] hwdata;
  logic [DATA_WIDTH-1:0] hrdata;
  logic                  hready;
  logic                  hresp;

  int unsigned pass_count;
  int unsigned data_read_count;
  int unsigned reg_count;
  int unsigned program_count;
  int unsigned error_count;
  int unsigned lock_count;
  int unsigned random_count;

  ahb_otp #(
    .BASE_ADDR(BASE_ADDR),
    .MEM_BYTES(MEM_BYTES),
    .REG_WINDOW_BYTES(REG_WINDOW_BYTES)
  ) u_ahb_otp (
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
    .hresp_o(hresp)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

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

  task automatic apply_reset;
    begin
      hresetn = 1'b0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1 || hresp !== AHB_HRESP_OKAY || hrdata !== '0) begin
        $error("reset: unexpected output hready=%0b hresp=%0b hrdata=0x%08h",
               hready, hresp, hrdata);
        $fatal(1);
      end
      pass_count++;
    end
  endtask

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
        $error("%s: address phase expected hready=1", label);
        $fatal(1);
      end

      @(negedge hclk);
      drive_idle();
      hwdata = data;

      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: write response mismatch expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end
      pass_count++;
    end
  endtask

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
        $error("%s: read response mismatch expected=%0b got=%0b hready=%0b",
               label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (expected_resp == AHB_HRESP_OKAY && hrdata !== expected_data) begin
        $error("%s: read data mismatch expected=0x%08h got=0x%08h",
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
    input logic expected_resp,
    input string label
  );
    begin
      ahb_write(REG_BASE + offset, AHB_HSIZE_WORD, data, expected_resp, label);
      reg_count++;
    end
  endtask

  task automatic read_reg(
    input logic [31:0] offset,
    input logic [31:0] expected,
    input string label
  );
    begin
      ahb_read(REG_BASE + offset, AHB_HSIZE_WORD, expected, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic start_program(
    input logic [31:0] word_addr,
    input logic [31:0] data,
    input logic [31:0] expected_status,
    input string label
  );
    begin
      write_reg(OTP_ADDR_OFFSET, word_addr, AHB_HRESP_OKAY, {label, " addr"});
      write_reg(OTP_WDATA_OFFSET, data, AHB_HRESP_OKAY, {label, " wdata"});
      write_reg(OTP_CTRL_OFFSET,
                (32'h1 << OTP_CTRL_PROG_EN_BIT) | (32'h1 << OTP_CTRL_START_BIT),
                AHB_HRESP_OKAY, {label, " start"});
      read_reg(OTP_STATUS_OFFSET, expected_status, {label, " status"});
      if (expected_status[OTP_STATUS_DONE_BIT]) begin
        program_count++;
      end
      if (expected_status[OTP_STATUS_ERROR_BIT]) begin
        error_count++;
      end
    end
  endtask

  task automatic clear_status;
    begin
      write_reg(OTP_CTRL_OFFSET, 32'h1 << OTP_CTRL_CLEAR_BIT, AHB_HRESP_OKAY, "clear status");
      read_reg(OTP_STATUS_OFFSET, {28'h0, 1'b0, 1'b0, 1'b0, 1'b0}, "status clear readback");
    end
  endtask

  task automatic check_random_programs(input int unsigned count);
    logic [31:0] word_addr;
    logic [31:0] data;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        word_addr = 32'(16 + idx);
        data = $urandom();
        start_program(word_addr, data, 32'h0000_0002, "random program");
        ahb_read(BASE_ADDR + (word_addr * 4), AHB_HSIZE_WORD, data,
                 AHB_HRESP_OKAY, "random readback");
        random_count++;
        clear_status();
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (data_read_count < 3 || reg_count < 24 || program_count < 6) begin
        $error("coverage miss: data=%0d reg=%0d program=%0d",
               data_read_count, reg_count, program_count);
        $fatal(1);
      end
      if (error_count < 8 || lock_count < 1 || random_count < 4) begin
        $error("coverage miss: error=%0d lock=%0d random=%0d",
               error_count, lock_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_otp coverage: pass_count=%0d data_read_count=%0d reg_count=%0d program_count=%0d error_count=%0d lock_count=%0d random_count=%0d",
               pass_count, data_read_count, reg_count, program_count,
               error_count, lock_count, random_count);
    end
  endtask

  initial begin
    void'($urandom(32'h5750_0A0A));
    pass_count = 0;
    data_read_count = 0;
    reg_count = 0;
    program_count = 0;
    error_count = 0;
    lock_count = 0;
    random_count = 0;

    apply_reset();

    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'hFFFF_FFFF,
             AHB_HRESP_OKAY, "default word 0");
    data_read_count++;
    ahb_read(BASE_ADDR + 32'h04, AHB_HSIZE_WORD, 32'hFFFF_FFFF,
             AHB_HRESP_OKAY, "default word 1");
    data_read_count++;
    read_reg(OTP_STATUS_OFFSET, 32'h0000_0000, "initial status");

    ahb_write(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'h0000_0000,
              AHB_HRESP_ERROR, "direct data write");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'hFFFF_FFFF,
             AHB_HRESP_OKAY, "direct write no modify");
    data_read_count++;

    write_reg(OTP_KEY_OFFSET, OTP_KEY_VALUE, AHB_HRESP_OKAY, "unlock key");
    read_reg(OTP_KEY_OFFSET, 32'h0000_0001, "key readback");
    start_program(32'h0000_0000, 32'hF0F0_F0F0, 32'h0000_0002, "first program");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'hF0F0_F0F0,
             AHB_HRESP_OKAY, "first program readback");
    data_read_count++;
    clear_status();

    start_program(32'h0000_0000, 32'h00F0_00F0, 32'h0000_0002, "second legal program");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'h00F0_00F0,
             AHB_HRESP_OKAY, "second program readback");
    data_read_count++;
    clear_status();

    start_program(32'h0000_0000, 32'hFFFF_FFFF, 32'h0000_0004, "illegal raise bits");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'h00F0_00F0,
             AHB_HRESP_OKAY, "illegal raise no modify");
    data_read_count++;
    clear_status();

    write_reg(OTP_KEY_OFFSET, 32'h0000_0000, AHB_HRESP_OKAY, "bad key clears unlock");
    start_program(32'h0000_0001, 32'hAAAA_AAAA, 32'h0000_0004, "program without key");
    clear_status();
    write_reg(OTP_KEY_OFFSET, OTP_KEY_VALUE, AHB_HRESP_OKAY, "unlock key again");
    start_program(32'(DATA_WORDS), 32'h1234_5678, 32'h0000_0004, "program out of range");
    clear_status();

    ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0, AHB_HRESP_ERROR, "misaligned data read");
    ahb_write(REG_BASE + OTP_ADDR_OFFSET + 32'h02, AHB_HSIZE_HALF, 32'h0000_0001,
              AHB_HRESP_ERROR, "misaligned register write");
    ahb_write(REG_BASE + 32'h80, AHB_HSIZE_WORD, 32'h0000_0001,
              AHB_HRESP_ERROR, "unknown register write");
    ahb_read(REG_BASE + 32'h80, AHB_HSIZE_WORD, '0,
             AHB_HRESP_ERROR, "unknown register read");
    ahb_read(BASE_ADDR + MEM_BYTES, AHB_HSIZE_WORD, '0,
             AHB_HRESP_ERROR, "out of range read");

    check_random_programs(4);

    write_reg(OTP_LOCK_OFFSET, 32'h0000_0001, AHB_HRESP_OKAY, "lock otp");
    lock_count++;
    read_reg(OTP_LOCK_OFFSET, 32'h0000_0001, "lock readback");
    read_reg(OTP_STATUS_OFFSET, 32'h0000_0008, "locked status");
    write_reg(OTP_KEY_OFFSET, OTP_KEY_VALUE, AHB_HRESP_OKAY, "key after lock");
    start_program(32'h0000_0008, 32'h5555_5555, 32'h0000_000C, "program after lock");

    check_coverage_summary();
    $display("tb_ahb_otp PASS");
    $finish;
  end
endmodule
