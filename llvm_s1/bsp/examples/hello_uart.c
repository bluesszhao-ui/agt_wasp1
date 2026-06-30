#include "wasp1.h"

int main(void)
{
  /* Divisor value is board/simulation policy; this proves the UART MMIO path. */
  wasp1_uart_init(16u);
  wasp1_uart_puts("wasp1 hello from OTP\n");
  for (;;) {
  }
}
