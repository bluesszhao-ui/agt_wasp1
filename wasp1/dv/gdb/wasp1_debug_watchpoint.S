/*
 * Deterministic RV32I program for the OpenOCD/GDB data-watchpoint regression.
 * The fixed instruction addresses let the GDB script distinguish a precise
 * pre-access halt from a later stop caused by an already-completed access.
 */
  .section .text
  .globl _start
_start:
  .word 0x00028063       /* 0x00: beq t0, zero, 0; pre-access gate. */
watch_loop:
  lw   t1, 0(t0)         /* 0x04: read-watchpoint target. */
  addi t1, zero, 0x55    /* 0x08: value used by the following store. */
  sw   t1, 0(t0)         /* 0x0c: write-watchpoint target. */
  jal  zero, watch_loop  /* 0x10: repeat the watched load/store sequence. */
