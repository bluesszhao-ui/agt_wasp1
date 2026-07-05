#include "wasp1.h"

/*
 * Mixed interrupt-and-DMA software regression. One OTP image enables two INTC
 * sources at once: DMA completion and GPIO level-high. DMA has higher priority,
 * while the testbench raises GPIO[0] after firmware advertises readiness. The
 * top-level testbench checks claim order, copied D-SRAM data, and final IRQ
 * deassertion.
 */
#define MIXED_IRQ_GPIO_MASK      UINT32_C(0x00000001)
#define MIXED_IRQ_DMA_SRC_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003a00))
#define MIXED_IRQ_DMA_DST_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003a40))
#define MIXED_IRQ_WORDS          UINT32_C(4)

#define MIXED_IRQ_BOX_ADDR       (WASP1_DSRAM_BASE + UINT32_C(0x00003900))
#define MIXED_IRQ_READY          UINT32_C(0x4d585244)
#define MIXED_IRQ_DMA_MAGIC      UINT32_C(0x4d58444d)
#define MIXED_IRQ_GPIO_MAGIC     UINT32_C(0x4d584750)
#define MIXED_IRQ_DONE           UINT32_C(0x4d584f4b)

enum {
  MIXED_IRQ_READY_WORD = 0,
  MIXED_IRQ_DMA_MAGIC_WORD = 1,
  MIXED_IRQ_GPIO_MAGIC_WORD = 2,
  MIXED_IRQ_CLAIM0_WORD = 3,
  MIXED_IRQ_CLAIM1_WORD = 4,
  MIXED_IRQ_MCAUSE0_WORD = 5,
  MIXED_IRQ_MCAUSE1_WORD = 6,
  MIXED_IRQ_GPIO_LEVEL_WORD = 7,
  MIXED_IRQ_DMA_STATUS_WORD = 8,
  MIXED_IRQ_HANDLED_MASK_WORD = 9,
  MIXED_IRQ_DONE_WORD = 10
};

#define MIXED_IRQ_HANDLED_DMA    UINT32_C(0x00000001)
#define MIXED_IRQ_HANDLED_GPIO   UINT32_C(0x00000002)
#define MIXED_IRQ_HANDLED_ALL    (MIXED_IRQ_HANDLED_DMA | MIXED_IRQ_HANDLED_GPIO)

static const uint32_t mixed_irq_pattern[MIXED_IRQ_WORDS] = {
  UINT32_C(0x0badc0de),
  UINT32_C(0x12345678),
  UINT32_C(0x89abcdef),
  UINT32_C(0xfedcba98)
};

static volatile uint32_t *const mixed_irq_box =
  (volatile uint32_t *)MIXED_IRQ_BOX_ADDR;

static volatile uint32_t mixed_irq_seq;
static volatile uint32_t mixed_irq_handled;
static volatile uint32_t mixed_irq_sink;

static void mixed_irq_record_claim(uint32_t mcause, uint32_t claim)
{
  /*
   * Only two successful claims are expected. Extra claims are still captured in
   * the handled mask by the bad path below through the magic words.
   */
  if (mixed_irq_seq == 0u) {
    mixed_irq_box[MIXED_IRQ_CLAIM0_WORD] = claim;
    mixed_irq_box[MIXED_IRQ_MCAUSE0_WORD] = mcause;
  } else if (mixed_irq_seq == 1u) {
    mixed_irq_box[MIXED_IRQ_CLAIM1_WORD] = claim;
    mixed_irq_box[MIXED_IRQ_MCAUSE1_WORD] = mcause;
  }
  ++mixed_irq_seq;
}

static void mixed_irq_bad(uint32_t mcause, uint32_t claim)
{
  mixed_irq_record_claim(mcause, claim);
  mixed_irq_box[MIXED_IRQ_DMA_MAGIC_WORD] = UINT32_C(0xbad00bad);
  mixed_irq_box[MIXED_IRQ_GPIO_MAGIC_WORD] = UINT32_C(0xbad00bad);
  wasp1_idle_forever();
}

static void mixed_irq_prepare_dma_buffers(void)
{
  volatile uint32_t *src = (volatile uint32_t *)MIXED_IRQ_DMA_SRC_ADDR;
  volatile uint32_t *dst = (volatile uint32_t *)MIXED_IRQ_DMA_DST_ADDR;

  for (uint32_t idx = 0u; idx < MIXED_IRQ_WORDS; ++idx) {
    src[idx] = mixed_irq_pattern[idx];
    dst[idx] = UINT32_C(0xca5e0000) | idx;
  }
}

