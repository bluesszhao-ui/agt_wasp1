#!/bin/sh
# Toolchain discovery and compile/link smoke tests for the wasp1 BSP.
#
# The script is intentionally tolerant by default: a workstation without a full
# RISC-V LLVM install still gets BSP syntax checks and a clear SKIP reason. Set
# REQUIRE_RISCV_TOOLCHAIN=1 in CI or on a toolchain machine to make missing
# codegen/assembler/linker support fail the run.

set -eu

mode="full"
if [ "${1:-}" = "--toolchain-only" ]; then
  mode="toolchain"
  shift
fi

log_file="${1:-logs/smoke_tests.log}"
log_dir=$(dirname "$log_file")
mkdir -p "$log_dir" build/smoke
: > "$log_file"

if [ -z "${WASP1_TOOLCHAIN_ENV_LOADED:-}" ] && [ -x scripts/wasp1_toolchain_env.sh ]; then
  # Import discovered tool paths while still allowing caller-provided variables
  # to take priority inside the environment script.
  eval "$(scripts/wasp1_toolchain_env.sh)"
fi

clang_bin="${WASP1_CLANG:-clang}"
ld_bin="${WASP1_LD:-ld.lld}"
objcopy_bin="${WASP1_OBJCOPY:-llvm-objcopy}"
objdump_bin="${WASP1_OBJDUMP:-llvm-objdump}"
target="${WASP1_TARGET:-riscv32-unknown-elf}"
march="${WASP1_MARCH:-rv32i_zicsr}"
mabi="${WASP1_MABI:-ilp32}"
require_toolchain="${REQUIRE_RISCV_TOOLCHAIN:-0}"
failures=0
skips=0

cflags="-target $target -march=$march -mabi=$mabi -ffreestanding -fno-builtin -nostdlib -Wall -Wextra -Werror -Ibsp/include"
ldflags="-target $target -march=$march -mabi=$mabi -ffreestanding -fno-builtin -nostdlib -fuse-ld=$ld_bin -Wl,-T,bsp/linker/wasp1.ld"

log()
{
  printf '%s\n' "$*" | tee -a "$log_file"
}

fail()
{
  log "FAIL $*"
  failures=$((failures + 1))
}

skip()
{
  log "SKIP $*"
  skips=$((skips + 1))
}

require_or_skip()
{
  reason="$1"
  if [ "$require_toolchain" = "1" ]; then
    fail "$reason"
  else
    skip "$reason"
  fi
}

run_capture()
{
  label="$1"
  shift
  log "RUN $label"
  if "$@" >> "$log_file" 2>&1; then
    log "PASS $label"
    return 0
  fi
  log "FAIL $label"
  return 1
}

if command -v "$clang_bin" >/dev/null 2>&1; then
  clang_path=$(command -v "$clang_bin")
  log "PASS tool clang=$clang_path"
  "$clang_bin" --version | sed 's/^/INFO clang /' >> "$log_file" 2>&1 || true
else
  require_or_skip "clang not found; set WASP1_CLANG or install LLVM with RISC-V support"
  log "RESULT failures=$failures skips=$skips"
  exit "$failures"
fi

if command -v "$ld_bin" >/dev/null 2>&1 || [ -x "$ld_bin" ]; then
  log "PASS tool ld=$ld_bin"
else
  require_or_skip "ld.lld not found; bare-metal ELF linking unavailable"
fi

if command -v "$objcopy_bin" >/dev/null 2>&1; then
  log "PASS tool objcopy=$(command -v "$objcopy_bin")"
else
  require_or_skip "llvm-objcopy not found; binary/hex image generation unavailable"
fi

if command -v "$objdump_bin" >/dev/null 2>&1; then
  log "PASS tool objdump=$(command -v "$objdump_bin")"
else
  skip "llvm-objdump not found; disassembly checks unavailable"
fi

if [ "$mode" = "toolchain" ]; then
  if [ "$failures" -eq 0 ]; then
    log "RESULT PASS toolchain discovery failures=0 skips=$skips"
  else
    log "RESULT FAIL toolchain discovery failures=$failures skips=$skips"
  fi
  exit "$failures"
