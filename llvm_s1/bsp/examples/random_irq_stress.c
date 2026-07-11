#include "wasp1.h"

/*
 * Fixed-seed interrupt-heavy system regression. The pseudo-random selector is
 * deterministic so a failing interrupt interleaving can be reproduced exactly
 * in RTL simulation and later on FPGA hardware.
 */
#define RANDOM_IRQ_BOX_ADDR      (WASP1_DSRAM_BASE + UINT32_C(0x00003b00))
#define RANDOM_IRQ_DMA_SRC_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003d00))
#define RANDOM_IRQ_DMA_DST_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003d80))

#define RANDOM_IRQ_SEED          UINT32_C(0x1a2b3c4d)
#define RANDOM_IRQ_ROUNDS        UINT32_C(12)
#define RANDOM_IRQ_DMA_WORDS     UINT32_C(4)
#define RANDOM_IRQ_GPIO_MASK     UINT32_C(0x00000001)
#define RANDOM_IRQ_MAGIC         UINT32_C(0x52495251)
#define RANDOM_IRQ_DONE          UINT32_C(0x52494f4b)

#define RANDOM_IRQ_EVENT_TIMER   UINT32_C(0x00000100)
#define RANDOM_IRQ_EVENT_DMA     UINT32_C(0x00000200)
#define RANDOM_IRQ_EVENT_GPIO    UINT32_C(0x00000400)

#define RANDOM_IRQ_FAIL_BAD_TRAP UINT32_C(1)
#define RANDOM_IRQ_FAIL_BAD_CLAIM UINT32_C(2)
#define RANDOM_IRQ_FAIL_DMA      UINT32_C(3)
#define RANDOM_IRQ_FAIL_TIMEOUT  UINT32_C(4)
#define RANDOM_IRQ_FAIL_DATA     UINT32_C(5)

enum {
  RANDOM_IRQ_MAGIC_WORD = 0,
  RANDOM_IRQ_DONE_WORD = 1,
  RANDOM_IRQ_STATE_WORD = 2,
  RANDOM_IRQ_ROUNDS_WORD = 3,
  RANDOM_IRQ_TOTAL_WORD = 4,
  RANDOM_IRQ_TIMER_WORD = 5,
  RANDOM_IRQ_DMA_WORD = 6,
  RANDOM_IRQ_GPIO_WORD = 7,
  RANDOM_IRQ_EVENT_SUM_WORD = 8,
  RANDOM_IRQ_DATA_SUM_WORD = 9,
  RANDOM_IRQ_GPIO_REQ_WORD = 10,
  RANDOM_IRQ_GPIO_ACK_WORD = 11,
  RANDOM_IRQ_LAST_MCAUSE_WORD = 12,
  RANDOM_IRQ_LAST_CLAIM_WORD = 13,
  RANDOM_IRQ_FAIL_WORD = 14,
  RANDOM_IRQ_UART_COUNT_WORD = 15,
  RANDOM_IRQ_TRACE_WORD = 16,
  RANDOM_IRQ_BOX_WORDS = 17
};

static volatile uint32_t *const random_irq_box =
  (volatile uint32_t *)RANDOM_IRQ_BOX_ADDR;

/* Shared main/handler state. Volatile prevents polling from being optimized. */
static volatile uint32_t random_irq_round;
static volatile uint32_t random_irq_total;
static volatile uint32_t random_irq_timer_count;
static volatile uint32_t random_irq_dma_count;
static volatile uint32_t random_irq_gpio_count;
static volatile uint32_t random_irq_event_sum;
static volatile uint32_t random_irq_failure;
static volatile uint32_t random_irq_sink;

static uint32_t random_irq_xorshift32(uint32_t value)
{
  /* xorshift32 needs only RV32I shifts and XOR operations. */
  value ^= value << 13;
  value ^= value >> 17;
  value ^= value << 5;
  return value;
}

static uint32_t random_irq_pattern(uint32_t round, uint32_t idx,
                                   uint32_t state)
{
  /* Encode round/index plus PRNG state without requiring the M extension. */
  return UINT32_C(0x62000000) |
         ((round & UINT32_C(0x0f)) << 16) |
         ((idx & UINT32_C(0x0f)) << 8) |
         (state & UINT32_C(0xff));
}

static void random_irq_record(uint32_t event_tag)
{
  /* Addition makes the final signature independent of interrupt service order. */
  ++random_irq_total;
  random_irq_event_sum += event_tag + random_irq_round;
}

