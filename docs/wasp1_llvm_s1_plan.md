# llvm_s1 Plan

## 1. Goal

`llvm_s1` contains the LLVM-based compiler work for wasp1 plus the bare-metal
BSP needed to build programs for the SoC.

The first stage uses the upstream LLVM RISC-V backend with wasp1-specific BSP,
linker script, startup code, runtime stubs, and later tool wrapper scripts.

## 2. Directory Structure

```text
llvm_s1
  toolchain
    llvm-project
    build
    install
    patches
    configs
    docs
  bsp
    include
    startup
    linker
    bootloader
    runtime
    examples
  scripts
  tests
    compile
    runtime
    abi
    linker
  docs
  build
  logs
  Makefile
```

## 3. Toolchain Strategy

Initial compile flags:

```text
-target riscv32-unknown-elf
-march=rv32i_zicsr
-mabi=ilp32
-nostdlib
```

The LLVM source tree is kept under:

```text
llvm_s1/toolchain/llvm-project
```

wasp1-specific LLVM changes are tracked as patches:

```text
llvm_s1/toolchain/patches
```

Potential later patches include:

```text
add -mcpu=wasp1
add wasp1 driver defaults
add wasp1 scheduling model
add wasp1 builtin helpers
```

## 4. BSP Contents

```text
bsp/include
  wasp1.h
  wasp1_memory_map.h
  wasp1_mmio.h
  wasp1_uart.h
  wasp1_gpio.h
  wasp1_timer.h
  wasp1_wdg.h
  wasp1_dma.h
  wasp1_otp.h
  wasp1_intc.h
  wasp1_i2c.h

bsp/startup
  crt0.S
  trap.S
  vectors.S

bsp/linker
  wasp1.ld

bsp/bootloader
  uart_loader.c
  otp_program.c
  image_format.h

bsp/runtime
  syscalls.c
  memcpy.c
  memset.c
```

Stage-1 status:

```text
implemented:
  memory map and MMIO helpers
  UART/GPIO/timer/WDG/DMA/INTC/OTP/I2C register helpers
  OTP-first linker script
  crt0 reset entry
  machine-mode trap entry with integer context save/restore
  memcpy/memset/syscall stubs
  UART, GPIO, and OTP programming examples
  long multi-peripheral boot example
  mixed interrupt-and-DMA example through INTC
  DMA real-memory-copy example
  UART external interrupt example through INTC
  UART RX-available/RX-overrun interrupt example through INTC
  DMA external interrupt example through INTC
  GPIO external interrupt example through INTC
  timer interrupt example with C trap handler
  structural BSP self-check
  toolchain discovery and syntax/codegen/link smoke-test harness
  project-local LLVM build wrapper
  OTP image generation utility and format self-check
  Homebrew LLVM/lld strict RV32I compile/link smoke pass
  local sparse LLVM source checkout for llvm/clang/lld
  SoC boot regression that consumes generated hello_uart OTP image
  SoC long boot regression that consumes generated long_boot OTP image
  SoC mixed interrupt-and-DMA regression that consumes generated mixed_irq_dma OTP image
  SoC system stress regression that consumes generated system_stress OTP image
  SoC DMA copy regression that consumes generated dma_copy OTP image
  SoC UART external interrupt regression that consumes generated uart_irq OTP image
  SoC UART RX/overrun interrupt regression that consumes generated uart_rx_irq OTP image
  SoC DMA external interrupt regression that consumes generated dma_irq OTP image
  SoC GPIO external interrupt regression that consumes generated gpio_irq OTP image
  SoC timer interrupt regression that consumes generated timer_irq OTP image
  SoC OTP programming regression that consumes generated otp_program OTP image

not yet implemented:
  bootloader sources
  wasp1-specific LLVM patches
  longer randomized and interrupt-heavy software stress regressions
```

## 5. Linker Layout

```text
.text/.rodata  -> OTP
.fasttext      -> I-SRAM, load from OTP
.data          -> D-SRAM, load from OTP
.bss           -> D-SRAM
heap/stack     -> D-SRAM
```

## 6. Tests

Compiler and BSP tests include:

```text
compile-only RV32I/Zicsr tests
linker layout checks
startup copy/zero checks
trap handler build checks
UART hello program
UART external interrupt program
UART RX/overrun external interrupt program
long multi-peripheral boot program
mixed interrupt-and-DMA program
system stress program
timer interrupt program
DMA copy program
DMA external interrupt program
GPIO external interrupt program
OTP programming program
```

The current `llvm_s1/Makefile` provides:

```text
make -C llvm_s1 toolchain
make -C llvm_s1 test
REQUIRE_RISCV_TOOLCHAIN=1 make -C llvm_s1 test
```

The default test target checks file completeness, critical linker/startup
symbols, aggregate-header syntax, tool discovery, and BSP source syntax. It also
attempts RV32I object generation, startup assembly, ELF linking, and optional
binary/OTP image generation when a full RISC-V LLVM toolchain is installed.
The current smoke flow builds `hello_uart_otp.hex`, `long_boot_otp.hex`,
`mixed_irq_dma_otp.hex`, `dma_copy_otp.hex`, `uart_irq_otp.hex`,
`uart_rx_irq_otp.hex`, `gpio_irq_otp.hex`, `dma_irq_otp.hex`,
`timer_irq_otp.hex`, and `otp_program_otp.hex`; the `wasp1` top-level
regression consumes these images.

On a workstation without RISC-V LLVM code generation support, unavailable
compile/link steps are reported as `SKIP`. The `REQUIRE_RISCV_TOOLCHAIN=1` mode
turns those gaps into failures for CI or toolchain-validation machines.

Toolchain setup details live in:

```text
llvm_s1/toolchain/docs/wasp1_toolchain_setup.md
llvm_s1/toolchain/configs/wasp1_llvm_cmake_cache.cmake
```
