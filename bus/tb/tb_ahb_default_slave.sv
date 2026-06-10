`timescale 1ns/1ps

module tb_ahb_default_slave;
  import wasp1_pkg::*;

  logic                  hsel;
  logic [1:0]            htrans;
  logic                  hwrite;
  logic [2:0]            hsize;
  logic [DATA_WIDTH-1:0] hwdata;
  logic [DATA_WIDTH-1:0] hrdata;
  logic                  hready;
  logic                  hresp;

  int unsigned pass_count;
  int unsigned error_count;
  int unsigned okay_count;
  int unsigned read_count;
  int unsigned write_count;
  int unsigned size_hit_count [3];

  ahb_default_slave u_ahb_default_slave (
    .hsel_i(hsel),
    .htrans_i(htrans),
    .hwrite_i(hwrite),
    .hsize_i(hsize),
    .hwdata_i(hwdata),
    .hrdata_o(hrdata),
    .hready_o(hready),
    .hresp_o(hresp)
  );

  task automatic check_response(
    input logic       sel,
    input logic [1:0] trans,
    input logic       write,
    input logic [2:0] size,
    input logic [31:0] wdata,
    input logic       expected_resp,
    input string      label
  );
    begin
      hsel = sel;
      htrans = trans;
      hwrite = write;
      hsize = size;
      hwdata = wdata;
      #1;

      if (hready !== 1'b1) begin
        $error("%s: expected hready=1 got %0b", label, hready);
        $fatal(1);
      end

      if (hrdata !== '0) begin
        $error("%s: expected zero hrdata got 0x%08h", label, hrdata);
        $fatal(1);
      end

      if (hresp !== expected_resp) begin
        $error("%s: expected hresp=%0b got %0b", label, expected_resp, hresp);
        $fatal(1);
      end

      if (expected_resp == AHB_HRESP_ERROR) begin
        error_count++;
      end else begin
        okay_count++;
      end

      if (write) begin
        write_count++;
      end else begin
        read_count++;
      end

      unique case (size)
        AHB_HSIZE_BYTE: size_hit_count[0]++;
        AHB_HSIZE_HALF: size_hit_count[1]++;
        AHB_HSIZE_WORD: size_hit_count[2]++;
        default: begin end
      endcase

      pass_count++;
    end
  endtask

  task automatic check_random_cases(input int unsigned count);
    logic       rand_sel;
    logic [1:0] rand_trans;
    logic       rand_write;
    logic [2:0] rand_size;
    logic [31:0] rand_wdata;
    logic       expected;
    begin
      for (int unsigned idx = 0; idx < count; idx++) begin
        rand_sel = 1'($urandom_range(0, 1));
        rand_trans = 2'($urandom_range(0, 3));
        rand_write = 1'($urandom_range(0, 1));
        rand_size = 3'($urandom_range(0, 2));
        rand_wdata = $urandom();
        expected = (rand_sel && rand_trans[1]) ? AHB_HRESP_ERROR : AHB_HRESP_OKAY;
        check_response(rand_sel, rand_trans, rand_write, rand_size, rand_wdata,
                       expected, "deterministic random");
      end
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (error_count < 8) begin
        $error("coverage miss: error_count too low: %0d", error_count);
        $fatal(1);
      end
      if (okay_count < 8) begin
        $error("coverage miss: okay_count too low: %0d", okay_count);
        $fatal(1);
      end
      if (read_count == 0 || write_count == 0) begin
        $error("coverage miss: read/write not both covered r=%0d w=%0d",
               read_count, write_count);
        $fatal(1);
      end
      foreach (size_hit_count[idx]) begin
        if (size_hit_count[idx] == 0) begin
          $error("coverage miss: hsize index %0d not covered", idx);
          $fatal(1);
        end
      end
      $display("tb_ahb_default_slave coverage: pass_count=%0d error_count=%0d okay_count=%0d read_count=%0d write_count=%0d",
               pass_count, error_count, okay_count, read_count, write_count);
      foreach (size_hit_count[idx]) begin
        $display("tb_ahb_default_slave coverage: size[%0d] hits=%0d",
                 idx, size_hit_count[idx]);
      end
    end
  endtask

  initial begin
    void'($urandom(32'h5750_0002));
    pass_count = 0;
    error_count = 0;
    okay_count = 0;
    read_count = 0;
    write_count = 0;
    foreach (size_hit_count[idx]) begin
      size_hit_count[idx] = 0;
    end

    hsel = 1'b0;
    htrans = AHB_HTRANS_IDLE;
    hwrite = 1'b0;
    hsize = AHB_HSIZE_WORD;
    hwdata = '0;

    check_response(1'b0, AHB_HTRANS_IDLE,   1'b0, AHB_HSIZE_BYTE, 32'h0000_0000, AHB_HRESP_OKAY,  "unselected idle read");
    check_response(1'b0, AHB_HTRANS_NONSEQ, 1'b1, AHB_HSIZE_WORD, 32'hCAFE_BABE, AHB_HRESP_OKAY,  "unselected nonseq write");
    check_response(1'b1, AHB_HTRANS_IDLE,   1'b0, AHB_HSIZE_HALF, 32'h0000_0000, AHB_HRESP_OKAY,  "selected idle read");
    check_response(1'b1, AHB_HTRANS_BUSY,   1'b1, AHB_HSIZE_BYTE, 32'h1234_5678, AHB_HRESP_OKAY,  "selected busy write");
    check_response(1'b1, AHB_HTRANS_NONSEQ, 1'b0, AHB_HSIZE_BYTE, 32'h0000_0000, AHB_HRESP_ERROR, "selected nonseq byte read");
    check_response(1'b1, AHB_HTRANS_NONSEQ, 1'b1, AHB_HSIZE_HALF, 32'hABCD_1234, AHB_HRESP_ERROR, "selected nonseq half write");
    check_response(1'b1, AHB_HTRANS_SEQ,    1'b0, AHB_HSIZE_WORD, 32'h0000_0000, AHB_HRESP_ERROR, "selected seq word read");
    check_response(1'b1, AHB_HTRANS_SEQ,    1'b1, AHB_HSIZE_WORD, 32'hFFFF_0000, AHB_HRESP_ERROR, "selected seq word write");

    check_random_cases(128);
    check_coverage_summary();

    $display("tb_ahb_default_slave PASS");
    $finish;
  end
endmodule
