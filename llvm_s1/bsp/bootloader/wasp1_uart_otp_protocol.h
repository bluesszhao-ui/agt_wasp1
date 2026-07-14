#ifndef WASP1_UART_OTP_PROTOCOL_H
#define WASP1_UART_OTP_PROTOCOL_H

/* Target-side contract for the versioned FT2232H Channel B OTP protocol. */
#include <stddef.h>
#include <stdint.h>

#define WASP1_OTP_PROTO_VERSION       UINT8_C(1)
#define WASP1_OTP_PROTO_HEADER_SIZE   UINT32_C(16)
#define WASP1_OTP_PROTO_CRC_SIZE      UINT32_C(4)
#define WASP1_OTP_PROTO_MAX_PAYLOAD   UINT32_C(256)
#define WASP1_OTP_PROTO_MAX_FRAME_SIZE \
  (WASP1_OTP_PROTO_HEADER_SIZE + WASP1_OTP_PROTO_MAX_PAYLOAD + \
   WASP1_OTP_PROTO_CRC_SIZE)

#define WASP1_OTP_CAP_READ    (UINT32_C(1) << 0)
#define WASP1_OTP_CAP_PROGRAM (UINT32_C(1) << 1)
#define WASP1_OTP_CAP_LOCK    (UINT32_C(1) << 2)

enum wasp1_otp_proto_kind {
  WASP1_OTP_PROTO_REQUEST = 0,
  WASP1_OTP_PROTO_RESPONSE = 1
};

enum wasp1_otp_proto_command {
  WASP1_OTP_CMD_HELLO = 0x01,
  WASP1_OTP_CMD_READ = 0x10,
  WASP1_OTP_CMD_PROGRAM = 0x11,
  WASP1_OTP_CMD_STATUS = 0x20,
  WASP1_OTP_CMD_LOCK = 0x21
};

enum wasp1_otp_proto_status {
  WASP1_OTP_PROTO_STATUS_OK = 0x00,
  WASP1_OTP_PROTO_STATUS_BAD_COMMAND = 0x01,
  WASP1_OTP_PROTO_STATUS_BAD_VERSION = 0x02,
  WASP1_OTP_PROTO_STATUS_BAD_LENGTH = 0x03,
  WASP1_OTP_PROTO_STATUS_BAD_ADDRESS = 0x04,
  WASP1_OTP_PROTO_STATUS_BAD_ALIGNMENT = 0x05,
  WASP1_OTP_PROTO_STATUS_CRC_ERROR = 0x06,
  WASP1_OTP_PROTO_STATUS_LOCKED = 0x07,
  WASP1_OTP_PROTO_STATUS_ILLEGAL_TRANSITION = 0x08,
  WASP1_OTP_PROTO_STATUS_PROGRAM_ERROR = 0x09,
  WASP1_OTP_PROTO_STATUS_BUSY = 0x0a,
  WASP1_OTP_PROTO_STATUS_INTERNAL_ERROR = 0x0b
};

/*
 * Hardware operations isolate packet validation from irreversible OTP access.
 * Unit tests provide an in-memory implementation; target firmware provides
 * MMIO operations backed by ahb_otp.
 */
struct wasp1_otp_loader_ops {
  void *context;
  uint32_t otp_data_size;
  uint32_t capabilities;
  uint16_t max_payload;
  uint16_t loader_version;
  uint32_t (*read_word)(void *context, uint32_t word_address);
  enum wasp1_otp_proto_status (*program_word)(
      void *context, uint32_t word_address, uint32_t value);
  enum wasp1_otp_proto_status (*lock)(void *context);
  uint32_t (*status)(void *context);
};

uint32_t wasp1_otp_protocol_crc32(const uint8_t *data, size_t length);

/*
 * Process exactly one complete request. A nonzero return is the response frame
 * length. Zero means no safe response can be formed, such as invalid magic or
 * insufficient response capacity.
 */
size_t wasp1_otp_protocol_process(
    const uint8_t *request,
    size_t request_length,
    uint8_t *response,
    size_t response_capacity,
    const struct wasp1_otp_loader_ops *ops);

#endif
