#include "wasp1.h"

/*
 * UART external-interrupt firmware smoke. TX-empty is self-generating once the
 * UART is enabled with an empty TX FIFO, so the top-level testbench only needs
 * to inspect D-SRAM mailboxes after the C trap handler runs.
 */
#define UART_IRQ_MAGIC_ADDR    (WASP1_DSRAM_BASE + UINT32_C(0x00003500))
#define UART_IRQ_MCAUSE_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003504))
#define UART_IRQ_CLAIM_ADDR    (WASP1_DSRAM_BASE + UINT32_C(0x00003508))
#define UART_IRQ_STATUS_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x0000350c))
#define UART_IRQ_DONE_ADDR     (WASP1_DSRAM_BASE + UINT32_C(0x00003510))

#define UART_IRQ_MAGIC         UINT32_C(0x55524951)
#define UART_IRQ_DONE          UINT32_C(0x55524f4b)

static volatile uint32_t *const uart_irq_magic =
  (volatile uint32_t *)UART_IRQ_MAGIC_ADDR;
static volatile uint32_t *const uart_irq_mcause =
  (volatile uint32_t *)UART_IRQ_MCAUSE_ADDR;
static volatile uint32_t *const uart_irq_claim =
  (volatile uint32_t *)UART_IRQ_CLAIM_ADDR;
static volatile uint32_t *const uart_irq_status =
  (volatile uint32_t *)UART_IRQ_STATUS_ADDR;
static volatile uint32_t *const uart_irq_done =
  (volatile uint32_t *)UART_IRQ_DONE_ADDR;

void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  (void)mepc;
  (void)mtval;

  if (mcause == WASP1_MCAUSE_MACHINE_EXTERNAL) {
    uint32_t claim = wasp1_intc_claim();
    *uart_irq_mcause = mcause;
    *uart_irq_claim = claim;

    if (claim == WASP1_IRQ_UART) {
      uint32_t status = wasp1_uart_irq_status();

      /*
       * TX-empty remains true while the FIFO is empty. Mask the UART source
       * before clearing sticky status so INTC cannot immediately repend.
       */
      wasp1_uart_irq_disable(WASP1_UART_CTRL_TX_IRQ_EN);
      wasp1_uart_irq_clear(WASP1_UART_IRQ_TX_EMPTY);
      wasp1_intc_complete(claim);
      wasp1_intc_clear_pending(claim);
      wasp1_intc_disable(claim);
      wasp1_csr_clear_mie(WASP1_MIE_MEIE);
      *uart_irq_status = status;
      *uart_irq_magic = UART_IRQ_MAGIC;
      return;
    }
  }

  *uart_irq_mcause = mcause;
  *uart_irq_claim = UINT32_C(0xbad00bad);
  *uart_irq_magic = UINT32_C(0xbad00bad);
  wasp1_idle_forever();
}

int main(void)
{
  *uart_irq_magic = 0u;
  *uart_irq_mcause = 0u;
  *uart_irq_claim = 0u;
  *uart_irq_status = 0u;
  *uart_irq_done = 0u;

  wasp1_uart_irq_config(4u, WASP1_UART_CTRL_TX_IRQ_EN);
  wasp1_intc_set_threshold(0u);
  wasp1_intc_set_priority(WASP1_IRQ_UART, 2u);
  wasp1_intc_clear_pending(WASP1_IRQ_UART);
  wasp1_intc_enable(WASP1_IRQ_UART);

  wasp1_csr_set_mie(WASP1_MIE_MEIE);
  wasp1_csr_set_mstatus(WASP1_MSTATUS_MIE);

  while (*uart_irq_magic != UART_IRQ_MAGIC) {
    __asm__ volatile ("nop");
  }

  *uart_irq_done = UART_IRQ_DONE;
  wasp1_idle_forever();
}
