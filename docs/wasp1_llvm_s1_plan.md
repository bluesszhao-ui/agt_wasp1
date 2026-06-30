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
  minimal trap stub
  memcpy/memset/syscall stubs
  UART and GPIO examples
  structural BSP self-check

not yet implemented:
  bootloader sources
  LLVM source build flow
  wasp1-specific LLVM patches
  RV32I compile/link smoke tests
  OTP image generation and SoC boot regression
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
timer interrupt program
DMA copy program
OTP programming program
```

The current `llvm_s1/Makefile` provides a stage-1 `make test` target that checks
file completeness, critical linker/startup symbols, and host C syntax for the
aggregate BSP header. RV32I compile/link tests are the next milestone once the
toolchain wrapper exists.
