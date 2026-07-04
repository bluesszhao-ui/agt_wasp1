#ifndef WASP1_DMA_H
#define WASP1_DMA_H

/* Single-channel DMA helper for word-copy transfers. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* DMA register offsets follow dma/rtl/ahb_dma.sv. */
#define WASP1_DMA_SRC         UINT32_C(0x00)
#define WASP1_DMA_DST         UINT32_C(0x04)
#define WASP1_DMA_LEN         UINT32_C(0x08)
#define WASP1_DMA_CTRL        UINT32_C(0x0c)
#define WASP1_DMA_STATUS      UINT32_C(0x10)

#define WASP1_DMA_CTRL_START  (UINT32_C(1) << 0)
#define WASP1_DMA_CTRL_IRQ_EN (UINT32_C(1) << 1)
#define WASP1_DMA_CTRL_CLEAR  (UINT32_C(1) << 2)

#define WASP1_DMA_STATUS_BUSY  (UINT32_C(1) << 0)
#define WASP1_DMA_STATUS_DONE  (UINT32_C(1) << 1)
#define WASP1_DMA_STATUS_ERROR (UINT32_C(1) << 2)

static inline void wasp1_dma_start(uint32_t src, uint32_t dst, uint32_t len_words, uint32_t irq_en)
{
  /* CLEAR drops stale done/error before START launches the next word transfer. */
  uint32_t ctrl = WASP1_DMA_CTRL_START | WASP1_DMA_CTRL_CLEAR;
  if (irq_en != 0u) {
    ctrl |= WASP1_DMA_CTRL_IRQ_EN;
  }
  wasp1_write32(WASP1_DMA_BASE + WASP1_DMA_SRC, src);
  wasp1_write32(WASP1_DMA_BASE + WASP1_DMA_DST, dst);
  wasp1_write32(WASP1_DMA_BASE + WASP1_DMA_LEN, len_words);
  wasp1_write32(WASP1_DMA_BASE + WASP1_DMA_CTRL, ctrl);
}

static inline void wasp1_dma_clear_done_error(void)
{
  /* Clear sticky done/error and drop IRQ enable unless a later start sets it. */
  wasp1_write32(WASP1_DMA_BASE + WASP1_DMA_CTRL, WASP1_DMA_CTRL_CLEAR);
}

#endif
