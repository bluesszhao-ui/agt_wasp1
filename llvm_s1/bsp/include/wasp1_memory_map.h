#ifndef WASP1_MEMORY_MAP_H
#define WASP1_MEMORY_MAP_H

#include <stdint.h>

/* Executable OTP starts at reset and reserves the final 256 bytes for registers. */
#define WASP1_OTP_BASE        UINT32_C(0x00000000)
#define WASP1_ISRAM_BASE      UINT32_C(0x10000000)
#define WASP1_DSRAM_BASE      UINT32_C(0x20000000)

/* AHB-Lite peripheral windows. Each peripheral occupies one 4 KiB slot. */
#define WASP1_DMA_BASE        UINT32_C(0x40000000)
#define WASP1_WDG_BASE        UINT32_C(0x40010000)
#define WASP1_TIMER_BASE      UINT32_C(0x40020000)
#define WASP1_INTC_BASE       UINT32_C(0x40030000)
#define WASP1_UART_BASE       UINT32_C(0x40040000)
#define WASP1_I2C_BASE        UINT32_C(0x40050000)
#define WASP1_GPIO_BASE       UINT32_C(0x40060000)

#define WASP1_OTP_SIZE        UINT32_C(0x00010000)
#define WASP1_ISRAM_SIZE      UINT32_C(0x00010000)
#define WASP1_DSRAM_SIZE      UINT32_C(0x00010000)
#define WASP1_PERIPH_SIZE     UINT32_C(0x00001000)

#define WASP1_OTP_REG_WINDOW_SIZE UINT32_C(0x00000100)
#define WASP1_OTP_DATA_SIZE       (WASP1_OTP_SIZE - WASP1_OTP_REG_WINDOW_SIZE)
#define WASP1_OTP_REG_BASE        (WASP1_OTP_BASE + WASP1_OTP_DATA_SIZE)

/* Hardware reset PC. The linker keeps _start at this address. */
#define WASP1_RESET_VECTOR    WASP1_OTP_BASE

#endif
