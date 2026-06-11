`timescale 1ns/1ps

module tb_ahb_dma;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = DMA_BASE;
  localparam int REGION_BYTES = PERIPH_SIZE;
  localparam int MEM_WORDS = 256;
  localparam logic [31:0] MEM_BASE = 32'h2000_0000;

  logic hclk;
  logic hresetn;
  logic s_hsel;
  logic [ADDR_WIDTH-1:0] s_haddr;
  logic [1:0] s_htrans;
  logic s_hwrite;
  logic [2:0] s_hsize;
  logic [DATA_WIDTH-1:0] s_hwdata;
  logic [DATA_WIDTH-1:0] s_hrdata;
  logic s_hready;
  logic s_hresp;

  logic [ADDR_WIDTH-1:0] m_haddr;
  logic [1:0] m_htrans;
  logic m_hwrite;
  logic [2:0] m_hsize;
  logic [2:0] m_hburst;
  logic [3:0] m_hprot;
  logic m_hmastlock;
  logic [DATA_WIDTH-1:0] m_hwdata;
  logic [DATA_WIDTH-1:0] m_hrdata;
  logic m_hready;
  logic m_hresp;
  logic dma_irq;

  logic [31:0] mem_q [MEM_WORDS];
  logic inject_read_error;
  logic inject_write_error;
  logic [31:0] read_count;
  logic [31:0] write_count;

  int unsigned pass_count;
  int unsigned reg_count;
  int unsigned copy_count;
  int unsigned irq_count;
  int unsigned error_count;
  int unsigned random_count;

  ahb_dma #(
    .BASE_ADDR(BASE_ADDR),
    .REGION_BYTES(REGION_BYTES)
  ) u_ahb_dma (
    .hclk_i(hclk),
    .hresetn_i(hresetn),
    .s_hsel_i(s_hsel),
    .s_haddr_i(s_haddr),
    .s_htrans_i(s_htrans),
    .s_hwrite_i(s_hwrite),
    .s_hsize_i(s_hsize),
    .s_hwdata_i(s_hwdata),
    .s_hrdata_o(s_hrdata),
    .s_hready_o(s_hready),
    .s_hresp_o(s_hresp),
    .m_haddr_o(m_haddr),
    .m_htrans_o(m_htrans),
    .m_hwrite_o(m_hwrite),
    .m_hsize_o(m_hsize),
    .m_hburst_o(m_hburst),
    .m_hprot_o(m_hprot),
    .m_hmastlock_o(m_hmastlock),
    .m_hwdata_o(m_hwdata),
    .m_hrdata_i(m_hrdata),
    .m_hready_i(m_hready),
    .m_hresp_i(m_hresp),
    .dma_irq_o(dma_irq)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

  function automatic int unsigned word_index(input logic [31:0] addr);
    word_index = (addr - MEM_BASE) >> 2;
  endfunction

  always_ff @(posedge hclk or negedge hresetn) begin
    if (!hresetn) begin
      m_hrdata <= '0;
      m_hready <= 1'b1;
      m_hresp <= AHB_HRESP_OKAY;
      read_count <= '0;
      write_count <= '0;
    end else begin
      m_hready <= 1'b1;
      m_hresp <= AHB_HRESP_OKAY;
      if (m_htrans[1]) begin
        if ((m_haddr < MEM_BASE) || (word_index(m_haddr) >= MEM_WORDS) || |m_haddr[1:0]) begin
          m_hresp <= AHB_HRESP_ERROR;
          m_hrdata <= '0;
        end else if (m_hwrite) begin
          if (inject_write_error) begin
            m_hresp <= AHB_HRESP_ERROR;
          end else begin
            mem_q[word_index(m_haddr)] <= m_hwdata;
            write_count <= write_count + 1'b1;
          end
        end else begin
          if (inject_read_error) begin
            m_hresp <= AHB_HRESP_ERROR;
            m_hrdata <= '0;
          end else begin
            m_hrdata <= mem_q[word_index(m_haddr)];
            read_count <= read_count + 1'b1;
          end
        end
      end
    end
  end

  task automatic drive_idle;
    begin
      s_hsel = 1'b0;
      s_haddr = '0;
      s_htrans = AHB_HTRANS_IDLE;
      s_hwrite = 1'b0;
      s_hsize = AHB_HSIZE_WORD;
      s_hwdata = '0;
    end
  endtask

  task automatic apply_reset;
    begin
      inject_read_error = 1'b0;
      inject_write_error = 1'b0;
      for (int idx = 0; idx < MEM_WORDS; idx++) begin
        mem_q[idx] = 32'hCAFE_0000 + 32'(idx);
      end
      hresetn = 1'b0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (s_hready !== 1'b1 || s_hresp !== AHB_HRESP_OKAY || dma_irq !== 1'b0 ||
          m_htrans !== AHB_HTRANS_IDLE) begin
        $error("reset outputs unexpected");
        $fatal(1);
      end
      pass_count++;
    end
  endtask

  task automatic ahb_write(
    input logic [31:0] addr,
    input logic [2:0] size,
    input logic [31:0] data,
    input logic expected_resp,
    input string label
  );
    begin
      @(negedge hclk);
      s_hsel = 1'b1;
      s_haddr = addr;
      s_htrans = AHB_HTRANS_NONSEQ;
      s_hwrite = 1'b1;
      s_hsize = size;
      s_hwdata = data;
      @(posedge hclk);
      @(negedge hclk);
      drive_idle();
      s_hwdata = data;
      @(posedge hclk);
      #1ns;
      if (s_hresp !== expected_resp) begin
        $error("%s: write resp expected=%0b got=%0b", label, expected_resp, s_hresp);
        $fatal(1);
      end
      if (expected_resp) error_count++;
      pass_count++;
    end
  endtask

  task automatic ahb_read(
    input logic [31:0] addr,
    input logic [2:0] size,
    input logic [31:0] expected,
    input logic [31:0] mask,
    input logic expected_resp,
    input string label
  );
    begin
      @(negedge hclk);
      s_hsel = 1'b1;
      s_haddr = addr;
      s_htrans = AHB_HTRANS_NONSEQ;
      s_hwrite = 1'b0;
      s_hsize = size;
      s_hwdata = '0;
      @(posedge hclk);
      @(negedge hclk);
      drive_idle();
      @(posedge hclk);
      #1ns;
      if (s_hresp !== expected_resp) begin
        $error("%s: read resp expected=%0b got=%0b", label, expected_resp, s_hresp);
        $fatal(1);
      end
      if (!expected_resp && ((s_hrdata & mask) !== (expected & mask))) begin
        $error("%s: read expected=0x%08h got=0x%08h mask=0x%08h", label, expected, s_hrdata, mask);
        $fatal(1);
      end
      if (expected_resp) error_count++;
      pass_count++;
    end
  endtask

  task automatic write_reg(input logic [31:0] offset, input logic [31:0] data, input string label);
    begin
      ahb_write(BASE_ADDR + offset, AHB_HSIZE_WORD, data, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic read_reg(input logic [31:0] offset, input logic [31:0] expected, input logic [31:0] mask, input string label);
    begin
      ahb_read(BASE_ADDR + offset, AHB_HSIZE_WORD, expected, mask, AHB_HRESP_OKAY, label);
      reg_count++;
    end
  endtask

  task automatic wait_done(input logic expect_error);
    logic [31:0] status;
    begin
      status = '0;
      for (int idx = 0; idx < 200; idx++) begin
        @(posedge hclk);
        #1ns;
        status = {29'h0, u_ahb_dma.error_q, u_ahb_dma.done_q, (u_ahb_dma.state_q != 3'd0)};
        if (status[DMA_STATUS_DONE_BIT] || status[DMA_STATUS_ERROR_BIT]) begin
          if (expect_error && !status[DMA_STATUS_ERROR_BIT]) begin
            $error("expected DMA error status got 0x%08h", status);
            $fatal(1);
          end
          if (!expect_error && !status[DMA_STATUS_DONE_BIT]) begin
            $error("expected DMA done status got 0x%08h", status);
            $fatal(1);
          end
          pass_count++;
          return;
        end
      end
      $error("DMA timeout");
      $fatal(1);
    end
  endtask

  task automatic program_and_start(input logic [31:0] src, input logic [31:0] dst, input logic [31:0] len, input logic irq_en);
    begin
      write_reg(DMA_SRC_OFFSET, src, "src write");
      write_reg(DMA_DST_OFFSET, dst, "dst write");
      write_reg(DMA_LEN_OFFSET, len, "len write");
      write_reg(DMA_CTRL_OFFSET,
                (32'h1 << DMA_CTRL_START_BIT) |
                (irq_en ? (32'h1 << DMA_CTRL_IRQ_EN_BIT) : 32'h0),
                "start write");
    end
  endtask

  task automatic check_copy(input int unsigned src_idx, input int unsigned dst_idx, input int unsigned words);
    begin
      for (int unsigned idx = 0; idx < words; idx++) begin
        mem_q[src_idx + idx] = $urandom();
        mem_q[dst_idx + idx] = 32'h0;
      end
      program_and_start(MEM_BASE + 32'(src_idx * 4), MEM_BASE + 32'(dst_idx * 4), 32'(words), 1'b1);
      wait_done(1'b0);
      for (int unsigned idx = 0; idx < words; idx++) begin
        if (mem_q[dst_idx + idx] !== mem_q[src_idx + idx]) begin
          $error("copy mismatch idx=%0d src=0x%08h dst=0x%08h", idx, mem_q[src_idx + idx], mem_q[dst_idx + idx]);
          $fatal(1);
        end
      end
      if (!dma_irq) begin
        $error("expected DMA IRQ after copy");
        $fatal(1);
      end
      irq_count++;
      copy_count++;
      pass_count++;
      write_reg(DMA_CTRL_OFFSET, (32'h1 << DMA_CTRL_CLEAR_BIT) | (32'h1 << DMA_CTRL_IRQ_EN_BIT), "clear done");
    end
  endtask

  task automatic check_error_cases;
    begin
      program_and_start(MEM_BASE, MEM_BASE + 32'h100, 32'd0, 1'b1);
      wait_done(1'b1);
      write_reg(DMA_CTRL_OFFSET, 32'h1 << DMA_CTRL_CLEAR_BIT, "clear zero len");
      program_and_start(MEM_BASE + 32'h1, MEM_BASE + 32'h100, 32'd1, 1'b1);
      wait_done(1'b1);
      write_reg(DMA_CTRL_OFFSET, 32'h1 << DMA_CTRL_CLEAR_BIT, "clear misalign");
      inject_read_error = 1'b1;
      program_and_start(MEM_BASE, MEM_BASE + 32'h100, 32'd1, 1'b1);
      wait_done(1'b1);
      inject_read_error = 1'b0;
      write_reg(DMA_CTRL_OFFSET, 32'h1 << DMA_CTRL_CLEAR_BIT, "clear read err");
      inject_write_error = 1'b1;
      program_and_start(MEM_BASE, MEM_BASE + 32'h100, 32'd1, 1'b1);
      wait_done(1'b1);
      inject_write_error = 1'b0;
      write_reg(DMA_CTRL_OFFSET, 32'h1 << DMA_CTRL_CLEAR_BIT, "clear write err");
      ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0, '1, AHB_HRESP_ERROR, "misaligned reg read");
      ahb_write(BASE_ADDR + DMA_SRC_OFFSET, AHB_HSIZE_BYTE, 32'h1, AHB_HRESP_ERROR, "byte write error");
      ahb_read(BASE_ADDR + 32'h80, AHB_HSIZE_WORD, '0, '1, AHB_HRESP_ERROR, "unknown reg read");
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (reg_count < 20 || copy_count < 5 || irq_count < 5 || error_count < 3 || random_count < 4) begin
        $error("coverage miss: reg=%0d copy=%0d irq=%0d error=%0d random=%0d",
               reg_count, copy_count, irq_count, error_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_dma coverage: pass_count=%0d reg_count=%0d copy_count=%0d irq_count=%0d error_count=%0d random_count=%0d read_count=%0d write_count=%0d",
               pass_count, reg_count, copy_count, irq_count, error_count,
               random_count, read_count, write_count);
    end
  endtask

  initial begin
    void'($urandom(32'hD0A0_0001));
    pass_count = 0;
    reg_count = 0;
    copy_count = 0;
    irq_count = 0;
    error_count = 0;
    random_count = 0;
    apply_reset();

    read_reg(DMA_STATUS_OFFSET, 32'h0, 32'h7, "initial status");
    check_copy(0, 32, 4);
    for (int unsigned idx = 0; idx < 4; idx++) begin
      check_copy(8 + idx * 4, 64 + idx * 4, 1 + idx);
      random_count++;
    end
    check_error_cases();
    check_coverage_summary();

    $display("tb_ahb_dma PASS");
    $finish;
  end
endmodule
