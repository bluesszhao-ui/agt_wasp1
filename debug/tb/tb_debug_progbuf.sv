`timescale 1ns/1ps

// Self-checking storage, priority, and deterministic-random testbench for the
// four-word Debug Module Program Buffer leaf.
module tb_debug_progbuf;
  import debug_dmi_pkg::*;

  localparam time CLK_PERIOD = 10ns;
  localparam int INDEX_WIDTH = $clog2(PROGBUF_WORD_COUNT);

  logic clk;                         // 100 MHz verification clock.
  logic rst_n;                       // Active-low asynchronous reset stimulus.
  logic clear;                       // Synchronous whole-buffer clear stimulus.
  logic write_valid;                 // Directed/random write request pulse.
  logic [INDEX_WIDTH-1:0] write_index;// Selected write word.
  logic [31:0] write_data;           // Selected write payload.
  logic [INDEX_WIDTH-1:0] read_index;// Combinational selected read word.
  logic [31:0] read_data;            // DUT selected read result.
  logic [PROGBUF_WORD_COUNT-1:0][31:0] words; // DUT full executor view.
  logic [31:0] model [PROGBUF_WORD_COUNT]; // Reference storage scoreboard.

  int unsigned pass_count;           // Total completed self-checking phases.
  int unsigned reset_count;          // Reset and synchronous-clear coverage.
  int unsigned write_count;          // Accepted directed/random writes.
  int unsigned read_count;           // Explicit word read comparisons.
  int unsigned priority_count;       // Clear-over-write priority coverage.
  int unsigned random_count;         // Deterministic-random write/read rounds.

  debug_progbuf u_debug_progbuf (
    .clk_i(clk),
    .rst_ni(rst_n),
    .clear_i(clear),
    .write_valid_i(write_valid),
    .write_index_i(write_index),
    .write_data_i(write_data),
    .read_index_i(read_index),
    .read_data_o(read_data),
    .words_o(words)
  );

  initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // Compare both the selected DMI view and the full future executor view.
  task automatic check_all(input string label);
    begin
      for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
        read_index = INDEX_WIDTH'(idx);
        #1ns;
        if ((read_data !== model[idx]) || (words[idx] !== model[idx])) begin
          $fatal(1, "%s word%0d mismatch read=0x%08x full=0x%08x expected=0x%08x",
                 label, idx, read_data, words[idx], model[idx]);
        end
        read_count++;
      end
      pass_count++;
    end
  endtask

  // Apply one accepted write and update the software reference model.
  task automatic write_word(
    input int unsigned index,
    input logic [31:0] value
  );
    begin
      @(negedge clk);
      write_valid = 1'b1;
      write_index = INDEX_WIDTH'(index);
      write_data = value;
      @(posedge clk);
      #1ns;
      write_valid = 1'b0;
      model[index] = value;
      write_count++;
    end
  endtask

  initial begin
    pass_count = 0;
    reset_count = 0;
    write_count = 0;
    read_count = 0;
    priority_count = 0;
    random_count = 0;
    clear = 1'b0;
    write_valid = 1'b0;
    write_index = '0;
    write_data = '0;
    read_index = '0;
    for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) model[idx] = '0;

    $display("phase reset start=%0t", $time);
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    #1ns;
    check_all("asynchronous reset");
    reset_count++;

    $display("phase directed start=%0t", $time);
    for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) begin
      write_word(idx, 32'h1000_0000 ^ (32'h0101_0101 * idx));
    end
    check_all("directed independent words");

    $display("phase priority start=%0t", $time);
    @(negedge clk);
    clear = 1'b1;
    write_valid = 1'b1;
    write_index = INDEX_WIDTH'(2);
    write_data = 32'hFFFF_FFFF;
    @(posedge clk);
    #1ns;
    clear = 1'b0;
    write_valid = 1'b0;
    for (int unsigned idx = 0; idx < PROGBUF_WORD_COUNT; idx++) model[idx] = '0;
    check_all("clear dominates write");
    reset_count++;
    priority_count++;

    $display("phase random start=%0t", $time);
    void'($urandom(32'h5052_4F47));
    for (int unsigned iter = 0; iter < 64; iter++) begin
      int unsigned index;
      logic [31:0] value;
      index = $urandom_range(PROGBUF_WORD_COUNT - 1, 0);
      value = $urandom();
      write_word(index, value);
      check_all("random scoreboard");
      random_count++;
    end

    if ((reset_count != 2) || (write_count != 68) ||
        (priority_count != 1) || (random_count != 64)) begin
      $fatal(1, "coverage goal missed");
    end
    $display("phase complete=%0t", $time);
    $display("tb_debug_progbuf coverage: pass=%0d reset=%0d write=%0d read=%0d priority=%0d random=%0d",
             pass_count, reset_count, write_count, read_count,
             priority_count, random_count);
    $display("tb_debug_progbuf PASS");
    $finish;
  end
endmodule
