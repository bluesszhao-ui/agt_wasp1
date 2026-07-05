#include "wasp1.h"

/*
 * Longer generated-image boot regression. This program deliberately touches
 * several independent SoC paths in one OTP boot: UART MMIO, GPIO register
 * updates, CPU D-SRAM stores/loads, DMA as the second AHB master, timer MMIO
 * polling, and executable OTP reads. The top-level testbench checks the final
 * D-SRAM mailbox and the hardware side effects.
 */
#define LONG_BOOT_MAILBOX_BASE  (WASP1_DSRAM_BASE + UINT32_C(0x00003600))
#define LONG_BOOT_DMA_SRC_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003700))
#define LONG_BOOT_DMA_DST_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003740))
#define LONG_BOOT_WORDS         UINT32_C(8)

#define LONG_BOOT_MAGIC         UINT32_C(0x4c424f4f)
#define LONG_BOOT_DONE          UINT32_C(0x4c424f4b)
#define LONG_BOOT_GPIO_EXPECTED UINT32_C(0x0000000a)

enum {
  LONG_BOOT_MAGIC_WORD = 0,
  LONG_BOOT_SUM_WORD = 1,
  LONG_BOOT_GPIO_WORD = 2,
  LONG_BOOT_DMA_STATUS_WORD = 3,
  LONG_BOOT_TIMER_STATUS_WORD = 4,
  LONG_BOOT_OTP0_WORD = 5,
  LONG_BOOT_DONE_WORD = 6
};

static const uint32_t long_boot_pattern[LONG_BOOT_WORDS] = {
  UINT32_C(0x01020304),
  UINT32_C(0x11223344),
  UINT32_C(0x55667788),
  UINT32_C(0x99aabbcc),
  UINT32_C(0xddeeff00),
  UINT32_C(0x13572468),
  UINT32_C(0x2468ace0),
  UINT32_C(0xf0e0d0c0)
};

static volatile uint32_t long_boot_sink;

static void clear_mailbox(void)
{
  volatile uint32_t *mailbox = (volatile uint32_t *)LONG_BOOT_MAILBOX_BASE;

  /* Clear all mailbox words so the testbench can distinguish stale state. */
  for (uint32_t idx = 0u; idx <= LONG_BOOT_DONE_WORD; ++idx) {
    mailbox[idx] = 0u;
  }
}

static uint32_t seed_and_sum_dma_buffers(void)
{
  volatile uint32_t *src = (volatile uint32_t *)LONG_BOOT_DMA_SRC_ADDR;
  volatile uint32_t *dst = (volatile uint32_t *)LONG_BOOT_DMA_DST_ADDR;
  uint32_t sum = 0u;

  /*
   * CPU writes seed D-SRAM data, then reads it back as a simple ordering point
   * before the DMA master observes the same memory through AHB.
   */
  for (uint32_t idx = 0u; idx < LONG_BOOT_WORDS; ++idx) {
    src[idx] = long_boot_pattern[idx];
    dst[idx] = UINT32_C(0xfeed0000) | idx;
  }
  for (uint32_t idx = 0u; idx < LONG_BOOT_WORDS; ++idx) {
    sum += src[idx];
  }
  long_boot_sink = sum;
  return sum;
}

static uint32_t run_dma_copy(void)
{
  uint32_t status;
  uint32_t timeout = 0u;

  wasp1_dma_start(LONG_BOOT_DMA_SRC_ADDR, LONG_BOOT_DMA_DST_ADDR,
                  LONG_BOOT_WORDS, 0u);
  do {
    status = wasp1_read32(WASP1_DMA_BASE + WASP1_DMA_STATUS);
    ++timeout;
  } while (((status & WASP1_DMA_STATUS_DONE) == 0u) &&
           ((status & WASP1_DMA_STATUS_ERROR) == 0u) &&
           (timeout < UINT32_C(10000)));

  return status;
}

static uint32_t run_timer_poll(void)
{
  uint32_t status;
  uint32_t timeout = 0u;

  wasp1_timer_disable();
  wasp1_timer_set_mtime(0u, 0u);
  wasp1_timer_set_cmp(24u, 0u);
  wasp1_timer_enable(0u);
  do {
    status = wasp1_read32(WASP1_TIMER_BASE + WASP1_TIMER_STATUS);
    ++timeout;
  } while (((status & WASP1_TIMER_STATUS_PENDING) == 0u) &&
           (timeout < UINT32_C(10000)));
  wasp1_timer_disable();

  return status;
}

int main(void)
{
  volatile uint32_t *mailbox = (volatile uint32_t *)LONG_BOOT_MAILBOX_BASE;
  volatile const uint32_t *otp_words = (volatile const uint32_t *)WASP1_OTP_BASE;
  uint32_t sum;
  uint32_t dma_status;
  uint32_t timer_status;
  uint32_t otp_word0;
  uint32_t gpio_value;

  clear_mailbox();

  wasp1_uart_init(8u);
  wasp1_uart_puts("wasp1 long boot regression\n");

  wasp1_gpio_set_dir(UINT32_C(0x0000000f));
  wasp1_gpio_write(UINT32_C(0x00000005));
  wasp1_gpio_toggle(UINT32_C(0x0000000f));
  gpio_value = wasp1_read32(WASP1_GPIO_BASE + WASP1_GPIO_DATA_OUT);

  sum = seed_and_sum_dma_buffers();
  dma_status = run_dma_copy();
  timer_status = run_timer_poll();
  otp_word0 = otp_words[0];

  mailbox[LONG_BOOT_SUM_WORD] = sum;
  mailbox[LONG_BOOT_GPIO_WORD] = gpio_value;
  mailbox[LONG_BOOT_DMA_STATUS_WORD] = dma_status;
  mailbox[LONG_BOOT_TIMER_STATUS_WORD] = timer_status;
  mailbox[LONG_BOOT_OTP0_WORD] = otp_word0;
  mailbox[LONG_BOOT_MAGIC_WORD] = LONG_BOOT_MAGIC;
  mailbox[LONG_BOOT_DONE_WORD] = LONG_BOOT_DONE;

  wasp1_idle_forever();
}
