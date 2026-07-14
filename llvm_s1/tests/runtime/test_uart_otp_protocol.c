/* Host-native behavioral tests for the target-side UART OTP protocol core. */
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#include "wasp1_uart_otp_protocol.h"


#define MODEL_WORDS 64u
#define ASSERT_TRUE(condition) do { \
  if (!(condition)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #condition); \
    return 1; \
  } \
} while (0)


struct otp_model {
  uint32_t words[MODEL_WORDS];
  unsigned int program_calls;
  int locked;
};


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


static uint32_t model_read_word(void *context, uint32_t word_address)
{
  struct otp_model *model = (struct otp_model *)context;
  return model->words[word_address];
}


static enum wasp1_otp_proto_status model_program_word(
    void *context, uint32_t word_address, uint32_t value)
{
  struct otp_model *model = (struct otp_model *)context;
  if (model->locked) {
    return WASP1_OTP_PROTO_STATUS_LOCKED;
  }
  if ((value & ~model->words[word_address]) != 0) {
    return WASP1_OTP_PROTO_STATUS_ILLEGAL_TRANSITION;
  }
  model->words[word_address] &= value;
  model->program_calls++;
  return WASP1_OTP_PROTO_STATUS_OK;
}


static enum wasp1_otp_proto_status model_lock(void *context)
{
  ((struct otp_model *)context)->locked = 1;
  return WASP1_OTP_PROTO_STATUS_OK;
}


static uint32_t model_status(void *context)
{
  return ((struct otp_model *)context)->locked ? UINT32_C(8) : UINT32_C(0);
}


static size_t make_request(
    uint8_t *frame,
    uint8_t version,
    uint16_t sequence,
    uint8_t command,
    uint32_t address,
    const uint8_t *payload,
    uint16_t payload_length)
{
  size_t index;
  uint32_t crc;
  frame[0] = (uint8_t)'W';
  frame[1] = (uint8_t)'1';
  frame[2] = version;
  frame[3] = WASP1_OTP_PROTO_REQUEST;
  store_u16(&frame[4], sequence);
  frame[6] = command;
  frame[7] = WASP1_OTP_PROTO_STATUS_OK;
  store_u32(&frame[8], address);
  store_u16(&frame[12], payload_length);
  store_u16(&frame[14], 0);
  for (index = 0; index < payload_length; ++index) {
    frame[WASP1_OTP_PROTO_HEADER_SIZE + index] = payload[index];
  }
  crc = wasp1_otp_protocol_crc32(
      frame, WASP1_OTP_PROTO_HEADER_SIZE + payload_length);
  store_u32(&frame[WASP1_OTP_PROTO_HEADER_SIZE + payload_length], crc);
  return WASP1_OTP_PROTO_HEADER_SIZE + payload_length + WASP1_OTP_PROTO_CRC_SIZE;
}


static uint8_t response_status(const uint8_t *response)
{
  return response[7];
}


