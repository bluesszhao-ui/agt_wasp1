/*
 * Polling UART front end for the wasp1 I-SRAM OTP programmer.
 *
 * Production use must link this file into I-SRAM and start it through JTAG or a
 * separately protected resident boot path. Executing it from the OTP array
 * while programming that array is forbidden by the architecture contract.
 */
#include <stddef.h>
#include <stdint.h>

#include "wasp1.h"
#include "wasp1_uart_otp_protocol.h"


#ifndef WASP1_UART_OTP_BAUD_DIV
#define WASP1_UART_OTP_BAUD_DIV UINT32_C(868)
#endif


static uint32_t target_read_word(void *context, uint32_t word_address)
{
  (void)context;
  /*
   * Use the uncached programming-register read port. Direct data-window loads
   * can retain a pre-program value in D-cache after the physical OTP changes.
   */
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_ADDR), word_address);
  return wasp1_read32(wasp1_otp_reg(WASP1_OTP_RDATA));
}


static enum wasp1_otp_proto_status target_program_word(
    void *context, uint32_t word_address, uint32_t value)
{
  uint32_t status;
  uint32_t readback;
  (void)context;

  if ((wasp1_read32(wasp1_otp_reg(WASP1_OTP_STATUS)) &
       WASP1_OTP_STATUS_LOCK) != 0) {
    return WASP1_OTP_PROTO_STATUS_LOCKED;
  }
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_CTRL), WASP1_OTP_CTRL_CLEAR);
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_KEY), WASP1_OTP_KEY_VALUE);
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_ADDR), word_address);
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_WDATA), value);
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_CTRL),
                WASP1_OTP_CTRL_PROG_EN | WASP1_OTP_CTRL_START);

  do {
    status = wasp1_read32(wasp1_otp_reg(WASP1_OTP_STATUS));
  } while ((status & WASP1_OTP_STATUS_BUSY) != 0);
  readback = wasp1_read32(wasp1_otp_reg(WASP1_OTP_RDATA));

  /* Revoke the transient unlock even when the hardware reports an error. */
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_KEY), UINT32_C(0));
  if ((status & WASP1_OTP_STATUS_ERROR) != 0) {
    return WASP1_OTP_PROTO_STATUS_PROGRAM_ERROR;
  }
  if ((status & WASP1_OTP_STATUS_DONE) == 0 ||
      readback != value) {
    return WASP1_OTP_PROTO_STATUS_PROGRAM_ERROR;
  }
  return WASP1_OTP_PROTO_STATUS_OK;
}


static enum wasp1_otp_proto_status target_lock(void *context)
{
  (void)context;
  wasp1_write32(wasp1_otp_reg(WASP1_OTP_LOCK), UINT32_C(1));
  if ((wasp1_read32(wasp1_otp_reg(WASP1_OTP_STATUS)) &
       WASP1_OTP_STATUS_LOCK) == 0) {
    return WASP1_OTP_PROTO_STATUS_INTERNAL_ERROR;
  }
  return WASP1_OTP_PROTO_STATUS_OK;
}


static uint32_t target_status(void *context)
{
  (void)context;
  return wasp1_read32(wasp1_otp_reg(WASP1_OTP_STATUS));
}


/* Immutable dispatch table avoids runtime construction or libc dependencies. */
static const struct wasp1_otp_loader_ops target_ops = {
  (void *)0,
  WASP1_OTP_DATA_SIZE,
  WASP1_OTP_CAP_READ | WASP1_OTP_CAP_PROGRAM | WASP1_OTP_CAP_LOCK,
  (uint16_t)WASP1_OTP_PROTO_MAX_PAYLOAD,
  UINT16_C(1),
  target_read_word,
  target_program_word,
  target_lock,
  target_status
};


static uint8_t uart_getc_blocking(void)
{
  while ((wasp1_uart_status() & WASP1_UART_STATUS_RX_EMPTY) != 0) {
  }
  return (uint8_t)wasp1_uart_getc_raw();
}


static void uart_write(const uint8_t *data, size_t length)
{
  size_t index;
  for (index = 0; index < length; ++index) {
    wasp1_uart_putc((char)data[index]);
  }
}


int main(void)
{
  static uint8_t request[WASP1_OTP_PROTO_MAX_FRAME_SIZE];
  static uint8_t response[WASP1_OTP_PROTO_MAX_FRAME_SIZE];

  wasp1_uart_init(WASP1_UART_OTP_BAUD_DIV);
  for (;;) {
    uint16_t payload_length;
    size_t frame_length;
    size_t response_length;
    size_t index;

    /* Resynchronize on the two magic bytes without storing console noise. */
    do {
      request[0] = uart_getc_blocking();
    } while (request[0] != (uint8_t)'W');
    request[1] = uart_getc_blocking();
    if (request[1] != (uint8_t)'1') {
      continue;
    }
    for (index = 2; index < WASP1_OTP_PROTO_HEADER_SIZE; ++index) {
      request[index] = uart_getc_blocking();
    }
    payload_length = (uint16_t)request[12] | ((uint16_t)request[13] << 8);
    if (payload_length > WASP1_OTP_PROTO_MAX_PAYLOAD) {
      /* Oversized input is abandoned; the next iteration searches for magic. */
      continue;
    }
    frame_length = WASP1_OTP_PROTO_HEADER_SIZE + payload_length +
                   WASP1_OTP_PROTO_CRC_SIZE;
    for (index = WASP1_OTP_PROTO_HEADER_SIZE; index < frame_length; ++index) {
      request[index] = uart_getc_blocking();
    }

    response_length = wasp1_otp_protocol_process(
        request, frame_length, response, sizeof(response), &target_ops);
    if (response_length != 0) {
      uart_write(response, response_length);
    }
  }
}
