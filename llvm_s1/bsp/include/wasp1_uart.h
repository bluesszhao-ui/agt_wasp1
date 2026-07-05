#ifndef WASP1_UART_H
#define WASP1_UART_H

/* Polled UART driver used by early boot logs and freestanding examples. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* Register offsets match uart/rtl/ahb_uart.sv. */
#define WASP1_UART_DATA       UINT32_C(0x00)
#define WASP1_UART_STATUS     UINT32_C(0x04)
#define WASP1_UART_CTRL       UINT32_C(0x08)
#define WASP1_UART_BAUD       UINT32_C(0x0c)
#define WASP1_UART_IRQ_STATUS UINT32_C(0x10)

#define WASP1_UART_CTRL_ENABLE    (UINT32_C(1) << 0)
#define WASP1_UART_CTRL_TX_EN     (UINT32_C(1) << 1)
#define WASP1_UART_CTRL_RX_EN     (UINT32_C(1) << 2)
#define WASP1_UART_CTRL_TX_IRQ_EN (UINT32_C(1) << 3)
#define WASP1_UART_CTRL_RX_IRQ_EN (UINT32_C(1) << 4)
#define WASP1_UART_CTRL_OVR_IRQ_EN (UINT32_C(1) << 5)

#define WASP1_UART_STATUS_TX_EMPTY (UINT32_C(1) << 0)
#define WASP1_UART_STATUS_TX_FULL  (UINT32_C(1) << 1)
#define WASP1_UART_STATUS_RX_EMPTY (UINT32_C(1) << 2)
#define WASP1_UART_STATUS_RX_FULL  (UINT32_C(1) << 3)
#define WASP1_UART_STATUS_TX_BUSY  (UINT32_C(1) << 4)
#define WASP1_UART_STATUS_RX_OVERRUN (UINT32_C(1) << 5)

#define WASP1_UART_IRQ_TX_EMPTY (UINT32_C(1) << 0)
#define WASP1_UART_IRQ_RX_AVAIL (UINT32_C(1) << 1)
#define WASP1_UART_IRQ_RX_OVERRUN (UINT32_C(1) << 2)

static inline void wasp1_uart_init(uint32_t baud_div)
{
  /* Program divisor before enabling TX/RX so the first character uses it. */
  wasp1_write32(WASP1_UART_BASE + WASP1_UART_BAUD, baud_div);
  wasp1_write32(WASP1_UART_BASE + WASP1_UART_CTRL,
                WASP1_UART_CTRL_ENABLE | WASP1_UART_CTRL_TX_EN | WASP1_UART_CTRL_RX_EN);
}

static inline void wasp1_uart_putc(char ch)
{
  /* Polling avoids interrupt/runtime dependencies during this first BSP stage. */
  while (wasp1_read32(WASP1_UART_BASE + WASP1_UART_STATUS) & WASP1_UART_STATUS_TX_FULL) {
  }
  wasp1_write32(WASP1_UART_BASE + WASP1_UART_DATA, (uint32_t)(uint8_t)ch);
}

static inline void wasp1_uart_puts(const char *text)
{
  /* Emit CR before LF for terminal compatibility; hardware stores only bytes. */
  while (*text != '\0') {
    if (*text == '\n') {
      wasp1_uart_putc('\r');
    }
    wasp1_uart_putc(*text++);
  }
}

static inline uint32_t wasp1_uart_irq_status(void)
{
  /* IRQ_STATUS is sticky W1C state, independent of the live STATUS register. */
  return wasp1_read32(WASP1_UART_BASE + WASP1_UART_IRQ_STATUS);
}

static inline void wasp1_uart_irq_clear(uint32_t mask)
{
  /* Hardware clears only the status bits written as 1. */
  wasp1_write32(WASP1_UART_BASE + WASP1_UART_IRQ_STATUS, mask);
}

static inline void wasp1_uart_irq_config(uint32_t baud_div, uint32_t ctrl_irq_mask)
{
  /*
   * Clear stale sticky IRQ status before enabling IRQ sources. The caller passes
   * CTRL IRQ enable bits, such as WASP1_UART_CTRL_TX_IRQ_EN.
   */
  wasp1_write32(WASP1_UART_BASE + WASP1_UART_BAUD, baud_div);
  wasp1_uart_irq_clear(WASP1_UART_IRQ_TX_EMPTY |
                       WASP1_UART_IRQ_RX_AVAIL |
                       WASP1_UART_IRQ_RX_OVERRUN);
  wasp1_write32(WASP1_UART_BASE + WASP1_UART_CTRL,
                WASP1_UART_CTRL_ENABLE |
                WASP1_UART_CTRL_TX_EN |
                WASP1_UART_CTRL_RX_EN |
                ctrl_irq_mask);
}

static inline void wasp1_uart_irq_disable(uint32_t ctrl_irq_mask)
{
  /* Disable selected UART IRQ-enable bits without changing UART TX/RX enables. */
  wasp1_clear32(WASP1_UART_BASE + WASP1_UART_CTRL, ctrl_irq_mask);
}

#endif
