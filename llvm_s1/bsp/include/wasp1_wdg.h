#ifndef WASP1_WDG_H
#define WASP1_WDG_H

/* Watchdog helper for timeout, IRQ, reset request, and kick operations. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* Watchdog register offsets follow wdg/rtl/ahb_wdg.sv. */
#define WASP1_WDG_CTRL        UINT32_C(0x00)
#define WASP1_WDG_STATUS      UINT32_C(0x04)
#define WASP1_WDG_TIMEOUT     UINT32_C(0x08)
#define WASP1_WDG_COUNT       UINT32_C(0x0c)
#define WASP1_WDG_KICK        UINT32_C(0x10)

#define WASP1_WDG_KICK_VALUE  UINT32_C(0x57444f47)

#define WASP1_WDG_CTRL_ENABLE   (UINT32_C(1) << 0)
#define WASP1_WDG_CTRL_IRQ_EN   (UINT32_C(1) << 1)
#define WASP1_WDG_CTRL_RESET_EN (UINT32_C(1) << 2)
#define WASP1_WDG_CTRL_CLEAR    (UINT32_C(1) << 3)

static inline void wasp1_wdg_start(uint32_t timeout, uint32_t irq_en, uint32_t reset_en)
{
  /* CLEAR resets stale timeout state while preserving the selected enables. */
  uint32_t ctrl = WASP1_WDG_CTRL_ENABLE;
  if (irq_en != 0u) {
    ctrl |= WASP1_WDG_CTRL_IRQ_EN;
  }
  if (reset_en != 0u) {
    ctrl |= WASP1_WDG_CTRL_RESET_EN;
  }
  wasp1_write32(WASP1_WDG_BASE + WASP1_WDG_TIMEOUT, timeout);
  wasp1_write32(WASP1_WDG_BASE + WASP1_WDG_CTRL, ctrl | WASP1_WDG_CTRL_CLEAR);
}

static inline void wasp1_wdg_kick(void)
{
  /* The hardware accepts only the documented magic word as a valid kick. */
  wasp1_write32(WASP1_WDG_BASE + WASP1_WDG_KICK, WASP1_WDG_KICK_VALUE);
}

#endif
