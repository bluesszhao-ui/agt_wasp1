#ifndef WASP1_CSR_H
#define WASP1_CSR_H

/* Minimal machine-mode CSR helpers for RV32I+Zicsr firmware examples. */
#include <stdint.h>

#define WASP1_MSTATUS_MIE (UINT32_C(1) << 3)
#define WASP1_MIE_MTIE    (UINT32_C(1) << 7)
#define WASP1_MIE_MEIE    (UINT32_C(1) << 11)

#define WASP1_MCAUSE_INTERRUPT_BIT UINT32_C(0x80000000)
#define WASP1_MCAUSE_MACHINE_TIMER (WASP1_MCAUSE_INTERRUPT_BIT | UINT32_C(7))
#define WASP1_MCAUSE_MACHINE_EXTERNAL (WASP1_MCAUSE_INTERRUPT_BIT | UINT32_C(11))

static inline uint32_t wasp1_csr_read_mstatus(void)
{
#if defined(__riscv)
  uint32_t value;
  __asm__ volatile ("csrr %0, mstatus" : "=r"(value));
  return value;
#else
  return 0u;
#endif
}

static inline uint32_t wasp1_csr_read_mie(void)
{
#if defined(__riscv)
  uint32_t value;
  __asm__ volatile ("csrr %0, mie" : "=r"(value));
  return value;
#else
  return 0u;
#endif
}

static inline void wasp1_csr_set_mstatus(uint32_t mask)
{
#if defined(__riscv)
  __asm__ volatile ("csrs mstatus, %0" :: "r"(mask) : "memory");
#else
  (void)mask;
#endif
}

static inline void wasp1_csr_clear_mstatus(uint32_t mask)
{
#if defined(__riscv)
  __asm__ volatile ("csrc mstatus, %0" :: "r"(mask) : "memory");
#else
  (void)mask;
#endif
}

static inline void wasp1_csr_set_mie(uint32_t mask)
{
#if defined(__riscv)
  __asm__ volatile ("csrs mie, %0" :: "r"(mask) : "memory");
#else
  (void)mask;
#endif
}

static inline void wasp1_csr_clear_mie(uint32_t mask)
{
#if defined(__riscv)
  __asm__ volatile ("csrc mie, %0" :: "r"(mask) : "memory");
#else
  (void)mask;
#endif
}

#endif
