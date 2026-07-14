/* Byte-exact target implementation of the wasp1 UART OTP protocol. */
#include "wasp1_uart_otp_protocol.h"


#define HEADER_MAGIC0_OFFSET  UINT32_C(0)
#define HEADER_MAGIC1_OFFSET  UINT32_C(1)
#define HEADER_VERSION_OFFSET UINT32_C(2)
#define HEADER_KIND_OFFSET    UINT32_C(3)
#define HEADER_SEQUENCE_OFFSET UINT32_C(4)
#define HEADER_COMMAND_OFFSET UINT32_C(6)
#define HEADER_STATUS_OFFSET  UINT32_C(7)
#define HEADER_ADDRESS_OFFSET UINT32_C(8)
#define HEADER_LENGTH_OFFSET  UINT32_C(12)
#define HEADER_FLAGS_OFFSET   UINT32_C(14)


static uint16_t load_u16(const uint8_t *bytes)
{
  return (uint16_t)bytes[0] | ((uint16_t)bytes[1] << 8);
}


static uint32_t load_u32(const uint8_t *bytes)
{
  return (uint32_t)bytes[0] |
         ((uint32_t)bytes[1] << 8) |
         ((uint32_t)bytes[2] << 16) |
         ((uint32_t)bytes[3] << 24);
}


static void store_u16(uint8_t *bytes, uint16_t value)
{
  bytes[0] = (uint8_t)value;
  bytes[1] = (uint8_t)(value >> 8);
}


static void store_u32(uint8_t *bytes, uint32_t value)
{
  bytes[0] = (uint8_t)value;
  bytes[1] = (uint8_t)(value >> 8);
  bytes[2] = (uint8_t)(value >> 16);
  bytes[3] = (uint8_t)(value >> 24);
}


static void copy_bytes(uint8_t *destination, const uint8_t *source, size_t length)
{
  size_t index;
  for (index = 0; index < length; ++index) {
    destination[index] = source[index];
  }
}


uint32_t wasp1_otp_protocol_crc32(const uint8_t *data, size_t length)
{
  uint32_t crc = UINT32_C(0xffffffff);
  size_t byte_index;

  /* Reflected IEEE CRC32, matching Python zlib.crc32. */
  for (byte_index = 0; byte_index < length; ++byte_index) {
    unsigned int bit_index;
    crc ^= data[byte_index];
    for (bit_index = 0; bit_index < 8; ++bit_index) {
      uint32_t mask = (uint32_t)-(int32_t)(crc & UINT32_C(1));
      crc = (crc >> 1) ^ (UINT32_C(0xedb88320) & mask);
    }
  }
  return crc ^ UINT32_C(0xffffffff);
}


static size_t make_response(
    const uint8_t *request,
    uint8_t status,
    uint32_t address,
    const uint8_t *payload,
    uint16_t payload_length,
    uint8_t *response,
    size_t response_capacity)
{
  size_t frame_length = (size_t)WASP1_OTP_PROTO_HEADER_SIZE + payload_length +
                        (size_t)WASP1_OTP_PROTO_CRC_SIZE;
  uint32_t crc;

  if (frame_length > response_capacity) {
    return 0;
  }
  response[HEADER_MAGIC0_OFFSET] = (uint8_t)'W';
  response[HEADER_MAGIC1_OFFSET] = (uint8_t)'1';
  response[HEADER_VERSION_OFFSET] = WASP1_OTP_PROTO_VERSION;
  response[HEADER_KIND_OFFSET] = WASP1_OTP_PROTO_RESPONSE;
  store_u16(&response[HEADER_SEQUENCE_OFFSET],
            load_u16(&request[HEADER_SEQUENCE_OFFSET]));
  response[HEADER_COMMAND_OFFSET] = request[HEADER_COMMAND_OFFSET];
  response[HEADER_STATUS_OFFSET] = status;
  store_u32(&response[HEADER_ADDRESS_OFFSET], address);
  store_u16(&response[HEADER_LENGTH_OFFSET], payload_length);
  store_u16(&response[HEADER_FLAGS_OFFSET], UINT16_C(0));
  if (payload_length != 0 && payload != (const uint8_t *)0) {
    copy_bytes(&response[WASP1_OTP_PROTO_HEADER_SIZE], payload, payload_length);
  }
  crc = wasp1_otp_protocol_crc32(
      response, (size_t)WASP1_OTP_PROTO_HEADER_SIZE + payload_length);
  store_u32(&response[WASP1_OTP_PROTO_HEADER_SIZE + payload_length], crc);
  return frame_length;
}


