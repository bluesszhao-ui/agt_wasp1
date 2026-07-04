#ifndef WASP1_RUNTIME_H
#define WASP1_RUNTIME_H

/* Small runtime helpers shared by freestanding wasp1 examples. */

static inline void __attribute__((noreturn)) wasp1_idle_forever(void)
{
#if defined(__riscv)
  /*
   * Use a branch-based idle loop instead of relying on compiler-generated
   * `jal x0, 0`. The branch form is already covered by the early core tests
   * and keeps software smoke tests from depending on one exact JAL idle idiom.
   */
  __asm__ volatile (
    "1:\n\t"
    "nop\n\t"
    "beq zero, zero, 1b\n\t"
    ::: "memory"
  );
#endif
  for (;;) {
  }
}

#endif