int main(void)
{
  struct otp_model model;
  struct wasp1_otp_loader_ops ops;
  uint8_t request[WASP1_OTP_PROTO_MAX_FRAME_SIZE];
  uint8_t response[WASP1_OTP_PROTO_MAX_FRAME_SIZE];
  uint8_t payload[16];
  size_t request_length;
  size_t response_length;
  unsigned int index;

  memset(&model, 0, sizeof(model));
  for (index = 0; index < MODEL_WORDS; ++index) {
    model.words[index] = UINT32_C(0xffffffff);
  }
  ops.context = &model;
  ops.otp_data_size = MODEL_WORDS * 4u;
  ops.capabilities = WASP1_OTP_CAP_READ | WASP1_OTP_CAP_PROGRAM |
                     WASP1_OTP_CAP_LOCK;
  ops.max_payload = 16;
  ops.loader_version = 1;
  ops.read_word = model_read_word;
  ops.program_word = model_program_word;
  ops.lock = model_lock;
  ops.status = model_status;

  ASSERT_TRUE(wasp1_otp_protocol_crc32((const uint8_t *)"123456789", 9) ==
              UINT32_C(0xcbf43926));

  request_length = make_request(request, 1, 0x1234, WASP1_OTP_CMD_HELLO,
                                0, payload, 0);
  response_length = wasp1_otp_protocol_process(
      request, request_length, response, sizeof(response), &ops);
  ASSERT_TRUE(response_length == 32);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_OK);
  ASSERT_TRUE(load_u16(&response[4]) == 0x1234);
  ASSERT_TRUE(load_u16(&response[12]) == 12);
  ASSERT_TRUE(load_u32(&response[16]) == MODEL_WORDS * 4u);
  ASSERT_TRUE(load_u32(&response[20]) == 7u);

  model.words[1] = UINT32_C(0x44332211);
  store_u16(payload, 4);
  request_length = make_request(request, 1, 2, WASP1_OTP_CMD_READ,
                                5, payload, 2);
  response_length = wasp1_otp_protocol_process(
      request, request_length, response, sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_OK);
  ASSERT_TRUE(load_u16(&response[12]) == 4);
  ASSERT_TRUE(response[16] == 0x22 && response[17] == 0x33 &&
              response[18] == 0x44 && response[19] == 0xff);

  store_u32(&payload[0], UINT32_C(0x12345678));
  store_u32(&payload[4], UINT32_C(0x00ff00ff));
  request_length = make_request(request, 1, 3, WASP1_OTP_CMD_PROGRAM,
                                8, payload, 8);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_OK);
  ASSERT_TRUE(model.words[2] == UINT32_C(0x12345678));
  ASSERT_TRUE(model.words[3] == UINT32_C(0x00ff00ff));
  ASSERT_TRUE(model.program_calls == 2);

  /* A later illegal word prevents programming an earlier legal word. */
  model.words[4] = UINT32_C(0xffffffff);
  model.words[5] = UINT32_C(0x00000000);
  store_u32(&payload[0], UINT32_C(0xaaaaaaaa));
  store_u32(&payload[4], UINT32_C(0x00000001));
  request_length = make_request(request, 1, 4, WASP1_OTP_CMD_PROGRAM,
                                16, payload, 8);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) ==
              WASP1_OTP_PROTO_STATUS_ILLEGAL_TRANSITION);
  ASSERT_TRUE(model.words[4] == UINT32_C(0xffffffff));
  ASSERT_TRUE(model.program_calls == 2);

  request_length = make_request(request, 1, 5, WASP1_OTP_CMD_PROGRAM,
                                2, payload, 4);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_BAD_ALIGNMENT);

  store_u16(payload, 8);
  request_length = make_request(request, 1, 6, WASP1_OTP_CMD_READ,
                                MODEL_WORDS * 4u - 4u, payload, 2);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_BAD_ADDRESS);

  request_length = make_request(request, 1, 7, WASP1_OTP_CMD_PROGRAM,
                                24, payload, 4);
  request[request_length - 1] ^= 1u;
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_CRC_ERROR);
  ASSERT_TRUE(model.program_calls == 2);

  request_length = make_request(request, 2, 8, WASP1_OTP_CMD_HELLO,
                                0, payload, 0);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_BAD_VERSION);

  request_length = make_request(request, 1, 9, 0x7f, 0, payload, 0);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_BAD_COMMAND);

  request_length = make_request(request, 1, 10, WASP1_OTP_CMD_LOCK,
                                0, payload, 0);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_OK);
  ASSERT_TRUE(model.locked == 1);

  request_length = make_request(request, 1, 11, WASP1_OTP_CMD_STATUS,
                                0, payload, 0);
  wasp1_otp_protocol_process(request, request_length, response,
                             sizeof(response), &ops);
  ASSERT_TRUE(response_status(response) == WASP1_OTP_PROTO_STATUS_OK);
  ASSERT_TRUE(load_u32(&response[16]) == UINT32_C(8));

  puts("RESULT PASS wasp1 UART OTP target protocol");
  return 0;
}