static int range_is_valid(uint32_t address, uint32_t length, uint32_t limit)
{
  /* Subtraction avoids overflow in address + length. */
  return address <= limit && length <= limit - address;
}


size_t wasp1_otp_protocol_process(
    const uint8_t *request,
    size_t request_length,
    uint8_t *response,
    size_t response_capacity,
    const struct wasp1_otp_loader_ops *ops)
{
  uint16_t payload_length;
  uint32_t address;
  size_t expected_length;
  uint32_t expected_crc;
  uint32_t observed_crc;
  uint8_t payload[WASP1_OTP_PROTO_MAX_PAYLOAD];
  uint16_t response_payload_length = 0;
  enum wasp1_otp_proto_status status = WASP1_OTP_PROTO_STATUS_OK;

  if (request == (const uint8_t *)0 || response == (uint8_t *)0 ||
      ops == (const struct wasp1_otp_loader_ops *)0 ||
      request_length < WASP1_OTP_PROTO_HEADER_SIZE ||
      request[HEADER_MAGIC0_OFFSET] != (uint8_t)'W' ||
      request[HEADER_MAGIC1_OFFSET] != (uint8_t)'1') {
    return 0;
  }

  payload_length = load_u16(&request[HEADER_LENGTH_OFFSET]);
  address = load_u32(&request[HEADER_ADDRESS_OFFSET]);
  if (payload_length > WASP1_OTP_PROTO_MAX_PAYLOAD ||
      payload_length > ops->max_payload) {
    return make_response(request, WASP1_OTP_PROTO_STATUS_BAD_LENGTH, address,
                         (const uint8_t *)0, 0, response, response_capacity);
  }
  expected_length = (size_t)WASP1_OTP_PROTO_HEADER_SIZE + payload_length +
                    (size_t)WASP1_OTP_PROTO_CRC_SIZE;
  if (request_length != expected_length) {
    return make_response(request, WASP1_OTP_PROTO_STATUS_BAD_LENGTH, address,
                         (const uint8_t *)0, 0, response, response_capacity);
  }

  expected_crc = load_u32(&request[WASP1_OTP_PROTO_HEADER_SIZE + payload_length]);
  observed_crc = wasp1_otp_protocol_crc32(
      request, (size_t)WASP1_OTP_PROTO_HEADER_SIZE + payload_length);
  if (expected_crc != observed_crc) {
    return make_response(request, WASP1_OTP_PROTO_STATUS_CRC_ERROR, address,
                         (const uint8_t *)0, 0, response, response_capacity);
  }
  if (request[HEADER_VERSION_OFFSET] != WASP1_OTP_PROTO_VERSION) {
    return make_response(request, WASP1_OTP_PROTO_STATUS_BAD_VERSION, address,
                         (const uint8_t *)0, 0, response, response_capacity);
  }
  if (request[HEADER_KIND_OFFSET] != WASP1_OTP_PROTO_REQUEST ||
      request[HEADER_STATUS_OFFSET] != WASP1_OTP_PROTO_STATUS_OK ||
      load_u16(&request[HEADER_FLAGS_OFFSET]) != UINT16_C(0)) {
    return make_response(request, WASP1_OTP_PROTO_STATUS_BAD_LENGTH, address,
                         (const uint8_t *)0, 0, response, response_capacity);
  }

  switch (request[HEADER_COMMAND_OFFSET]) {
    case WASP1_OTP_CMD_HELLO:
      if (payload_length != 0) {
        status = WASP1_OTP_PROTO_STATUS_BAD_LENGTH;
        break;
      }
      store_u32(&payload[0], ops->otp_data_size);
      store_u32(&payload[4], ops->capabilities);
      store_u16(&payload[8], ops->max_payload);
      store_u16(&payload[10], ops->loader_version);
      response_payload_length = 12;
      break;

    case WASP1_OTP_CMD_READ:
      if (payload_length != 2) {
        status = WASP1_OTP_PROTO_STATUS_BAD_LENGTH;
      } else {
        uint16_t read_length = load_u16(&request[WASP1_OTP_PROTO_HEADER_SIZE]);
        uint32_t index;
        if (read_length > ops->max_payload) {
          status = WASP1_OTP_PROTO_STATUS_BAD_LENGTH;
        } else if (!range_is_valid(address, read_length, ops->otp_data_size)) {
          status = WASP1_OTP_PROTO_STATUS_BAD_ADDRESS;
        } else if ((ops->capabilities & WASP1_OTP_CAP_READ) == 0 ||
                   ops->read_word == (uint32_t (*)(void *, uint32_t))0) {
          status = WASP1_OTP_PROTO_STATUS_BAD_COMMAND;
        } else {
          for (index = 0; index < read_length; ++index) {
            uint32_t word = ops->read_word(ops->context, (address + index) >> 2);
            payload[index] = (uint8_t)(word >> (((address + index) & 3u) * 8u));
          }
          response_payload_length = read_length;
        }
      }
      break;

    case WASP1_OTP_CMD_PROGRAM:
      if (payload_length == 0) {
        status = WASP1_OTP_PROTO_STATUS_BAD_LENGTH;
      } else if ((address & UINT32_C(3)) != 0 ||
                 (payload_length & UINT16_C(3)) != 0) {
        status = WASP1_OTP_PROTO_STATUS_BAD_ALIGNMENT;
      } else if (!range_is_valid(address, payload_length, ops->otp_data_size)) {
        status = WASP1_OTP_PROTO_STATUS_BAD_ADDRESS;
      } else if ((ops->capabilities & WASP1_OTP_CAP_PROGRAM) == 0 ||
                 ops->program_word ==
                     (enum wasp1_otp_proto_status (*)(void *, uint32_t, uint32_t))0 ||
                 ops->read_word == (uint32_t (*)(void *, uint32_t))0) {
        status = WASP1_OTP_PROTO_STATUS_BAD_COMMAND;
      } else {
        uint32_t index;
        /* Validate the complete frame before the first irreversible pulse. */
        for (index = 0; index < payload_length; index += 4) {
          uint32_t current = ops->read_word(ops->context, (address + index) >> 2);
          uint32_t requested = load_u32(
              &request[WASP1_OTP_PROTO_HEADER_SIZE + index]);
          if ((requested & ~current) != 0) {
            status = WASP1_OTP_PROTO_STATUS_ILLEGAL_TRANSITION;
            break;
          }
        }
        for (index = 0;
             status == WASP1_OTP_PROTO_STATUS_OK && index < payload_length;
             index += 4) {
          status = ops->program_word(
              ops->context,
              (address + index) >> 2,
              load_u32(&request[WASP1_OTP_PROTO_HEADER_SIZE + index]));
        }
      }
      break;

    case WASP1_OTP_CMD_STATUS:
      if (payload_length != 0 ||
          ops->status == (uint32_t (*)(void *))0) {
        status = WASP1_OTP_PROTO_STATUS_BAD_LENGTH;
      } else {
        store_u32(payload, ops->status(ops->context));
        response_payload_length = 4;
      }
      break;

    case WASP1_OTP_CMD_LOCK:
      if (payload_length != 0) {
        status = WASP1_OTP_PROTO_STATUS_BAD_LENGTH;
      } else if ((ops->capabilities & WASP1_OTP_CAP_LOCK) == 0 ||
                 ops->lock ==
                     (enum wasp1_otp_proto_status (*)(void *))0) {
        status = WASP1_OTP_PROTO_STATUS_BAD_COMMAND;
      } else {
        status = ops->lock(ops->context);
      }
      break;

    default:
      status = WASP1_OTP_PROTO_STATUS_BAD_COMMAND;
      break;
  }

  if (status != WASP1_OTP_PROTO_STATUS_OK) {
    response_payload_length = 0;
  }
  return make_response(request, (uint8_t)status, address, payload,
                       response_payload_length, response, response_capacity);
}