void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  uint32_t claim;
  uint32_t dma_status;

  (void)mepc;
  (void)mtval;
  random_irq_box[RANDOM_IRQ_LAST_MCAUSE_WORD] = mcause;

  if (mcause == WASP1_MCAUSE_MACHINE_TIMER) {
    /* Disabling CTRL deasserts the level-sensitive machine timer source. */
    wasp1_timer_disable();
    ++random_irq_timer_count;
    random_irq_record(RANDOM_IRQ_EVENT_TIMER);
    return;
  }

  if (mcause != WASP1_MCAUSE_MACHINE_EXTERNAL) {
    random_irq_failure = RANDOM_IRQ_FAIL_BAD_TRAP;
    return;
  }

  claim = wasp1_intc_claim();
  random_irq_box[RANDOM_IRQ_LAST_CLAIM_WORD] = claim;
  if (claim == WASP1_IRQ_DMA) {
    /* Clear the peripheral source before completing the INTC claim. */
    dma_status = wasp1_read32(WASP1_DMA_BASE + WASP1_DMA_STATUS);
    if ((dma_status & WASP1_DMA_STATUS_ERROR) != 0u) {
      random_irq_failure = RANDOM_IRQ_FAIL_DMA;
    }
    wasp1_dma_clear_done_error();
    wasp1_intc_complete(claim);
    wasp1_intc_clear_pending(claim);
    ++random_irq_dma_count;
    random_irq_record(RANDOM_IRQ_EVENT_DMA);
    return;
  }

  if (claim == WASP1_IRQ_GPIO) {
    /* Mask the level source before completion so a high pin cannot repend. */
    wasp1_gpio_irq_disable(RANDOM_IRQ_GPIO_MASK);
    wasp1_gpio_irq_clear(RANDOM_IRQ_GPIO_MASK);
    wasp1_intc_complete(claim);
    wasp1_intc_clear_pending(claim);
    ++random_irq_gpio_count;
    random_irq_box[RANDOM_IRQ_GPIO_ACK_WORD] =
      random_irq_box[RANDOM_IRQ_GPIO_REQ_WORD];
    random_irq_record(RANDOM_IRQ_EVENT_GPIO);
    return;
  }

  random_irq_failure = RANDOM_IRQ_FAIL_BAD_CLAIM;
}

static void random_irq_prepare_dma(uint32_t round, uint32_t state)
{
  volatile uint32_t *src = (volatile uint32_t *)RANDOM_IRQ_DMA_SRC_ADDR;
  volatile uint32_t *dst = (volatile uint32_t *)RANDOM_IRQ_DMA_DST_ADDR;
  uint32_t folded = 0u;

  for (uint32_t idx = 0u; idx < RANDOM_IRQ_DMA_WORDS; ++idx) {
    src[idx] = random_irq_pattern(round, idx, state);
    dst[idx] = UINT32_C(0xdeadc000) | (round << 4) | idx;
  }

  /* CPU readback orders source stores before the second AHB master starts. */
  for (uint32_t idx = 0u; idx < RANDOM_IRQ_DMA_WORDS; ++idx) {
    folded ^= src[idx];
  }
  random_irq_sink = folded;
}

static void random_irq_arm_timer(uint32_t state, uint32_t concurrent)
{
  uint32_t delay = UINT32_C(10) + (state & UINT32_C(0x7));

  /* Concurrent rounds use a wider window while DMA is also in flight. */
  if (concurrent != 0u) {
    delay += UINT32_C(64);
  }
  wasp1_timer_disable();
  wasp1_timer_set_mtime(0u, 0u);
  wasp1_timer_set_cmp(delay, 0u);
  wasp1_timer_enable(1u);
}

static void random_irq_wait_for(uint32_t expected_total)
{
  uint32_t timeout = 0u;

  while ((random_irq_total != expected_total) &&
         (random_irq_failure == 0u) &&
         (timeout < UINT32_C(100000))) {
    ++timeout;
    __asm__ volatile ("nop");
  }
  if ((random_irq_total != expected_total) && (random_irq_failure == 0u)) {
    random_irq_failure = RANDOM_IRQ_FAIL_TIMEOUT;
  }
}

static uint32_t random_irq_check_dma(uint32_t round, uint32_t state)
{
  volatile uint32_t *dst = (volatile uint32_t *)RANDOM_IRQ_DMA_DST_ADDR;
  uint32_t sum = 0u;

  for (uint32_t idx = 0u; idx < RANDOM_IRQ_DMA_WORDS; ++idx) {
    uint32_t expected = random_irq_pattern(round, idx, state);
    if (dst[idx] != expected) {
      random_irq_failure = RANDOM_IRQ_FAIL_DATA;
    }
    sum += dst[idx] ^ (round << idx);
  }
  return sum;
}

