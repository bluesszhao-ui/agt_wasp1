#include <stddef.h>
#include <stdint.h>
#include "wasp1_runtime.h"
#include "wasp1_uart.h"

/* Default fatal trap hook. Firmware examples may override this weak symbol. */
void __attribute__((weak)) wasp1_trap_handler(uint32_t mcause, uint32_t mepc, uint32_t mtval)
{
  (void)mcause;
  (void)mepc;
  (void)mtval;
  wasp1_idle_forever();
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
  wasp1_idle_forever();
}