static void mixed_irq_drain_dma_source(void)
{
  volatile uint32_t *src = (volatile uint32_t *)MIXED_IRQ_DMA_SRC_ADDR;
  uint32_t folded = 0u;

  /*
   * The CPU readback is the same simple ordering point used by the directed
   * DMA examples so the DMA master sees committed D-SRAM source data.
   */
  for (uint32_t idx = 0u; idx < MIXED_IRQ_WORDS; ++idx) {
    folded ^= src[idx];
  }
  mixed_irq_sink = folded;
}

void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  uint32_t claim;

  (void)mepc;
  (void)mtval;

  if (mcause != WASP1_MCAUSE_MACHINE_EXTERNAL) {
    mixed_irq_bad(mcause, UINT32_C(0xbad00bad));
  }

  claim = wasp1_intc_claim();
  mixed_irq_record_claim(mcause, claim);

  if (claim == WASP1_IRQ_DMA) {
    /*
     * DMA done/error is sticky. Record status before clearing it, then complete
     * INTC while leaving GPIO armed for the second claim.
     */
    mixed_irq_box[MIXED_IRQ_DMA_STATUS_WORD] =
      wasp1_read32(WASP1_DMA_BASE + WASP1_DMA_STATUS);
    wasp1_dma_clear_done_error();
    wasp1_intc_complete(claim);
    wasp1_intc_clear_pending(claim);
    mixed_irq_handled |= MIXED_IRQ_HANDLED_DMA;
    mixed_irq_box[MIXED_IRQ_HANDLED_MASK_WORD] = mixed_irq_handled;
    mixed_irq_box[MIXED_IRQ_DMA_MAGIC_WORD] = MIXED_IRQ_DMA_MAGIC;
    return;
  }

  if (claim == WASP1_IRQ_GPIO) {
    /*
     * GPIO is level-sensitive. Mask and clear the source before completing the
     * claim so a still-high pin cannot immediately repend.
     */
    wasp1_gpio_irq_disable(MIXED_IRQ_GPIO_MASK);
    wasp1_gpio_irq_clear(MIXED_IRQ_GPIO_MASK);
    wasp1_intc_complete(claim);
    wasp1_intc_clear_pending(claim);
    wasp1_intc_disable(claim);
    mixed_irq_handled |= MIXED_IRQ_HANDLED_GPIO;
    mixed_irq_box[MIXED_IRQ_GPIO_LEVEL_WORD] = wasp1_gpio_read();
    mixed_irq_box[MIXED_IRQ_HANDLED_MASK_WORD] = mixed_irq_handled;
    mixed_irq_box[MIXED_IRQ_GPIO_MAGIC_WORD] = MIXED_IRQ_GPIO_MAGIC;
    if (mixed_irq_handled == MIXED_IRQ_HANDLED_ALL) {
      wasp1_intc_disable(WASP1_IRQ_DMA);
      wasp1_csr_clear_mie(WASP1_MIE_MEIE);
    }
    return;
  }

  mixed_irq_bad(mcause, claim);
}

int main(void)
{
  for (uint32_t idx = 0u; idx <= MIXED_IRQ_DONE_WORD; ++idx) {
    mixed_irq_box[idx] = 0u;
  }
  mixed_irq_seq = 0u;
  mixed_irq_handled = 0u;

  mixed_irq_prepare_dma_buffers();
  mixed_irq_drain_dma_source();

  wasp1_gpio_set_dir(0u);
  wasp1_gpio_irq_config(MIXED_IRQ_GPIO_MASK, 0u, MIXED_IRQ_GPIO_MASK);

  wasp1_intc_set_threshold(0u);
  wasp1_intc_set_priority(WASP1_IRQ_DMA, 3u);
  wasp1_intc_set_priority(WASP1_IRQ_GPIO, 2u);
  wasp1_intc_clear_pending(WASP1_IRQ_DMA);
  wasp1_intc_clear_pending(WASP1_IRQ_GPIO);
  wasp1_intc_enable(WASP1_IRQ_DMA);
  wasp1_intc_enable(WASP1_IRQ_GPIO);

  wasp1_csr_set_mie(WASP1_MIE_MEIE);
  wasp1_csr_set_mstatus(WASP1_MSTATUS_MIE);

  wasp1_dma_start(MIXED_IRQ_DMA_SRC_ADDR, MIXED_IRQ_DMA_DST_ADDR,
                  MIXED_IRQ_WORDS, 1u);
  mixed_irq_box[MIXED_IRQ_READY_WORD] = MIXED_IRQ_READY;

  while (mixed_irq_handled != MIXED_IRQ_HANDLED_ALL) {
    __asm__ volatile ("nop");
  }

  mixed_irq_box[MIXED_IRQ_DONE_WORD] = MIXED_IRQ_DONE;
  wasp1_idle_forever();
}