fi

syntax_sources="
  bsp/examples/hello_uart.c
  bsp/examples/gpio_blink.c
  bsp/examples/gpio_irq.c
  bsp/examples/uart_irq.c
  bsp/examples/long_boot.c
  bsp/examples/dma_copy.c
  bsp/examples/dma_irq.c
  bsp/examples/timer_irq.c
  bsp/examples/otp_program.c
  bsp/runtime/memcpy.c
  bsp/runtime/memset.c
  bsp/runtime/syscalls.c
"

for src in $syntax_sources; do
  if ! run_capture "syntax $src" "$clang_bin" $cflags -fsyntax-only "$src"; then
    failures=$((failures + 1))
  fi
done

probe_c="build/smoke/probe.c"
probe_o="build/smoke/probe.o"
printf 'int main(void) { return 0; }\n' > "$probe_c"
if "$clang_bin" $cflags -c "$probe_c" -o "$probe_o" >> "$log_file" 2>&1; then
  log "PASS riscv32 C codegen"
  codegen_ok=1
else
  codegen_ok=0
  require_or_skip "riscv32 C codegen unavailable for $clang_bin"
fi

if [ "$codegen_ok" -eq 1 ]; then
  runtime_objects=""
  for src in $syntax_sources; do
    obj="build/smoke/$(basename "$src" .c).o"
    if run_capture "compile $src" "$clang_bin" $cflags -c "$src" -o "$obj"; then
      case "$src" in
        bsp/runtime/*)
          runtime_objects="$runtime_objects $obj"
          ;;
      esac
    else
      failures=$((failures + 1))
    fi
  done

  asm_objects=""
  for src in bsp/startup/crt0.S bsp/startup/trap.S bsp/startup/vectors.S; do
    obj="build/smoke/$(basename "$src" .S).o"
    if run_capture "assemble $src" "$clang_bin" $cflags -c "$src" -o "$obj"; then
      asm_objects="$asm_objects $obj"
    else
      require_or_skip "startup assembly unavailable for $src"
    fi
  done

  hello_obj="build/smoke/hello_uart.o"
  if [ -f "$hello_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link hello_uart ELF" "$clang_bin" $ldflags $asm_objects "$hello_obj" $runtime_objects -o build/smoke/hello_uart.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy hello_uart binary" "$objcopy_bin" -O binary build/smoke/hello_uart.elf build/smoke/hello_uart.bin; then
          run_capture "make hello_uart OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/hello_uart.bin \
            --output-hex build/smoke/hello_uart_otp.hex \
            --output-bin build/smoke/hello_uart_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for riscv32"
    fi
  else
    require_or_skip "link skipped because required objects were not produced"
  fi

  gpio_irq_obj="build/smoke/gpio_irq.o"
  if [ -f "$gpio_irq_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link gpio_irq ELF" "$clang_bin" $ldflags $asm_objects "$gpio_irq_obj" $runtime_objects -o build/smoke/gpio_irq.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy gpio_irq binary" "$objcopy_bin" -O binary build/smoke/gpio_irq.elf build/smoke/gpio_irq.bin; then
          run_capture "make gpio_irq OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/gpio_irq.bin \
            --output-hex build/smoke/gpio_irq_otp.hex \
            --output-bin build/smoke/gpio_irq_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for gpio_irq riscv32"
    fi
  else
    require_or_skip "gpio_irq link skipped because required objects were not produced"
  fi

  uart_irq_obj="build/smoke/uart_irq.o"
  if [ -f "$uart_irq_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link uart_irq ELF" "$clang_bin" $ldflags $asm_objects "$uart_irq_obj" $runtime_objects -o build/smoke/uart_irq.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy uart_irq binary" "$objcopy_bin" -O binary build/smoke/uart_irq.elf build/smoke/uart_irq.bin; then
          run_capture "make uart_irq OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/uart_irq.bin \
            --output-hex build/smoke/uart_irq_otp.hex \
            --output-bin build/smoke/uart_irq_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for uart_irq riscv32"
    fi
  else
    require_or_skip "uart_irq link skipped because required objects were not produced"
  fi

  long_boot_obj="build/smoke/long_boot.o"
  if [ -f "$long_boot_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link long_boot ELF" "$clang_bin" $ldflags $asm_objects "$long_boot_obj" $runtime_objects -o build/smoke/long_boot.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy long_boot binary" "$objcopy_bin" -O binary build/smoke/long_boot.elf build/smoke/long_boot.bin; then
          run_capture "make long_boot OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/long_boot.bin \
            --output-hex build/smoke/long_boot_otp.hex \
            --output-bin build/smoke/long_boot_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for long_boot riscv32"
    fi
  else
    require_or_skip "long_boot link skipped because required objects were not produced"
  fi

  dma_obj="build/smoke/dma_copy.o"
  if [ -f "$dma_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link dma_copy ELF" "$clang_bin" $ldflags $asm_objects "$dma_obj" $runtime_objects -o build/smoke/dma_copy.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy dma_copy binary" "$objcopy_bin" -O binary build/smoke/dma_copy.elf build/smoke/dma_copy.bin; then
          run_capture "make dma_copy OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/dma_copy.bin \
            --output-hex build/smoke/dma_copy_otp.hex \
            --output-bin build/smoke/dma_copy_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for dma_copy riscv32"
    fi
  else
    require_or_skip "dma_copy link skipped because required objects were not produced"
  fi

  dma_irq_obj="build/smoke/dma_irq.o"
  if [ -f "$dma_irq_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link dma_irq ELF" "$clang_bin" $ldflags $asm_objects "$dma_irq_obj" $runtime_objects -o build/smoke/dma_irq.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy dma_irq binary" "$objcopy_bin" -O binary build/smoke/dma_irq.elf build/smoke/dma_irq.bin; then
          run_capture "make dma_irq OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/dma_irq.bin \
            --output-hex build/smoke/dma_irq_otp.hex \
            --output-bin build/smoke/dma_irq_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for dma_irq riscv32"
    fi
  else
    require_or_skip "dma_irq link skipped because required objects were not produced"
  fi

  timer_irq_obj="build/smoke/timer_irq.o"
  if [ -f "$timer_irq_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link timer_irq ELF" "$clang_bin" $ldflags $asm_objects "$timer_irq_obj" $runtime_objects -o build/smoke/timer_irq.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy timer_irq binary" "$objcopy_bin" -O binary build/smoke/timer_irq.elf build/smoke/timer_irq.bin; then
          run_capture "make timer_irq OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/timer_irq.bin \
            --output-hex build/smoke/timer_irq_otp.hex \
            --output-bin build/smoke/timer_irq_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for timer_irq riscv32"
    fi
  else
    require_or_skip "timer_irq link skipped because required objects were not produced"
  fi

  otp_obj="build/smoke/otp_program.o"
  if [ -f "$otp_obj" ] && [ -n "$runtime_objects" ] && [ -n "$asm_objects" ]; then
    if run_capture "link otp_program ELF" "$clang_bin" $ldflags $asm_objects "$otp_obj" $runtime_objects -o build/smoke/otp_program.elf; then
      if command -v "$objcopy_bin" >/dev/null 2>&1; then
        if run_capture "objcopy otp_program binary" "$objcopy_bin" -O binary build/smoke/otp_program.elf build/smoke/otp_program.bin; then
          run_capture "make otp_program OTP hex" scripts/wasp1_make_otp_image.py \
            --format bin \
            --input build/smoke/otp_program.bin \
            --output-hex build/smoke/otp_program_otp.hex \
            --output-bin build/smoke/otp_program_otp.bin || failures=$((failures + 1))
        else
          failures=$((failures + 1))
        fi
      fi
    else
      require_or_skip "bare-metal linker unavailable for otp_program riscv32"
    fi
  else
    require_or_skip "otp_program link skipped because required objects were not produced"
  fi
fi

if [ "$failures" -eq 0 ]; then
  log "RESULT PASS smoke tests failures=0 skips=$skips"
else
  log "RESULT FAIL smoke tests failures=$failures skips=$skips"
fi

exit "$failures"
