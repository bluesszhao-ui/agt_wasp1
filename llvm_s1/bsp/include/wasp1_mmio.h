#ifndef WASP1_MMIO_H
#define WASP1_MMIO_H

#include <stdint.h>

/* Read a 32-bit memory-mapped register. Volatile preserves the access. */
static inline uint32_t wasp1_read32(uintptr_t addr)
{
  return *(volatile uint32_t *)addr;
}

/* Write a 32-bit memory-mapped register. All wasp1 registers are word aligned. */
static inline void wasp1_write32(uintptr_t addr, uint32_t value)
{
  *(volatile uint32_t *)addr = value;
}

/* Set ordinary read/write control bits through a read-modify-write sequence. */
static inline void wasp1_set32(uintptr_t addr, uint32_t mask)
{
  wasp1_write32(addr, wasp1_read32(addr) | mask);
}

/* Clear ordinary read/write control bits through a read-modify-write sequence. */
static inline void wasp1_clear32(uintptr_t addr, uint32_t mask)
{
  wasp1_write32(addr, wasp1_read32(addr) & ~mask);
}

#endif
