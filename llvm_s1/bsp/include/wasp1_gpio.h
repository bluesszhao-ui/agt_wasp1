#ifndef WASP1_GPIO_H
#define WASP1_GPIO_H

/* GPIO register helpers for direction, data, and simple output updates. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* Register offsets follow gpio/rtl/ahb_gpio.sv. */
#define WASP1_GPIO_DATA_IN    UINT32_C(0x00)
#define WASP1_GPIO_DATA_OUT   UINT32_C(0x04)
#define WASP1_GPIO_DIR        UINT32_C(0x08)
#define WASP1_GPIO_SET        UINT32_C(0x0c)
#define WASP1_GPIO_CLR        UINT32_C(0x10)
#define WASP1_GPIO_TOGGLE     UINT32_C(0x14)
#define WASP1_GPIO_IRQ_EN     UINT32_C(0x18)
#define WASP1_GPIO_IRQ_TYPE   UINT32_C(0x1c)
#define WASP1_GPIO_IRQ_POL    UINT32_C(0x20)
#define WASP1_GPIO_IRQ_STATUS UINT32_C(0x24)

static inline uint32_t wasp1_gpio_read(void)
{
  /* DATA_IN reflects the synchronized external pin level. */
  return wasp1_read32(WASP1_GPIO_BASE + WASP1_GPIO_DATA_IN);
}

static inline void wasp1_gpio_set_dir(uint32_t mask)
{
  /* One bit per GPIO; 1 selects output and 0 selects input. */
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_DIR, mask);
}

static inline void wasp1_gpio_write(uint32_t value)
{
  /* DATA_OUT replaces the complete 32-bit output register. */
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_DATA_OUT, value);
}

static inline void wasp1_gpio_set(uint32_t mask)
{
  /* SET modifies only asserted bits in the output register. */
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_SET, mask);
}

static inline void wasp1_gpio_clear(uint32_t mask)
{
  /* CLR modifies only asserted bits in the output register. */
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_CLR, mask);
}

static inline void wasp1_gpio_toggle(uint32_t mask)
{
  /* TOGGLE flips only asserted bits in the output register. */
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_TOGGLE, mask);
}

static inline void wasp1_gpio_irq_config(uint32_t enable_mask, uint32_t type_mask, uint32_t polarity_mask)
{
  /*
   * IRQ_TYPE: 1=edge, 0=level. IRQ_POL: for edge 1=rising/0=falling;
   * for level 1=high/0=low.
   */
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_IRQ_EN, 0u);
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_IRQ_TYPE, type_mask);
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_IRQ_POL, polarity_mask);
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_IRQ_STATUS, enable_mask);
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_IRQ_EN, enable_mask);
}

static inline void wasp1_gpio_irq_disable(uint32_t mask)
{
  /* Disable selected GPIO interrupt bits with an ordinary RMW clear. */
  wasp1_clear32(WASP1_GPIO_BASE + WASP1_GPIO_IRQ_EN, mask);
}

static inline void wasp1_gpio_irq_clear(uint32_t mask)
{
  /* IRQ_STATUS is write-one-to-clear. */
  wasp1_write32(WASP1_GPIO_BASE + WASP1_GPIO_IRQ_STATUS, mask);
}

#endif
