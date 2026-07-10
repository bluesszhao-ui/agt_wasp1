#include "wasp1.h"

/*
 * System-level polling stress regression. It intentionally avoids interrupt
 * setup so failures localize to CPU/cache/AHB/DMA/timer/GPIO/UART paths rather
 * than trap sequencing. Dedicated IRQ examples cover interrupt behavior.
 */
#define SYSTEM_STRESS_BOX_ADDR      (WASP1_DSRAM_BASE + UINT32_C(0x00003c00))
#define SYSTEM_STRESS_DMA_SRC_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003d00))
#define SYSTEM_STRESS_DMA_DST_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003d80))

#define SYSTEM_STRESS_ROUNDS        UINT32_C(6)
#define SYSTEM_STRESS_WORDS         UINT32_C(8)
#define SYSTEM_STRESS_MAGIC         UINT32_C(0x53545352)
#define SYSTEM_STRESS_DONE          UINT32_C(0x53544f4b)

enum {
  SYSTEM_STRESS_MAGIC_WORD = 0,
  SYSTEM_STRESS_DONE_WORD = 1,
  SYSTEM_STRESS_ROUNDS_WORD = 2,
  SYSTEM_STRESS_CHECKSUM_WORD = 3,
  SYSTEM_STRESS_GPIO_WORD = 4,
  SYSTEM_STRESS_DMA_STATUS_WORD = 5,
  SYSTEM_STRESS_TIMER_STATUS_WORD = 6,
  SYSTEM_STRESS_OTP_XOR_WORD = 7,
  SYSTEM_STRESS_UART_COUNT_WORD = 8
};

static volatile uint32_t system_stress_sink;

static uint32_t stress_pattern(uint32_t round, uint32_t idx)
{
  /*
   * Use shifts, OR, and XOR only so the RV32I compiler does not need multiply
   * support for the deterministic data pattern.
   */
  return UINT32_C(0x51000000) |
         ((round & UINT32_C(0x0f)) << 20) |
         ((idx & UINT32_C(0x0f)) << 12) |
         ((round & UINT32_C(0x0f)) << 4) |
         (idx & UINT32_C(0x0f));
}

static uint32_t run_dma_round(uint32_t round)
{
  volatile uint32_t *src = (volatile uint32_t *)SYSTEM_STRESS_DMA_SRC_ADDR;
  volatile uint32_t *dst = (volatile uint32_t *)SYSTEM_STRESS_DMA_DST_ADDR;
  uint32_t status;
  uint32_t timeout = 0u;
  uint32_t folded = 0u;

  for (uint32_t idx = 0u; idx < SYSTEM_STRESS_WORDS; ++idx) {
    src[idx] = stress_pattern(round, idx);
    dst[idx] = UINT32_C(0xa5000000) | (round << 8) | idx;
  }
  for (uint32_t idx = 0u; idx < SYSTEM_STRESS_WORDS; ++idx) {
    folded ^= src[idx];
  }
  system_stress_sink = folded;

  wasp1_dma_start(SYSTEM_STRESS_DMA_SRC_ADDR, SYSTEM_STRESS_DMA_DST_ADDR,
                  SYSTEM_STRESS_WORDS, 0u);
  do {
    status = wasp1_read32(WASP1_DMA_BASE + WASP1_DMA_STATUS);
    ++timeout;
  } while (((status & WASP1_DMA_STATUS_DONE) == 0u) &&
           ((status & WASP1_DMA_STATUS_ERROR) == 0u) &&
           (timeout < UINT32_C(20000)));

  wasp1_dma_clear_done_error();
  return status;
}

static uint32_t run_timer_round(uint32_t round)
{
  uint32_t status;
  uint32_t timeout = 0u;

  wasp1_timer_disable();
  wasp1_timer_set_mtime(0u, 0u);
  wasp1_timer_set_cmp(UINT32_C(12) + round, 0u);
  wasp1_timer_enable(0u);
  do {
    status = wasp1_read32(WASP1_TIMER_BASE + WASP1_TIMER_STATUS);
    ++timeout;
  } while (((status & WASP1_TIMER_STATUS_PENDING) == 0u) &&
           (timeout < UINT32_C(20000)));
  wasp1_timer_disable();
  return status;
}

int main(void)
{
  volatile uint32_t *box = (volatile uint32_t *)SYSTEM_STRESS_BOX_ADDR;
  volatile uint32_t *dst = (volatile uint32_t *)SYSTEM_STRESS_DMA_DST_ADDR;
  volatile const uint32_t *otp = (volatile const uint32_t *)WASP1_OTP_BASE;
  uint32_t checksum = 0u;
  uint32_t dma_status_acc = 0u;
  uint32_t timer_status_acc = 0u;
  uint32_t otp_xor = 0u;
  uint32_t gpio_value = 0u;
  uint32_t uart_count = 0u;

  for (uint32_t idx = 0u; idx <= SYSTEM_STRESS_UART_COUNT_WORD; ++idx) {
    box[idx] = 0u;
  }

  wasp1_uart_init(6u);
  wasp1_uart_puts("wasp1 system stress\n");
  uart_count += UINT32_C(21);

  wasp1_gpio_set_dir(UINT32_C(0x000000ff));

  for (uint32_t idx = 0u; idx < 4u; ++idx) {
    otp_xor ^= otp[idx];
  }

  for (uint32_t round = 0u; round < SYSTEM_STRESS_ROUNDS; ++round) {
    dma_status_acc |= run_dma_round(round);

    for (uint32_t idx = 0u; idx < SYSTEM_STRESS_WORDS; ++idx) {
      checksum += dst[idx] ^ (round << idx);
    }

    timer_status_acc |= run_timer_round(round);

    gpio_value = (UINT32_C(0x5a) ^ (round << 1)) & UINT32_C(0xff);
    wasp1_gpio_write(gpio_value);
    wasp1_gpio_toggle(UINT32_C(0x0000000f));
    gpio_value = wasp1_read32(WASP1_GPIO_BASE + WASP1_GPIO_DATA_OUT);

    wasp1_uart_putc((char)('A' + (char)round));
    ++uart_count;
  }

  box[SYSTEM_STRESS_ROUNDS_WORD] = SYSTEM_STRESS_ROUNDS;
  box[SYSTEM_STRESS_CHECKSUM_WORD] = checksum;
  box[SYSTEM_STRESS_GPIO_WORD] = gpio_value;
  box[SYSTEM_STRESS_DMA_STATUS_WORD] = dma_status_acc;
  box[SYSTEM_STRESS_TIMER_STATUS_WORD] = timer_status_acc;
  box[SYSTEM_STRESS_OTP_XOR_WORD] = otp_xor;
  box[SYSTEM_STRESS_UART_COUNT_WORD] = uart_count;
  box[SYSTEM_STRESS_MAGIC_WORD] = SYSTEM_STRESS_MAGIC;
  box[SYSTEM_STRESS_DONE_WORD] = SYSTEM_STRESS_DONE;

  wasp1_idle_forever();
}
