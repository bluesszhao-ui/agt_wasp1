#include <stddef.h>
#include <stdint.h>
#include "wasp1_uart.h"

/* Stage-1 fatal trap hook. Full context save is deferred to runtime work. */
void wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  (void)mcause;
  (void)mepc;
  (void)mtval;
  for (;;) {
  }
}

int puts(const char *text)
{
  /* Route the minimal stdio surface to the polled UART. */
  wasp1_uart_puts(text);
  wasp1_uart_putc('\n');
  return 0;
}

int putchar(int ch)
{
  wasp1_uart_putc((char)ch);
  return ch;
}

void _exit(int status)
{
  /* Bare-metal programs have no host process to return to. */
  (void)status;
  for (;;) {
  }
}
