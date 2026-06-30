#include "wasp1.h"

int main(void)
{
  /* Drive GPIO[0] as an output and toggle it with a simple software delay. */
  wasp1_gpio_set_dir(1u);
  for (;;) {
    wasp1_gpio_set(1u);
    for (volatile unsigned i = 0; i < 1000u; ++i) {
    }
    wasp1_gpio_clear(1u);
    for (volatile unsigned i = 0; i < 1000u; ++i) {
    }
  }
}
