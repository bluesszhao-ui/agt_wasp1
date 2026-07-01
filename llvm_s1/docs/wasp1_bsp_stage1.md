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
| `scripts/run_smoke_tests.sh` | Toolchain discovery plus syntax/compile/link smoke tests |
| `scripts/wasp1_make_otp_image.py` | ELF/raw-binary to OTP `$readmemh` image converter |

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

The current `make test` target checks BSP structure, key symbols, aggregate C
header syntax, tool discovery, example/runtime source syntax, and OTP image
format generation. If a full RISC-V LLVM toolchain is available, the smoke
script also attempts RV32I object generation, startup assembly, bare-metal ELF
linking, and optional binary image generation.

By default, missing RISC-V code generation or LLVM binary utilities are reported
as `SKIP` so a normal workstation can still validate the BSP source tree. To
make those gaps fail a CI run, use:

```text
REQUIRE_RISCV_TOOLCHAIN=1 make -C llvm_s1 test
```

Follow-up work should replace this smoke layer with real RV32I boot regressions:

1. Add an installed LLVM bundle under `llvm_s1/toolchain/install` or document
   an external LLVM install path.
2. Convert linked ELF output into OTP initialization images.
3. Connect the generated OTP image to `wasp1` top-level simulation.
4. Add directed firmware tests for timer interrupts, DMA copy, and OTP program.
