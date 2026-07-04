#include "wasp1.h"

/*
 * Fixed D-SRAM mailboxes observed by the top-level simulation. They avoid
 * symbol lookup in SystemVerilog while still exercising real cached stores.
 */
#define TIMER_IRQ_MAGIC_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003100))
#define TIMER_IRQ_MCAUSE_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003104))
#define TIMER_IRQ_MEPC_ADDR    (WASP1_DSRAM_BASE + UINT32_C(0x00003108))
#define TIMER_IRQ_DONE_ADDR    (WASP1_DSRAM_BASE + UINT32_C(0x0000310c))

#define TIMER_IRQ_MAGIC        UINT32_C(0x54494d52)
#define TIMER_IRQ_DONE         UINT32_C(0x49525121)

static volatile uint32_t *const timer_irq_magic =
  (volatile uint32_t *)TIMER_IRQ_MAGIC_ADDR;
static volatile uint32_t *const timer_irq_mcause =
  (volatile uint32_t *)TIMER_IRQ_MCAUSE_ADDR;
static volatile uint32_t *const timer_irq_mepc =
  (volatile uint32_t *)TIMER_IRQ_MEPC_ADDR;
static volatile uint32_t *const timer_irq_done =
  (volatile uint32_t *)TIMER_IRQ_DONE_ADDR;

void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  (void)mtval;

  if (mcause == WASP1_MCAUSE_MACHINE_TIMER) {
    /*
     * Move compare far away and gate the peripheral IRQ before returning.
     * Otherwise mret would immediately re-enter the same timer interrupt.
     */
    wasp1_timer_set_cmp(UINT32_C(0xfffffff0), UINT32_C(0xffffffff));
    wasp1_timer_disable();
    wasp1_csr_clear_mie(WASP1_MIE_MTIE);

    *timer_irq_mcause = mcause;
    *timer_irq_mepc = mepc;
    *timer_irq_magic = TIMER_IRQ_MAGIC;
    return;
  }

  *timer_irq_mcause = mcause;
  *timer_irq_mepc = mepc;
  *timer_irq_magic = UINT32_C(0xbad00bad);
  wasp1_idle_forever();
}

int main(void)
{
  *timer_irq_magic = 0u;
  *timer_irq_mcause = 0u;
  *timer_irq_mepc = 0u;
  *timer_irq_done = 0u;

  wasp1_timer_disable();
  wasp1_timer_set_mtime(0u, 0u);
  wasp1_timer_set_cmp(8u, 0u);

  wasp1_csr_set_mie(WASP1_MIE_MTIE);
  wasp1_timer_enable(1u);
  wasp1_csr_set_mstatus(WASP1_MSTATUS_MIE);

  while (*timer_irq_magic != TIMER_IRQ_MAGIC) {
    __asm__ volatile ("nop");
  }

  *timer_irq_done = TIMER_IRQ_DONE;
  wasp1_idle_forever();
}
