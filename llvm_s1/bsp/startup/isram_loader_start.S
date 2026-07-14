  # Entry point for a loader injected directly into I-SRAM through JTAG.
  .section .text.start, "ax", @progbits
  .globl _start
  .type _start, @function

_start:
  # Establish the small-data base and an I-SRAM-local stack.
  .option push
  .option norelax
  la gp, __global_pointer$
  .option pop
  la sp, __stack_top

  # Unexpected traps stay in a visible local loop for debugger inspection.
  la t0, .Ltrap
  csrw mtvec, t0

  # JTAG ELF loading initializes data, but BSS still requires architectural 0.
  la a0, __bss_start
  la a1, __bss_end
.Lzero_bss:
  bgeu a0, a1, .Lmain
  sw zero, 0(a0)
  addi a0, a0, 4
  j .Lzero_bss

.Lmain:
  call main
.Ltrap:
  j .Ltrap

  .size _start, . - _start
