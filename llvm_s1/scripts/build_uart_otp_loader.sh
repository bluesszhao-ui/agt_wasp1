#!/bin/sh
# Build the JTAG-loadable RV32I UART OTP programmer entirely into I-SRAM.

set -eu

if [ -z "${WASP1_TOOLCHAIN_ENV_LOADED:-}" ]; then
  eval "$(scripts/wasp1_toolchain_env.sh)"
fi

clang_bin="${WASP1_CLANG:-clang}"
ld_bin="${WASP1_LD:-ld.lld}"
objcopy_bin="${WASP1_OBJCOPY:-llvm-objcopy}"
target="${WASP1_TARGET:-riscv32-unknown-elf}"
march="${WASP1_MARCH:-rv32i_zicsr}"
mabi="${WASP1_MABI:-ilp32}"
output_dir="${WASP1_UART_OTP_OUTPUT_DIR:-build/uart_otp_loader}"
log_file="${WASP1_UART_OTP_LOG_FILE:-logs/uart_otp_loader_build.log}"
baud_define=""
if [ -n "${WASP1_UART_OTP_BAUD_DIV:-}" ]; then
  baud_define="-DWASP1_UART_OTP_BAUD_DIV=${WASP1_UART_OTP_BAUD_DIV}"
fi

mkdir -p "$output_dir" logs
: > "$log_file"

cflags="-target $target -march=$march -mabi=$mabi -Os -ffreestanding -fno-builtin -nostdlib -Wall -Wextra -Werror -Ibsp/include -Ibsp/bootloader $baud_define"

"$clang_bin" $cflags -c bsp/startup/isram_loader_start.S \
  -o "$output_dir/isram_loader_start.o" >> "$log_file" 2>&1
"$clang_bin" $cflags -c bsp/bootloader/wasp1_uart_otp_protocol.c \
  -o "$output_dir/wasp1_uart_otp_protocol.o" >> "$log_file" 2>&1
"$clang_bin" $cflags -c bsp/bootloader/uart_otp_loader.c \
  -o "$output_dir/uart_otp_loader.o" >> "$log_file" 2>&1
"$clang_bin" -target "$target" -march="$march" -mabi="$mabi" \
  -nostdlib -fuse-ld="$ld_bin" -Wl,-T,bsp/linker/wasp1_isram_loader.ld \
  "$output_dir/isram_loader_start.o" \
  "$output_dir/wasp1_uart_otp_protocol.o" \
  "$output_dir/uart_otp_loader.o" \
  -o "$output_dir/wasp1_uart_otp_loader.elf" >> "$log_file" 2>&1
"$objcopy_bin" -O binary "$output_dir/wasp1_uart_otp_loader.elf" \
  "$output_dir/wasp1_uart_otp_loader.bin" >> "$log_file" 2>&1
scripts/wasp1_make_otp_image.py \
  --format bin \
  --input "$output_dir/wasp1_uart_otp_loader.bin" \
  --output-hex "$output_dir/wasp1_uart_otp_loader_isram.hex" \
  --size 0x10000 --fill 0x00 >> "$log_file" 2>&1

size=$(wc -c < "$output_dir/wasp1_uart_otp_loader.bin" | tr -d ' ')
if [ "$size" -le 0 ] || [ "$size" -gt 61440 ]; then
  printf 'FAIL loader binary size %s is outside I-SRAM budget\n' "$size" | tee -a "$log_file"
  exit 1
fi
printf 'PASS RV32I I-SRAM UART OTP loader: %s bytes\n' "$size" | tee -a "$log_file"
