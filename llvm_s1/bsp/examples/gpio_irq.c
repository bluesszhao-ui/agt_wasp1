#include "wasp1.h"

/*
 * GPIO external-interrupt firmware smoke. The testbench waits for READY, drives
 * gpio_in[0] high, then checks the handler's D-SRAM mailboxes.
 */
#define GPIO_IRQ_PIN_MASK     UINT32_C(0x00000001)

#define GPIO_IRQ_READY_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003400))
#define GPIO_IRQ_MAGIC_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003404))
#define GPIO_IRQ_MCAUSE_ADDR  (WASP1_DSRAM_BASE + UINT32_C(0x00003408))
#define GPIO_IRQ_CLAIM_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x0000340c))
#define GPIO_IRQ_LEVEL_ADDR   (WASP1_DSRAM_BASE + UINT32_C(0x00003410))
#define GPIO_IRQ_DONE_ADDR    (WASP1_DSRAM_BASE + UINT32_C(0x00003414))

#define GPIO_IRQ_READY        UINT32_C(0x47504459)
#define GPIO_IRQ_MAGIC        UINT32_C(0x47504951)
#define GPIO_IRQ_DONE         UINT32_C(0x47504f4b)

static volatile uint32_t *const gpio_irq_ready =
  (volatile uint32_t *)GPIO_IRQ_READY_ADDR;
static volatile uint32_t *const gpio_irq_magic =
  (volatile uint32_t *)GPIO_IRQ_MAGIC_ADDR;
static volatile uint32_t *const gpio_irq_mcause =
  (volatile uint32_t *)GPIO_IRQ_MCAUSE_ADDR;
static volatile uint32_t *const gpio_irq_claim =
  (volatile uint32_t *)GPIO_IRQ_CLAIM_ADDR;
static volatile uint32_t *const gpio_irq_level =
  (volatile uint32_t *)GPIO_IRQ_LEVEL_ADDR;
static volatile uint32_t *const gpio_irq_done =
  (volatile uint32_t *)GPIO_IRQ_DONE_ADDR;

void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  (void)mepc;
  (void)mtval;

  if (mcause == WASP1_MCAUSE_MACHINE_EXTERNAL) {
    uint32_t claim = wasp1_intc_claim();
    *gpio_irq_mcause = mcause;
    *gpio_irq_claim = claim;

    if (claim == WASP1_IRQ_GPIO) {
      /*
       * The source is level-sensitive. Mask it before clearing sticky status so
       * a still-high pin cannot immediately repend after completion.
       */
      wasp1_gpio_irq_disable(GPIO_IRQ_PIN_MASK);
      wasp1_gpio_irq_clear(GPIO_IRQ_PIN_MASK);
      wasp1_intc_complete(claim);
      wasp1_intc_clear_pending(claim);
      wasp1_intc_disable(claim);
      wasp1_csr_clear_mie(WASP1_MIE_MEIE);
      *gpio_irq_level = wasp1_gpio_read();
      *gpio_irq_magic = GPIO_IRQ_MAGIC;
      return;
    }
  }

  *gpio_irq_mcause = mcause;
  *gpio_irq_magic = UINT32_C(0xbad00bad);
  wasp1_idle_forever();
}

int main(void)
{
  *gpio_irq_ready = 0u;
  *gpio_irq_magic = 0u;
  *gpio_irq_mcause = 0u;
  *gpio_irq_claim = 0u;
  *gpio_irq_level = 0u;
  *gpio_irq_done = 0u;

  wasp1_gpio_set_dir(0u);
  wasp1_gpio_irq_config(GPIO_IRQ_PIN_MASK, 0u, GPIO_IRQ_PIN_MASK);
  wasp1_intc_set_threshold(0u);
  wasp1_intc_set_priority(WASP1_IRQ_GPIO, 2u);
  wasp1_intc_clear_pending(WASP1_IRQ_GPIO);
  wasp1_intc_enable(WASP1_IRQ_GPIO);

  wasp1_csr_set_mie(WASP1_MIE_MEIE);
  wasp1_csr_set_mstatus(WASP1_MSTATUS_MIE);

  *gpio_irq_ready = GPIO_IRQ_READY;

  while (*gpio_irq_magic != GPIO_IRQ_MAGIC) {
    __asm__ volatile ("nop");
  }

  *gpio_irq_done = GPIO_IRQ_DONE;
  wasp1_idle_forever();
}
