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

It does not yet build LLVM from source, add `-mcpu=wasp1`, or run a full SoC
software boot regression.

## 2. Contents

| Path | Purpose |
| --- | --- |
| `bsp/include/` | Memory map, MMIO helpers, and peripheral register helpers |
| `bsp/linker/wasp1.ld` | OTP load layout with I-SRAM and D-SRAM run regions |
| `bsp/startup/crt0.S` | Reset entry, stack setup, mtvec setup, copy/zero loops, `main` call |
| `bsp/startup/trap.S` | Minimal machine trap entry calling `wasp1_trap_handler` |
| `bsp/runtime/` | Minimal freestanding runtime helpers |
| `bsp/examples/` | Tiny UART and GPIO examples |
| `scripts/check_bsp.sh` | Structural BSP check that avoids requiring a RISC-V compiler |

The startup/trap code is intentionally minimal. `trap.S` forwards `mcause`,
`mepc`, and `mtval` to `wasp1_trap_handler`, but it does not save the full
integer register context yet. That makes it useful for fatal early diagnostics,
not for nested interrupts or recoverable exceptions.

## 3. Link Layout

```text
.text/.rodata  load/run in OTP
.fasttext      load from OTP, run in I-SRAM
.data          load from OTP, run in D-SRAM
.bss           run in D-SRAM
heap/stack     run in D-SRAM
```

## 4. Next Steps

The current `make test` target checks BSP structure, key symbols, and aggregate
C header syntax. Follow-up work should replace that with real RV32I build and
boot regressions:

1. Add toolchain discovery and build rules for `clang`, `ld.lld`, `llvm-objcopy`,
   and `llvm-objdump`.
2. Add compile/link smoke tests under `llvm_s1/tests`.
3. Convert linked ELF output into OTP initialization images.
4. Connect the generated OTP image to `wasp1` top-level simulation.
