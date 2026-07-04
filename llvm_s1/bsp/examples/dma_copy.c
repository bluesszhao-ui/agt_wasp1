#include "wasp1.h"

#define DMA_COPY_SRC_ADDR UINT32_C(0x20003000)
#define DMA_COPY_DST_ADDR UINT32_C(0x20003040)
#define DMA_COPY_WORDS    UINT32_C(4)

static const uint32_t dma_copy_pattern[DMA_COPY_WORDS] = {
  UINT32_C(0x11223344),
  UINT32_C(0x55667788),
  UINT32_C(0x99aabbcc),
  UINT32_C(0xddeeff00)
};

static volatile uint32_t dma_copy_sink;

static void prepare_dma_buffers(void)
{
  volatile uint32_t *src = (volatile uint32_t *)DMA_COPY_SRC_ADDR;
  volatile uint32_t *dst = (volatile uint32_t *)DMA_COPY_DST_ADDR;

  /* CPU stores seed real D-SRAM contents before the DMA master copies them. */
  for (uint32_t idx = 0; idx < DMA_COPY_WORDS; ++idx) {
    src[idx] = dma_copy_pattern[idx];
    dst[idx] = UINT32_C(0xdead0000) | idx;
  }
}

static void drain_source_writes(void)
{
  volatile uint32_t *src = (volatile uint32_t *)DMA_COPY_SRC_ADDR;
  uint32_t folded = 0u;

  /*
   * Read back the source window before starting DMA. This gives the current
   * core/D-cache path a simple ordering point so the DMA master sees the real
   * D-SRAM contents instead of racing recent CPU stores.
   */
  for (uint32_t idx = 0; idx < DMA_COPY_WORDS; ++idx) {
    folded ^= src[idx];
  }
  dma_copy_sink = folded;
}

__attribute__((noreturn))
static void start_dma_copy_no_poll(void)
{
  volatile uint32_t *dma = (volatile uint32_t *)WASP1_DMA_BASE;

  /*
   * Use direct volatile stores so the START write is not followed by a helper
   * return or MMIO polling while the DMA master is active. The top-level
   * regression checks the copied D-SRAM contents and DMA status directly.
   */
  dma[WASP1_DMA_SRC / 4u] = DMA_COPY_SRC_ADDR;
  dma[WASP1_DMA_DST / 4u] = DMA_COPY_DST_ADDR;
  dma[WASP1_DMA_LEN / 4u] = DMA_COPY_WORDS;
  dma[WASP1_DMA_CTRL / 4u] =
    WASP1_DMA_CTRL_START | WASP1_DMA_CTRL_IRQ_EN | WASP1_DMA_CTRL_CLEAR;

  wasp1_idle_forever();
}

int main(void)
{
  prepare_dma_buffers();
  drain_source_writes();
  start_dma_copy_no_poll();
}
