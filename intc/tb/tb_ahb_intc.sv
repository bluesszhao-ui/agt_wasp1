`timescale 1ns/1ps

module tb_ahb_intc;
  import wasp1_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam logic [31:0] BASE_ADDR = INTC_BASE;
  localparam int REGION_BYTES = PERIPH_SIZE;

  logic hclk;
  logic hresetn;
  logic hsel;
  logic [ADDR_WIDTH-1:0] haddr;
  logic [1:0] htrans;
  logic hwrite;
  logic [2:0] hsize;
  logic [DATA_WIDTH-1:0] hwdata;
  logic [DATA_WIDTH-1:0] hrdata;
  logic hready;
  logic hresp;
  logic [IRQ_SRC_COUNT-1:0] irq_src;
  logic meip;
  logic [$clog2(IRQ_SRC_COUNT)-1:0] claim_id;

  int unsigned pass_count;
  int unsigned reg_count;
  int unsigned pending_count;
  int unsigned claim_count;
  int unsigned threshold_count;
  int unsigned error_count;
  int unsigned random_count;

  ahb_intc u_ahb_intc (
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
    .irq_src_i(irq_src),
    .meip_o(meip),
    .claim_id_o(claim_id)
  );

  initial begin
    hclk = 1'b0;
    forever #(CLK_PERIOD / 2) hclk = ~hclk;
  end

  function automatic logic [31:0] priority_offset(input int unsigned irq_id);
    priority_offset = INTC_PRIORITY_BASE_OFFSET + 32'(irq_id * INTC_PRIORITY_STRIDE);
  endfunction

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

  task automatic wait_cycles(input int unsigned cycles);
    begin
      repeat (cycles) @(posedge hclk);
      #1ns;
    end
  endtask

  task automatic apply_reset;
    begin
      irq_src = '0;
      hresetn = 1'b0;
      drive_idle();
      repeat (3) @(posedge hclk);
      hresetn = 1'b1;
      @(posedge hclk);
      #1ns;
      if (hready !== 1'b1 || hresp !== AHB_HRESP_OKAY || hrdata !== '0 ||
          meip !== 1'b0 || claim_id !== '0) begin
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
      hsel = 1'b1;
      haddr = addr;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b1;
      hsize = size;
      hwdata = data;
      @(posedge hclk);
      @(negedge hclk);
      drive_idle();
      hwdata = data;
      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: write resp expected=%0b got=%0b hready=%0b", label, expected_resp, hresp, hready);
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
      hsel = 1'b1;
      haddr = addr;
      htrans = AHB_HTRANS_NONSEQ;
      hwrite = 1'b0;
      hsize = size;
      hwdata = '0;
      @(posedge hclk);
      @(negedge hclk);
      drive_idle();
      @(posedge hclk);
      #1ns;
      if (hresp !== expected_resp || hready !== 1'b1) begin
        $error("%s: read resp expected=%0b got=%0b hready=%0b", label, expected_resp, hresp, hready);
        $fatal(1);
      end
      if (!expected_resp && ((hrdata & mask) !== (expected & mask))) begin
        $error("%s: read expected=0x%08h got=0x%08h mask=0x%08h", label, expected, hrdata, mask);
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

  task automatic drive_irq(input logic [IRQ_SRC_COUNT-1:0] value);
    begin
      irq_src = value;
      wait_cycles(3);
    end
  endtask

  task automatic check_basic_pending_enable;
    begin
      drive_irq(6'b000100);
      read_reg(INTC_PENDING_OFFSET, 32'h0000_0004, 32'h0000_003F, "pending irq2");
      if (meip !== 1'b0 || claim_id !== '0) begin
        $error("irq should be masked before enable");
        $fatal(1);
      end
      write_reg(INTC_ENABLE_OFFSET, 32'h0000_0004, "enable irq2");
      wait_cycles(1);
      if (meip !== 1'b1 || claim_id !== 3'd2) begin
        $error("expected irq2 claim meip=%0b claim=%0d", meip, claim_id);
        $fatal(1);
      end
      read_reg(INTC_CLAIM_OFFSET, 32'h0000_0002, 32'h0000_0007, "claim irq2");
      drive_irq('0);
      write_reg(INTC_CLAIM_OFFSET, 32'h0000_0002, "complete irq2");
      wait_cycles(1);
      wait_cycles(1);
      read_reg(INTC_PENDING_OFFSET, 32'h0000_0000, 32'h0000_003F, "pending clear irq2");
      pending_count++;
      claim_count++;
      pass_count++;
    end
  endtask

  task automatic check_priority_threshold;
    begin
      write_reg(INTC_ENABLE_OFFSET, 32'h0000_003E, "enable all real irqs");
      write_reg(priority_offset(2), 32'h0000_0001, "prio irq2");
      write_reg(priority_offset(4), 32'h0000_0003, "prio irq4");
      write_reg(priority_offset(5), 32'h0000_0002, "prio irq5");
      drive_irq(6'b110100);
      read_reg(INTC_CLAIM_OFFSET, 32'h0000_0004, 32'h0000_0007, "highest prio irq4");
      write_reg(INTC_THRESHOLD_OFFSET, 32'h0000_0002, "threshold two");
      wait_cycles(1);
      read_reg(INTC_CLAIM_OFFSET, 32'h0000_0004, 32'h0000_0007, "threshold keeps irq4");
      write_reg(INTC_THRESHOLD_OFFSET, 32'h0000_0003, "threshold three");
      wait_cycles(1);
      read_reg(INTC_CLAIM_OFFSET, 32'h0000_0000, 32'h0000_0007, "threshold masks all");
      if (meip !== 1'b0) begin
        $error("threshold should mask meip");
        $fatal(1);
      end
      write_reg(INTC_THRESHOLD_OFFSET, 32'h0000_0000, "threshold zero");
      drive_irq('0);
      write_reg(INTC_PENDING_OFFSET, 32'hFFFF_FFFF, "clear pending after prio");
      wait_cycles(1);
      priority_count++;
      threshold_count++;
      pass_count++;
    end
  endtask

  int unsigned priority_count;

  task automatic check_tie_break;
    begin
      write_reg(INTC_ENABLE_OFFSET, 32'h0000_003E, "enable all tie");
      write_reg(priority_offset(1), 32'h0000_0002, "prio irq1 tie");
      write_reg(priority_offset(3), 32'h0000_0002, "prio irq3 tie");
      drive_irq(6'b001010);
      read_reg(INTC_CLAIM_OFFSET, 32'h0000_0001, 32'h0000_0007, "tie lower id");
      drive_irq('0);
      write_reg(INTC_PENDING_OFFSET, 32'hFFFF_FFFF, "clear tie pending");
      wait_cycles(1);
      claim_count++;
    end
  endtask

  task automatic check_w1c_and_id0;
    begin
      write_reg(INTC_ENABLE_OFFSET, 32'hFFFF_FFFF, "enable all masks id0");
      read_reg(INTC_ENABLE_OFFSET, 32'h0000_003E, 32'h0000_003F, "id0 masked");
      drive_irq(6'b000001);
      read_reg(INTC_PENDING_OFFSET, 32'h0000_0000, 32'h0000_003F, "id0 no pending");
      drive_irq(6'b100000);
      read_reg(INTC_PENDING_OFFSET, 32'h0000_0020, 32'h0000_003F, "irq5 pending");
      drive_irq('0);
      write_reg(INTC_PENDING_OFFSET, 32'h0000_0020, "w1c irq5");
      wait_cycles(1);
      read_reg(INTC_PENDING_OFFSET, 32'h0000_0000, 32'h0000_003F, "irq5 cleared");
      pending_count++;
    end
  endtask

  task automatic check_random_sources(input int unsigned count);
    logic [IRQ_SRC_COUNT-1:0] src;
    logic [31:0] expected_claim;
    begin
      write_reg(INTC_THRESHOLD_OFFSET, 32'h0, "random threshold zero");
      write_reg(INTC_ENABLE_OFFSET, 32'h0000_003E, "random enable");
      drive_irq('0);
      write_reg(INTC_PENDING_OFFSET, 32'hFFFF_FFFF, "random initial clear");
      for (int unsigned prio_idx = 1; prio_idx < IRQ_SRC_COUNT; prio_idx++) begin
        write_reg(priority_offset(prio_idx), 32'h0000_0001, "random priority reset");
      end
      for (int unsigned idx = 0; idx < count; idx++) begin
        src = 6'($urandom()) & 6'b111110;
        if (src == '0) src = 6'b000010;
        drive_irq(src);
        expected_claim = 32'h0;
        for (int id = 1; id < IRQ_SRC_COUNT; id++) begin
          if (src[id] && expected_claim == 0) expected_claim = 32'(id);
        end
        read_reg(INTC_CLAIM_OFFSET, expected_claim, 32'h7, "random claim");
        drive_irq('0);
        write_reg(INTC_PENDING_OFFSET, 32'hFFFF_FFFF, "random clear");
        wait_cycles(1);
        random_count++;
      end
    end
  endtask

  task automatic check_error_paths;
    begin
      ahb_read(BASE_ADDR + 32'h02, AHB_HSIZE_WORD, '0, '1, AHB_HRESP_ERROR, "misaligned read");
      ahb_write(BASE_ADDR + INTC_ENABLE_OFFSET, AHB_HSIZE_BYTE, 32'h1, AHB_HRESP_ERROR, "byte write");
      ahb_read(BASE_ADDR + 32'h18, AHB_HSIZE_WORD, '0, '1, AHB_HRESP_ERROR, "unknown read");
      ahb_write(BASE_ADDR + priority_offset(IRQ_SRC_COUNT), AHB_HSIZE_WORD, 32'h1, AHB_HRESP_ERROR, "bad priority");
      ahb_read(BASE_ADDR + REGION_BYTES, AHB_HSIZE_WORD, '0, '1, AHB_HRESP_ERROR, "out range");
    end
  endtask

  task automatic check_coverage_summary;
    begin
      if (reg_count < 35 || pending_count < 2 || claim_count < 2 || threshold_count < 1 ||
          priority_count < 1 || error_count < 5 || random_count < 8) begin
        $error("coverage miss: reg=%0d pending=%0d claim=%0d threshold=%0d priority=%0d error=%0d random=%0d",
               reg_count, pending_count, claim_count, threshold_count, priority_count, error_count, random_count);
        $fatal(1);
      end
      $display("tb_ahb_intc coverage: pass_count=%0d reg_count=%0d pending_count=%0d claim_count=%0d threshold_count=%0d priority_count=%0d error_count=%0d random_count=%0d",
               pass_count, reg_count, pending_count, claim_count, threshold_count,
               priority_count, error_count, random_count);
    end
  endtask

  initial begin
    void'($urandom(32'h1A7C_0001));
    pass_count = 0;
    reg_count = 0;
    pending_count = 0;
    claim_count = 0;
    threshold_count = 0;
    priority_count = 0;
    error_count = 0;
    random_count = 0;

    apply_reset();
    read_reg(INTC_PENDING_OFFSET, 32'h0, 32'h3F, "initial pending");
    read_reg(INTC_ENABLE_OFFSET, 32'h0, 32'h3F, "initial enable");
    read_reg(INTC_THRESHOLD_OFFSET, 32'h0, 32'h3, "initial threshold");
    read_reg(priority_offset(0), 32'h0, 32'h3, "initial prio0");
    read_reg(priority_offset(1), 32'h1, 32'h3, "initial prio1");

    check_basic_pending_enable();
    check_priority_threshold();
    check_tie_break();
    check_w1c_and_id0();
    check_random_sources(8);
    check_error_paths();
    check_coverage_summary();

    $display("tb_ahb_intc PASS");
    $finish;
  end
endmodule
