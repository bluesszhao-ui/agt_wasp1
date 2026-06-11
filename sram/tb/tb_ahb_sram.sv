`timescale 1ns/1ps

module tb_ahb_sram;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = 32'h1000_0000;
  localparam int MEM_BYTES = 1024;

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
  int unsigned word_count;
  int unsigned half_count;
  int unsigned byte_count;
  int unsigned error_count;
  int unsigned idle_count;
  int unsigned random_count;

  ahb_sram #(
    .BASE_ADDR(BASE_ADDR),
    .MEM_BYTES(MEM_BYTES)
  ) u_ahb_sram (
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
      hsel = 1'b0;
      haddr = '0;
      htrans = AHB_HTRANS_IDLE;
      hwrite = 1'b0;
      hsize = AHB_HSIZE_WORD;
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
      unique case (size)
        AHB_HSIZE_BYTE: byte_count++;
        AHB_HSIZE_HALF: half_count++;
        AHB_HSIZE_WORD: word_count++;
        default: begin end
      endcase
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

  task automatic check_unselected_no_write;
    begin
      @(negedge hclk);
      hsel = 1'b0;
      haddr = BASE_ADDR + 32'h20;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b1;
      hsize = AHB_HSIZE_WORD;
      hwdata = 32'hFFFF_FFFF;
      @(posedge hclk);
      @(negedge hclk);
      drive_idle();
      @(posedge hclk);
      #1ns;
      if (hresp !== AHB_HRESP_OKAY) begin
        $error("unselected: unexpected error");
        $fatal(1);
      end
      idle_count++;
      pass_count++;
    end
  endtask

  task automatic check_random_word_accesses(input int unsigned count);
    logic [31:0] addr;
    logic [31:0] data;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        addr = BASE_ADDR + 32'(($urandom_range(0, (MEM_BYTES / 4) - 1)) * 4);
        data = $urandom();
        ahb_write(addr, AHB_HSIZE_WORD, data, AHB_HRESP_OKAY, "random word write");
        ahb_read(addr, AHB_HSIZE_WORD, data, AHB_HRESP_OKAY, "random word read");
        random_count++;
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (word_count < 8 || half_count < 2 || byte_count < 4) begin
        $error("coverage miss: size counts word=%0d half=%0d byte=%0d",
               word_count, half_count, byte_count);
        $fatal(1);
      end
      if (error_count < 4 || idle_count == 0 || random_count < 16) begin
        $error("coverage miss: error=%0d idle=%0d random=%0d",
               error_count, idle_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_sram coverage: pass_count=%0d word_count=%0d half_count=%0d byte_count=%0d error_count=%0d idle_count=%0d random_count=%0d",
               pass_count, word_count, half_count, byte_count, error_count,
               idle_count, random_count);
    end
  endtask

  initial begin
    void'($urandom(32'h5750_1000));
    pass_count = 0;
    word_count = 0;
    half_count = 0;
    byte_count = 0;
    error_count = 0;
    idle_count = 0;
    random_count = 0;

    apply_reset();

    ahb_write(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'h1122_3344, AHB_HRESP_OKAY, "word write");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'h1122_3344, AHB_HRESP_OKAY, "word read");

    ahb_write(BASE_ADDR + 32'h02, AHB_HSIZE_HALF, 32'hAABB_CCDD, AHB_HRESP_OKAY, "upper half write");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'hAABB_3344, AHB_HRESP_OKAY, "upper half readback");

    ahb_write(BASE_ADDR + 32'h01, AHB_HSIZE_BYTE, 32'h0000_EE00, AHB_HRESP_OKAY, "byte lane1 write");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'hAABB_EE44, AHB_HRESP_OKAY, "byte lane1 readback");

    ahb_write(BASE_ADDR + 32'h00, AHB_HSIZE_BYTE, 32'h0000_0099, AHB_HRESP_OKAY, "byte lane0 write");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'hAABB_EE99, AHB_HRESP_OKAY, "byte lane0 readback");

    ahb_write(BASE_ADDR + 32'h02, AHB_HSIZE_BYTE, 32'h0077_0000, AHB_HRESP_OKAY, "byte lane2 write");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'hAA77_EE99, AHB_HRESP_OKAY, "byte lane2 readback");

    ahb_write(BASE_ADDR + 32'h03, AHB_HSIZE_BYTE, 32'h6600_0000, AHB_HRESP_OKAY, "byte lane3 write");
    ahb_read(BASE_ADDR + 32'h00, AHB_HSIZE_WORD, 32'h6677_EE99, AHB_HRESP_OKAY, "byte lane3 readback");

    ahb_write(BASE_ADDR + 32'h20, AHB_HSIZE_WORD, 32'h5566_7788, AHB_HRESP_OKAY, "second word write");
    check_unselected_no_write();
    ahb_read(BASE_ADDR + 32'h20, AHB_HSIZE_WORD, 32'h5566_7788, AHB_HRESP_OKAY, "unselected no write readback");

    ahb_write(BASE_ADDR + 32'h03, AHB_HSIZE_HALF, 32'h0000_1234, AHB_HRESP_ERROR, "misaligned half write");
    ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0, AHB_HRESP_ERROR, "misaligned word read");
    ahb_write(BASE_ADDR + MEM_BYTES, AHB_HSIZE_WORD, 32'hDEAD_BEEF, AHB_HRESP_ERROR, "out of range write");
    ahb_read(BASE_ADDR - 4, AHB_HSIZE_WORD, '0, AHB_HRESP_ERROR, "below base read");

    check_random_word_accesses(16);
    check_coverage_summary();

    $display("tb_ahb_sram PASS");
    $finish;
  end
endmodule