int main(void)
{
  uint32_t state = RANDOM_IRQ_SEED;
  uint32_t trace = 0u;
  uint32_t data_sum = 0u;
  uint32_t uart_count = 0u;

  for (uint32_t idx = 0u; idx < RANDOM_IRQ_BOX_WORDS; ++idx) {
    random_irq_box[idx] = 0u;
  }
  random_irq_round = 0u;
  random_irq_total = 0u;
  random_irq_timer_count = 0u;
  random_irq_dma_count = 0u;
  random_irq_gpio_count = 0u;
  random_irq_event_sum = 0u;
  random_irq_failure = 0u;

  wasp1_uart_init(4u);
  wasp1_uart_putc('R');
  ++uart_count;

  wasp1_gpio_set_dir(0u);
  wasp1_intc_set_threshold(0u);
  wasp1_intc_set_priority(WASP1_IRQ_DMA, 3u);
  wasp1_intc_set_priority(WASP1_IRQ_GPIO, 2u);
  wasp1_intc_clear_pending(WASP1_IRQ_DMA);
  wasp1_intc_clear_pending(WASP1_IRQ_GPIO);
  wasp1_intc_enable(WASP1_IRQ_DMA);
  wasp1_intc_enable(WASP1_IRQ_GPIO);
  wasp1_csr_set_mie(WASP1_MIE_MTIE | WASP1_MIE_MEIE);
  wasp1_csr_set_mstatus(WASP1_MSTATUS_MIE);

  for (uint32_t round = 0u; round < RANDOM_IRQ_ROUNDS; ++round) {
    uint32_t selector;
    uint32_t expected_total;

    state = random_irq_xorshift32(state);
    selector = state & UINT32_C(0x3);
    trace |= selector << (round << 1);
    random_irq_round = round;
    expected_total = random_irq_total;

    if (selector == 0u) {
      random_irq_arm_timer(state, 0u);
      ++expected_total;
    } else if (selector == 1u) {
      random_irq_prepare_dma(round, state);
      wasp1_dma_start(RANDOM_IRQ_DMA_SRC_ADDR, RANDOM_IRQ_DMA_DST_ADDR,
                      RANDOM_IRQ_DMA_WORDS, 1u);
      ++expected_total;
    } else if (selector == 2u) {
      wasp1_gpio_irq_config(RANDOM_IRQ_GPIO_MASK, 0u,
                            RANDOM_IRQ_GPIO_MASK);
      ++random_irq_box[RANDOM_IRQ_GPIO_REQ_WORD];
      ++expected_total;
    } else {
      random_irq_prepare_dma(round, state);
      random_irq_arm_timer(state, 1u);
      wasp1_dma_start(RANDOM_IRQ_DMA_SRC_ADDR, RANDOM_IRQ_DMA_DST_ADDR,
                      RANDOM_IRQ_DMA_WORDS, 1u);
      expected_total += UINT32_C(2);
    }

    random_irq_wait_for(expected_total);
    if ((selector == 1u) || (selector == 3u)) {
      data_sum += random_irq_check_dma(round, state);
    }
    wasp1_uart_putc((char)('a' + (char)round));
    ++uart_count;
    if (random_irq_failure != 0u) {
      break;
    }
  }

  wasp1_timer_disable();
  wasp1_gpio_irq_disable(RANDOM_IRQ_GPIO_MASK);
  wasp1_intc_disable(WASP1_IRQ_DMA);
  wasp1_intc_disable(WASP1_IRQ_GPIO);
  wasp1_csr_clear_mie(WASP1_MIE_MTIE | WASP1_MIE_MEIE);

  random_irq_box[RANDOM_IRQ_STATE_WORD] = state;
  random_irq_box[RANDOM_IRQ_ROUNDS_WORD] = RANDOM_IRQ_ROUNDS;
  random_irq_box[RANDOM_IRQ_TOTAL_WORD] = random_irq_total;
  random_irq_box[RANDOM_IRQ_TIMER_WORD] = random_irq_timer_count;
  random_irq_box[RANDOM_IRQ_DMA_WORD] = random_irq_dma_count;
  random_irq_box[RANDOM_IRQ_GPIO_WORD] = random_irq_gpio_count;
  random_irq_box[RANDOM_IRQ_EVENT_SUM_WORD] = random_irq_event_sum;
  random_irq_box[RANDOM_IRQ_DATA_SUM_WORD] = data_sum;
  random_irq_box[RANDOM_IRQ_FAIL_WORD] = random_irq_failure;
  random_irq_box[RANDOM_IRQ_UART_COUNT_WORD] = uart_count;
  random_irq_box[RANDOM_IRQ_TRACE_WORD] = trace;
  random_irq_box[RANDOM_IRQ_MAGIC_WORD] = RANDOM_IRQ_MAGIC;
  random_irq_box[RANDOM_IRQ_DONE_WORD] = RANDOM_IRQ_DONE;

  wasp1_idle_forever();
}
