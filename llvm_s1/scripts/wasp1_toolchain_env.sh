#!/bin/sh
# Print shell exports for the preferred wasp1 LLVM/RISC-V toolchain.
#
# Usage:
#   eval "$(llvm_s1/scripts/wasp1_toolchain_env.sh)"
#
# Discovery order:
#   1. Existing WASP1_LLVM_ROOT from the caller
#   2. llvm_s1/toolchain/install
#   3. Homebrew LLVM on Apple Silicon
#   4. Homebrew LLVM on Intel macOS
#   5. Tools already present in PATH

set -eu

quote_sh()
{
  # Single-quote a value for eval-safe POSIX shell output.
  printf "%s" "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
llvm_s1_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

root="${WASP1_LLVM_ROOT:-}"
if [ -z "$root" ]; then
  for candidate in \
    "$llvm_s1_dir/toolchain/install" \
    "/opt/homebrew/opt/llvm" \
    "/usr/local/opt/llvm"
  do
    if [ -x "$candidate/bin/clang" ]; then
      root="$candidate"
      break
    fi
  done
fi

if [ -n "$root" ]; then
  clang_default="$root/bin/clang"
  objcopy_default="$root/bin/llvm-objcopy"
  objdump_default="$root/bin/llvm-objdump"
else
  clang_default=$(command -v clang 2>/dev/null || printf "clang")
  objcopy_default=$(command -v llvm-objcopy 2>/dev/null || printf "llvm-objcopy")
  objdump_default=$(command -v llvm-objdump 2>/dev/null || printf "llvm-objdump")
fi

ld_default=""
for candidate in \
  "${root:+$root/bin/ld.lld}" \
  "/opt/homebrew/opt/lld/bin/ld.lld" \
  "/usr/local/opt/lld/bin/ld.lld"
do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    ld_default="$candidate"
    break
  fi
done
if [ -z "$ld_default" ]; then
  ld_default=$(command -v ld.lld 2>/dev/null || printf "ld.lld")
fi

printf 'export WASP1_TOOLCHAIN_ENV_LOADED=1\n'
if [ -n "$root" ]; then
  printf 'export WASP1_LLVM_ROOT=%s\n' "$(quote_sh "$root")"
fi
printf 'export WASP1_CLANG=%s\n' "$(quote_sh "${WASP1_CLANG:-$clang_default}")"
printf 'export WASP1_LD=%s\n' "$(quote_sh "${WASP1_LD:-$ld_default}")"
printf 'export WASP1_OBJCOPY=%s\n' "$(quote_sh "${WASP1_OBJCOPY:-$objcopy_default}")"
printf 'export WASP1_OBJDUMP=%s\n' "$(quote_sh "${WASP1_OBJDUMP:-$objdump_default}")"
printf 'export WASP1_TARGET=%s\n' "$(quote_sh "${WASP1_TARGET:-riscv32-unknown-elf}")"
printf 'export WASP1_MARCH=%s\n' "$(quote_sh "${WASP1_MARCH:-rv32i_zicsr}")"
printf 'export WASP1_MABI=%s\n' "$(quote_sh "${WASP1_MABI:-ilp32}")"
