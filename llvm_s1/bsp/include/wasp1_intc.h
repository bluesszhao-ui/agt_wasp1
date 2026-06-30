#ifndef WASP1_INTC_H
#define WASP1_INTC_H

/* PLIC-lite interrupt controller helper definitions. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* Register offsets follow intc/rtl/ahb_intc.sv. */
#define WASP1_INTC_PENDING    UINT32_C(0x00)
#define WASP1_INTC_ENABLE     UINT32_C(0x04)
#define WASP1_INTC_CLAIM      UINT32_C(0x08)
#define WASP1_INTC_THRESHOLD  UINT32_C(0x0c)
#define WASP1_INTC_PRIORITY_BASE UINT32_C(0x20)
#define WASP1_INTC_PRIORITY_STRIDE UINT32_C(4)

#define WASP1_IRQ_WDG         UINT32_C(1)
#define WASP1_IRQ_UART        UINT32_C(2)
#define WASP1_IRQ_I2C         UINT32_C(3)
#define WASP1_IRQ_GPIO        UINT32_C(4)
#define WASP1_IRQ_DMA         UINT32_C(5)

static inline void wasp1_intc_enable(uint32_t irq_id)
{
  /* IRQ ID 0 is reserved; valid device IDs are defined above. */
  wasp1_set32(WASP1_INTC_BASE + WASP1_INTC_ENABLE, UINT32_C(1) << irq_id);
}

static inline uint32_t wasp1_intc_claim(void)
{
  /* Claim returns 0 when no enabled interrupt exceeds the threshold. */
  return wasp1_read32(WASP1_INTC_BASE + WASP1_INTC_CLAIM);
}

static inline void wasp1_intc_complete(uint32_t irq_id)
{
  /* Completion writes the claimed ID back to the claim/complete register. */
  wasp1_write32(WASP1_INTC_BASE + WASP1_INTC_CLAIM, irq_id);
}

#endif
