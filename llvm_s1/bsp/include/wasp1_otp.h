#ifndef WASP1_OTP_H
#define WASP1_OTP_H

/* OTP programming register definitions; executable data lives below this window. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* Offsets are relative to WASP1_OTP_REG_BASE, not to executable OTP base. */
#define WASP1_OTP_CTRL        UINT32_C(0x00)
#define WASP1_OTP_STATUS      UINT32_C(0x04)
#define WASP1_OTP_ADDR        UINT32_C(0x08)
#define WASP1_OTP_WDATA       UINT32_C(0x0c)
#define WASP1_OTP_RDATA       UINT32_C(0x10)
#define WASP1_OTP_KEY         UINT32_C(0x14)
#define WASP1_OTP_LOCK        UINT32_C(0x18)

#define WASP1_OTP_KEY_VALUE   UINT32_C(0x57504f54)

#define WASP1_OTP_CTRL_PROG_EN (UINT32_C(1) << 0)
#define WASP1_OTP_CTRL_START   (UINT32_C(1) << 1)
#define WASP1_OTP_CTRL_CLEAR   (UINT32_C(1) << 2)

static inline uintptr_t wasp1_otp_reg(uint32_t offset)
{
  /* Return an absolute MMIO address inside the final 256-byte OTP register window. */
  return (uintptr_t)(WASP1_OTP_REG_BASE + offset);
}

#endif
