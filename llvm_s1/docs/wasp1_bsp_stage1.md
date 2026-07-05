# wasp1 BSP Stage 1

## 1. Scope

This stage provides a bare-metal BSP skeleton for code built with an upstream
RISC-V LLVM toolchain using:

```text
-target riscv32-unknown-elf
-march=rv32i_zicsr
-mabi=ilp32
-nostdlib
```

It does not yet build LLVM from source, add `-mcpu=wasp1`, or run a complete
system software regression suite.

## 2. Contents

| Path | Purpose |
| --- | --- |
| `bsp/include/` | Memory map, MMIO helpers, and peripheral register helpers |
| `bsp/linker/wasp1.ld` | OTP load layout with I-SRAM and D-SRAM run regions |
| `bsp/startup/crt0.S` | Reset entry, stack setup, mtvec setup, copy/zero loops, `main` call |
| `bsp/startup/trap.S` | Machine trap entry saving integer context and calling `wasp1_trap_handler` |
| `bsp/runtime/` | Minimal freestanding runtime helpers |
| `bsp/examples/` | Tiny UART, UART TX/RX IRQ, long boot, GPIO, GPIO IRQ, DMA copy, DMA IRQ, timer IRQ, and OTP programming examples |
| `scripts/check_bsp.sh` | Structural BSP check that avoids requiring a RISC-V compiler |
| `scripts/run_smoke_tests.sh` | Toolchain discovery plus syntax/compile/link smoke tests |
| `scripts/wasp1_make_otp_image.py` | ELF/raw-binary to OTP `$readmemh` image converter |

The startup/trap code is still machine-mode-only and direct-vector only.
`trap.S` saves all integer registers except `x0` and the stack pointer slot,
forwards `mcause`, `mepc`, and `mtval` to `wasp1_trap_handler`, restores the
interrupted context, and returns with `mret`. This supports simple recoverable
timer and external interrupt firmware; nested interrupts are still outside the
stage-1 runtime policy.

## 3. Link Layout

```text
.text/.rodata  load/run in OTP
.fasttext      load from OTP, run in I-SRAM
.data          load from OTP, run in D-SRAM
.bss           run in D-SRAM
heap/stack     run in D-SRAM
```

## 4. Next Steps

The current `make test` target checks BSP structure, key symbols, aggregate C
header syntax, tool discovery, example/runtime source syntax, and OTP image
format generation. If a full RISC-V LLVM toolchain is available, the smoke
script also attempts RV32I object generation, startup assembly, bare-metal ELF
linking, binary image generation, and generated OTP image creation for
`hello_uart`, `uart_irq`, `uart_rx_irq`, `long_boot`, `mixed_irq_dma`,
`gpio_irq`, `dma_copy`, `dma_irq`, `timer_irq`, and `otp_program`.

By default, missing RISC-V code generation or LLVM binary utilities are reported
as `SKIP` so a normal workstation can still validate the BSP source tree. To
make those gaps fail a CI run, use:

```text
REQUIRE_RISCV_TOOLCHAIN=1 make -C llvm_s1 test
```

The top-level `wasp1` simulation already consumes generated OTP images for the
UART boot smoke, the UART TX-empty external interrupt smoke, the UART
RX-available/RX-overrun external interrupt smoke, the long multi-peripheral boot
smoke, the mixed interrupt-and-DMA smoke, the DMA real-memory-copy smoke, the
DMA external interrupt smoke, the GPIO external interrupt smoke, the timer
interrupt smoke, and the OTP
programming-register smoke. The
OTP programming example places the
programming routine in `.fasttext` so startup copies it to I-SRAM before it
writes OTP control registers. The DMA copy example seeds real D-SRAM
source/destination windows, drains the source stores with a readback, then
starts DMA and lets the top-level testbench check copied memory and DMA status.
The long boot example performs UART output, GPIO output/toggle operations,
D-SRAM pattern stores and reads, a polled DMA copy, a polled timer compare, and
an executable OTP word read before writing completion mailboxes.
The mixed IRQ/DMA example enables DMA completion and GPIO level-high external
interrupts together, gives DMA higher INTC priority, starts a DMA copy, and
records the expected DMA-then-GPIO claim sequence plus copied D-SRAM data.
The UART IRQ example enables the UART TX-empty interrupt, routes it through INTC
as machine external interrupt IRQ ID 2, claims/completes the interrupt in the C
trap handler, clears the sticky UART source, disables the TX IRQ enable, and
records trap mailbox values in D-SRAM.
The UART RX IRQ example waits for testbench-driven serial input, handles one
RX-available interrupt by reading UART DATA, then handles an RX-overrun
interrupt after the testbench sends enough external serial frames to trip the
sticky overrun path.
The DMA IRQ example routes the same DMA completion through INTC as machine
external interrupt, claims/completes IRQ ID 5, and clears the sticky DMA IRQ
source before returning.
The GPIO IRQ example configures GPIO bit 0 as a level-high source, routes it
through INTC as IRQ ID 4, claims/completes the machine external interrupt, and
clears the sticky GPIO IRQ source before returning.
The timer IRQ example programs `mtime/mtimecmp`, enables MTIE/MIE, handles one
machine timer interrupt in C, records trap CSR values in D-SRAM mailboxes, and
then idles.

Follow-up work should continue replacing this smoke layer with broader RV32I
boot regressions:

1. Add an installed LLVM bundle under `llvm_s1/toolchain/install` or document
   an external LLVM install path.
2. Add richer debug operations and longer software stress regressions.
