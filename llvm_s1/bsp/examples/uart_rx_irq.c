#include "wasp1.h"

/*
 * UART RX interrupt firmware smoke. The testbench drives uart_rx_i only after
 * firmware writes ready mailboxes, so both RX-available and RX-overrun sources
 * are checked as real external serial input rather than a TX loopback shortcut.
 */
#define UART_RX_IRQ_BASE_ADDR      (WASP1_DSRAM_BASE + UINT32_C(0x00003800))

#define UART_RX_IRQ_READY          UINT32_C(0x55525244)
#define UART_RX_IRQ_RX_MAGIC       UINT32_C(0x55525841)
#define UART_RX_IRQ_OVR_READY      UINT32_C(0x55524f52)
#define UART_RX_IRQ_OVR_MAGIC      UINT32_C(0x55524f56)
#define UART_RX_IRQ_DONE           UINT32_C(0x55524f4b)

#define UART_RX_IRQ_RX_DATA        UINT32_C(0x0000005a)
#define UART_RX_IRQ_RX_STATUS      WASP1_UART_IRQ_RX_AVAIL
#define UART_RX_IRQ_OVR_STATUS     WASP1_UART_IRQ_RX_OVERRUN

enum {
  UART_RX_IRQ_READY_WORD = 0,
  UART_RX_IRQ_MAGIC_WORD = 1,
  UART_RX_IRQ_MCAUSE_WORD = 2,
  UART_RX_IRQ_CLAIM_WORD = 3,
  UART_RX_IRQ_STATUS_WORD = 4,
  UART_RX_IRQ_DATA_WORD = 5,
  UART_RX_IRQ_OVR_READY_WORD = 6,
  UART_RX_IRQ_OVR_MAGIC_WORD = 7,
  UART_RX_IRQ_OVR_STATUS_WORD = 8,
  UART_RX_IRQ_OVR_UART_STATUS_WORD = 9,
  UART_RX_IRQ_DONE_WORD = 10
};

static volatile uint32_t *const uart_rx_irq_box =
  (volatile uint32_t *)UART_RX_IRQ_BASE_ADDR;

static volatile uint32_t uart_rx_irq_phase;

static void uart_rx_irq_bad(uint32_t mcause, uint32_t claim)
{
  uart_rx_irq_box[UART_RX_IRQ_MCAUSE_WORD] = mcause;
  uart_rx_irq_box[UART_RX_IRQ_CLAIM_WORD] = claim;
  uart_rx_irq_box[UART_RX_IRQ_MAGIC_WORD] = UINT32_C(0xbad00bad);
  wasp1_idle_forever();
}

void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  uint32_t claim;
  uint32_t irq_status;
  uint32_t uart_status;

  (void)mepc;
  (void)mtval;

  if (mcause != WASP1_MCAUSE_MACHINE_EXTERNAL) {
    uart_rx_irq_bad(mcause, UINT32_C(0xbad00bad));
  }

  claim = wasp1_intc_claim();
  uart_rx_irq_box[UART_RX_IRQ_MCAUSE_WORD] = mcause;
  uart_rx_irq_box[UART_RX_IRQ_CLAIM_WORD] = claim;
  if (claim != WASP1_IRQ_UART) {
    uart_rx_irq_bad(mcause, claim);
  }

  irq_status = wasp1_uart_irq_status();
  uart_status = wasp1_uart_status();

  if (uart_rx_irq_phase == 0u) {
    /*
     * RX-available should be the only enabled UART IRQ source in phase 0.
     * Reading DATA drains the byte so phase 1 can fill the FIFO from empty.
     */
    uart_rx_irq_box[UART_RX_IRQ_STATUS_WORD] = irq_status;
    uart_rx_irq_box[UART_RX_IRQ_DATA_WORD] = wasp1_uart_getc_raw();
    wasp1_uart_irq_disable(WASP1_UART_CTRL_RX_IRQ_EN);
    wasp1_uart_irq_clear(WASP1_UART_IRQ_RX_AVAIL);
    wasp1_intc_complete(claim);
    wasp1_intc_clear_pending(claim);
    uart_rx_irq_phase = 1u;
    uart_rx_irq_box[UART_RX_IRQ_MAGIC_WORD] = UART_RX_IRQ_RX_MAGIC;
    return;
  }

  /*
   * Phase 1 leaves RX-available masked and enables only overrun. The testbench
   * sends enough external serial frames to drive the sticky overrun path.
   */
  uart_rx_irq_box[UART_RX_IRQ_OVR_STATUS_WORD] = irq_status;
  uart_rx_irq_box[UART_RX_IRQ_OVR_UART_STATUS_WORD] = uart_status;
  wasp1_uart_irq_disable(WASP1_UART_CTRL_OVR_IRQ_EN);
  wasp1_uart_irq_clear(WASP1_UART_IRQ_RX_OVERRUN | WASP1_UART_IRQ_RX_AVAIL);
  wasp1_intc_complete(claim);
  wasp1_intc_clear_pending(claim);
  wasp1_intc_disable(claim);
  wasp1_csr_clear_mie(WASP1_MIE_MEIE);
  uart_rx_irq_box[UART_RX_IRQ_OVR_MAGIC_WORD] = UART_RX_IRQ_OVR_MAGIC;
}

int main(void)
{
  for (uint32_t idx = 0u; idx <= UART_RX_IRQ_DONE_WORD; ++idx) {
    uart_rx_irq_box[idx] = 0u;
  }
  uart_rx_irq_phase = 0u;

  wasp1_uart_irq_config(4u, WASP1_UART_CTRL_RX_IRQ_EN);
  wasp1_intc_set_threshold(0u);
  wasp1_intc_set_priority(WASP1_IRQ_UART, 2u);
  wasp1_intc_clear_pending(WASP1_IRQ_UART);
  wasp1_intc_enable(WASP1_IRQ_UART);
  wasp1_csr_set_mie(WASP1_MIE_MEIE);
  wasp1_csr_set_mstatus(WASP1_MSTATUS_MIE);

  uart_rx_irq_box[UART_RX_IRQ_READY_WORD] = UART_RX_IRQ_READY;
  while (uart_rx_irq_box[UART_RX_IRQ_MAGIC_WORD] != UART_RX_IRQ_RX_MAGIC) {
    __asm__ volatile ("nop");
  }

  wasp1_uart_irq_clear(WASP1_UART_IRQ_RX_AVAIL | WASP1_UART_IRQ_RX_OVERRUN);
  wasp1_uart_irq_enable(WASP1_UART_CTRL_OVR_IRQ_EN);
  uart_rx_irq_box[UART_RX_IRQ_OVR_READY_WORD] = UART_RX_IRQ_OVR_READY;
  while (uart_rx_irq_box[UART_RX_IRQ_OVR_MAGIC_WORD] != UART_RX_IRQ_OVR_MAGIC) {
    __asm__ volatile ("nop");
  }

  uart_rx_irq_box[UART_RX_IRQ_DONE_WORD] = UART_RX_IRQ_DONE;
  wasp1_idle_forever();
}
