#include "wasp1.h"

/*
 * DMA external-interrupt firmware smoke. The top-level testbench observes
 * these fixed D-SRAM mailboxes after the handler claims and completes IRQ 5.
 */
#define DMA_IRQ_SRC_ADDR      UINT32_C(0x20003200)
#define DMA_IRQ_DST_ADDR      UINT32_C(0x20003240)
#define DMA_IRQ_WORDS         UINT32_C(4)

#define DMA_IRQ_MAGIC_ADDR    (WASP1_DSRAM_BASE + UINT32_C(0x00003300))
#define DMA_IRQ_MCAUSE_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003304))
#define DMA_IRQ_CLAIM_ADDR    (WASP1_DSRAM_BASE + UINT32_C(0x00003308))
#define DMA_IRQ_DONE_ADDR     (WASP1_DSRAM_BASE + UINT32_C(0x0000330c))

#define DMA_IRQ_MAGIC         UINT32_C(0x444d4149)
#define DMA_IRQ_DONE          UINT32_C(0x45584954)

static const uint32_t dma_irq_pattern[DMA_IRQ_WORDS] = {
  UINT32_C(0x10203040),
  UINT32_C(0x50607080),
  UINT32_C(0x90a0b0c0),
  UINT32_C(0xd0e0f000)
};

static volatile uint32_t dma_irq_sink;

static volatile uint32_t *const dma_irq_magic =
  (volatile uint32_t *)DMA_IRQ_MAGIC_ADDR;
static volatile uint32_t *const dma_irq_mcause =
  (volatile uint32_t *)DMA_IRQ_MCAUSE_ADDR;
static volatile uint32_t *const dma_irq_claim =
  (volatile uint32_t *)DMA_IRQ_CLAIM_ADDR;
static volatile uint32_t *const dma_irq_done =
  (volatile uint32_t *)DMA_IRQ_DONE_ADDR;

static void prepare_dma_buffers(void)
{
  volatile uint32_t *src = (volatile uint32_t *)DMA_IRQ_SRC_ADDR;
  volatile uint32_t *dst = (volatile uint32_t *)DMA_IRQ_DST_ADDR;

  for (uint32_t idx = 0; idx < DMA_IRQ_WORDS; ++idx) {
    src[idx] = dma_irq_pattern[idx];
    dst[idx] = UINT32_C(0xbeef0000) | idx;
  }
}

static void drain_source_writes(void)
{
  volatile uint32_t *src = (volatile uint32_t *)DMA_IRQ_SRC_ADDR;
  uint32_t folded = 0u;

  for (uint32_t idx = 0; idx < DMA_IRQ_WORDS; ++idx) {
    folded ^= src[idx];
  }
  dma_irq_sink = folded;
}

void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  (void)mepc;
  (void)mtval;

  if (mcause == WASP1_MCAUSE_MACHINE_EXTERNAL) {
    uint32_t claim = wasp1_intc_claim();
    *dma_irq_mcause = mcause;
    *dma_irq_claim = claim;

    if (claim == WASP1_IRQ_DMA) {
      /*
       * The DMA IRQ source is sticky done/error status. Clear the source before
       * completing INTC so MEIP does not immediately repend after mret.
       */
      wasp1_dma_clear_done_error();
      wasp1_intc_complete(claim);
      wasp1_intc_clear_pending(claim);
      wasp1_intc_disable(claim);
      wasp1_csr_clear_mie(WASP1_MIE_MEIE);
      *dma_irq_magic = DMA_IRQ_MAGIC;
      return;
    }
  }

  *dma_irq_mcause = mcause;
  *dma_irq_claim = UINT32_C(0xbad00bad);
  *dma_irq_magic = UINT32_C(0xbad00bad);
  wasp1_idle_forever();
}

int main(void)
{
  *dma_irq_magic = 0u;
  *dma_irq_mcause = 0u;
  *dma_irq_claim = 0u;
  *dma_irq_done = 0u;

  prepare_dma_buffers();
  drain_source_writes();

  wasp1_intc_set_threshold(0u);
  wasp1_intc_set_priority(WASP1_IRQ_DMA, 2u);
  wasp1_intc_clear_pending(WASP1_IRQ_DMA);
  wasp1_intc_enable(WASP1_IRQ_DMA);

  wasp1_csr_set_mie(WASP1_MIE_MEIE);
  wasp1_csr_set_mstatus(WASP1_MSTATUS_MIE);

  wasp1_dma_start(DMA_IRQ_SRC_ADDR, DMA_IRQ_DST_ADDR, DMA_IRQ_WORDS, 1u);

  while (*dma_irq_magic != DMA_IRQ_MAGIC) {
    __asm__ volatile ("nop");
  }

  *dma_irq_done = DMA_IRQ_DONE;
  wasp1_idle_forever();
}
