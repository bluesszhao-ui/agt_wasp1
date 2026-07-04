#include "wasp1.h"

#define OTP_PROGRAM_TEST_WORD_ADDR UINT32_C(0x00003fa0)
#define OTP_PROGRAM_TEST_DATA      UINT32_C(0x13572468)
#define OTP_PROGRAM_TIMEOUT        UINT32_C(1024)

__attribute__((section(".fasttext")))
static uint32_t program_test_word_from_isram(void)
{
  uint32_t status;
  uint32_t timeout;

  /* This routine must run from I-SRAM while it changes the OTP data array. */
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_KEY), WASP1_OTP_KEY_VALUE);
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_ADDR), OTP_PROGRAM_TEST_WORD_ADDR);
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_WDATA), OTP_PROGRAM_TEST_DATA);
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_CTRL),
                WASP1_OTP_CTRL_PROG_EN | WASP1_OTP_CTRL_START);

  timeout = OTP_PROGRAM_TIMEOUT;
  do {
    status = wasp1_read32(wasp1_otp_reg(WASP1_OTP_STATUS));
    if ((status & (WASP1_OTP_STATUS_DONE | WASP1_OTP_STATUS_ERROR)) != 0u) {
      break;
    }
    timeout--;
  } while (timeout != 0u);

  return status;
}

int main(void)
{
  volatile uint32_t status;

  status = program_test_word_from_isram();

  wasp1_uart_init(16u);
  if ((status & WASP1_OTP_STATUS_DONE) != 0u &&
      (status & WASP1_OTP_STATUS_ERROR) == 0u) {
    wasp1_uart_puts("otp program pass\n");
  } else {
    wasp1_uart_puts("otp program fail\n");
  }

  for (;;) {
  }
}
