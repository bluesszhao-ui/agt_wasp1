#ifndef WASP1_TIMER_H
#define WASP1_TIMER_H

/* Machine timer helper for the memory-mapped wasp1 mtime/mtimecmp block. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* Timer exposes 64-bit counters through low/high 32-bit register pairs. */
#define WASP1_TIMER_CTRL      UINT32_C(0x00)
#define WASP1_TIMER_STATUS    UINT32_C(0x04)
#define WASP1_TIMER_MTIME_LO  UINT32_C(0x08)
#define WASP1_TIMER_MTIME_HI  UINT32_C(0x0c)
#define WASP1_TIMER_CMP_LO    UINT32_C(0x10)
#define WASP1_TIMER_CMP_HI    UINT32_C(0x14)

#define WASP1_TIMER_CTRL_ENABLE (UINT32_C(1) << 0)
#define WASP1_TIMER_CTRL_IRQ_EN (UINT32_C(1) << 1)
#define WASP1_TIMER_STATUS_PENDING (UINT32_C(1) << 0)

static inline void wasp1_timer_enable(uint32_t irq_en)
{
  /* IRQ enable is optional so polling examples can run without trap setup. */
  uint32_t ctrl = WASP1_TIMER_CTRL_ENABLE;
  if (irq_en != 0u) {
    ctrl |= WASP1_TIMER_CTRL_IRQ_EN;
  }
  wasp1_write32(WASP1_TIMER_BASE + WASP1_TIMER_CTRL, ctrl);
}

static inline void wasp1_timer_set_cmp(uint32_t lo, uint32_t hi)
{
  /* Write high then low so the final low write arms the desired compare value. */
  wasp1_write32(WASP1_TIMER_BASE + WASP1_TIMER_CMP_HI, hi);
  wasp1_write32(WASP1_TIMER_BASE + WASP1_TIMER_CMP_LO, lo);
}

#endif
