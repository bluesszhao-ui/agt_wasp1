  # Reset entry for freestanding wasp1 programs linked into executable OTP.
  .section .text.start, "ax", @progbits
  .globl _start
  .type _start, @function

_start:
  # Initialize the global pointer and stack before any C code can run.
  .option push
  .option norelax
  la gp, __global_pointer$
  .option pop
  la sp, __stack_top

  # Direct all machine traps to the stage-1 trap stub.
  la t0, __trap_entry
  csrw mtvec, t0

  # Copy optional .fasttext from OTP to I-SRAM for routines tagged as fast code.
  la a0, __fasttext_load_start
  la a1, __fasttext_start
  la a2, __fasttext_end
1:
  bgeu a1, a2, 2f
  lw t0, 0(a0)
  sw t0, 0(a1)
  addi a0, a0, 4
  addi a1, a1, 4
  j 1b

2:
  # Copy initialized data from its OTP load image into D-SRAM.
  la a0, __data_load_start
  la a1, __data_start
  la a2, __data_end
3:
  bgeu a1, a2, 4f
  lw t0, 0(a0)
  sw t0, 0(a1)
  addi a0, a0, 4
  addi a1, a1, 4
  j 3b

4:
  # Zero .bss so C static storage starts with the architectural value 0.
  la a0, __bss_start
  la a1, __bss_end
5:
  bgeu a0, a1, 6f
  sw zero, 0(a0)
  addi a0, a0, 4
  j 5b

6:
  # Enter user firmware. Returning from main falls into a quiet halt loop.
  call main

7:
  j 7b

  .size _start, . - _start
