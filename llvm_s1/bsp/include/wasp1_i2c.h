#ifndef WASP1_I2C_H
#define WASP1_I2C_H

/* Minimal I2C register definitions for firmware-controlled byte transfers. */
#include <stdint.h>
#include "wasp1_memory_map.h"
#include "wasp1_mmio.h"

/* I2C register offsets follow i2c/rtl/ahb_i2c.sv. */
#define WASP1_I2C_DATA        UINT32_C(0x00)
#define WASP1_I2C_STATUS      UINT32_C(0x04)
#define WASP1_I2C_CTRL        UINT32_C(0x08)
#define WASP1_I2C_PRESCALE    UINT32_C(0x0c)
#define WASP1_I2C_CMD         UINT32_C(0x10)

#define WASP1_I2C_CTRL_ENABLE (UINT32_C(1) << 0)
#define WASP1_I2C_CTRL_IRQ_EN (UINT32_C(1) << 1)
#define WASP1_I2C_CTRL_CLEAR  (UINT32_C(1) << 2)

#define WASP1_I2C_STATUS_BUSY     (UINT32_C(1) << 0)
#define WASP1_I2C_STATUS_DONE     (UINT32_C(1) << 1)
#define WASP1_I2C_STATUS_ACKERR   (UINT32_C(1) << 2)
#define WASP1_I2C_STATUS_RX_VALID (UINT32_C(1) << 3)

#define WASP1_I2C_CMD_START     (UINT32_C(1) << 0)
#define WASP1_I2C_CMD_READ      (UINT32_C(1) << 1)
#define WASP1_I2C_CMD_STOP      (UINT32_C(1) << 2)
#define WASP1_I2C_CMD_ACK_VALUE (UINT32_C(1) << 3)

#endif
