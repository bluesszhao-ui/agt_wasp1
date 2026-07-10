#!/bin/sh
# Stage-1 BSP structural check for wasp1.
#
# The stage-1 LLVM area intentionally avoids requiring a local RISC-V compiler.
# This script verifies that the freestanding BSP skeleton is complete, that the
# C headers parse under a generic C compiler, and that startup/linker symbols
# needed by the future RV32I build flow are present.

set -eu

log_file="${1:-logs/check_bsp.log}"
log_dir=$(dirname "$log_file")
mkdir -p "$log_dir"
: > "$log_file"

failures=0

log()
{
  printf '%s\n' "$*" | tee -a "$log_file"
}

require_file()
{
  file="$1"
  if [ -f "$file" ]; then
    log "PASS file $file"
  else
    log "FAIL missing $file"
    failures=$((failures + 1))
  fi
}

require_grep()
{
  pattern="$1"
  file="$2"
  label="$3"
  if grep -Eq "$pattern" "$file"; then
    log "PASS token $label"
  else
    log "FAIL token $label in $file"
    failures=$((failures + 1))
  fi
}

bsp_files="
  bsp/include/wasp1.h
  bsp/include/wasp1_csr.h
  bsp/include/wasp1_dma.h
  bsp/include/wasp1_gpio.h
  bsp/include/wasp1_i2c.h
  bsp/include/wasp1_intc.h
  bsp/include/wasp1_memory_map.h
  bsp/include/wasp1_mmio.h
  bsp/include/wasp1_otp.h
  bsp/include/wasp1_runtime.h
  bsp/include/wasp1_timer.h
  bsp/include/wasp1_uart.h
  bsp/include/wasp1_wdg.h
  bsp/linker/wasp1.ld
  bsp/startup/crt0.S
  bsp/startup/trap.S
  bsp/startup/vectors.S
  bsp/runtime/syscalls.c
  bsp/runtime/memcpy.c
  bsp/runtime/memset.c
  bsp/examples/hello_uart.c
  bsp/examples/gpio_blink.c
  bsp/examples/gpio_irq.c
  bsp/examples/uart_irq.c
  bsp/examples/uart_rx_irq.c
  bsp/examples/long_boot.c
  bsp/examples/mixed_irq_dma.c
  bsp/examples/system_stress.c
  bsp/examples/dma_copy.c
  bsp/examples/dma_irq.c
  bsp/examples/timer_irq.c
  bsp/examples/otp_program.c
  docs/wasp1_bsp_stage1.md
  scripts/check_otp_image.sh
  scripts/wasp1_make_otp_image.py
"

for file in $bsp_files; do
  require_file "$file"
done

require_grep 'WASP1_OTP_BASE[[:space:]]+UINT32_C\(0x00000000\)' bsp/include/wasp1_memory_map.h 'OTP base'
require_grep 'WASP1_DSRAM_BASE[[:space:]]+UINT32_C\(0x20000000\)' bsp/include/wasp1_memory_map.h 'D-SRAM base'
require_grep 'WASP1_UART_BASE[[:space:]]+UINT32_C\(0x40040000\)' bsp/include/wasp1_memory_map.h 'UART base'
require_grep 'OTP[[:space:]]+\(rx\)[[:space:]]+:[[:space:]]+ORIGIN = 0x00000000, LENGTH = 0x0000ff00' bsp/linker/wasp1.ld 'OTP linker window'
require_grep 'ENTRY\(_start\)' bsp/linker/wasp1.ld 'entry point'
require_grep 'csrw[[:space:]]+mtvec' bsp/startup/crt0.S 'mtvec setup'
require_grep '__trap_entry' bsp/startup/trap.S 'trap entry'
require_grep 'sw[[:space:]]+x31' bsp/startup/trap.S 'trap context save'
require_grep '\.fasttext' bsp/examples/otp_program.c 'OTP programming routine in I-SRAM section'

if command -v cc >/dev/null 2>&1; then
  tmp_c=$(mktemp "${TMPDIR:-/tmp}/wasp1_bsp_headers.$$.XXXXXX.c")
  {
    printf '#include "wasp1.h"\n'
    printf 'int main(void) { return (int)(WASP1_RESET_VECTOR + WASP1_IRQ_DMA); }\n'
  } > "$tmp_c"
  if cc -std=c11 -Wall -Wextra -Werror -Ibsp/include -fsyntax-only "$tmp_c" >> "$log_file" 2>&1; then
    log "PASS host C syntax for aggregate header"
  else
    log "FAIL host C syntax for aggregate header"
    failures=$((failures + 1))
  fi
  rm -f "$tmp_c"
else
  log "SKIP host C syntax check: cc not found"
fi

if command -v python3 >/dev/null 2>&1; then
  pycache_dir="${TMPDIR:-/tmp}/wasp1_pycache"
  mkdir -p "$pycache_dir"
  if PYTHONPYCACHEPREFIX="$pycache_dir" python3 -m py_compile scripts/wasp1_make_otp_image.py >> "$log_file" 2>&1; then
    log "PASS python syntax for OTP image utility"
  else
    log "FAIL python syntax for OTP image utility"
    failures=$((failures + 1))
  fi
else
  log "SKIP python syntax check: python3 not found"
fi

if [ "$failures" -eq 0 ]; then
  log "RESULT PASS llvm_s1 stage-1 BSP structural check"
else
  log "RESULT FAIL llvm_s1 stage-1 BSP structural check failures=$failures"
fi

exit "$failures"
