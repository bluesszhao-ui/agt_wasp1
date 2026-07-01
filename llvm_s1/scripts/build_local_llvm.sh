#!/bin/sh
# Configure, build, and install the project-local LLVM toolchain for wasp1.
#
# This script does not download LLVM. It expects the source tree to be present
# at llvm_s1/toolchain/llvm-project, then installs into
# llvm_s1/toolchain/install so smoke tests can discover the result.

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
llvm_s1_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)

source_dir="${WASP1_LLVM_SOURCE_DIR:-$llvm_s1_dir/toolchain/llvm-project/llvm}"
build_dir="${WASP1_LLVM_BUILD_DIR:-$llvm_s1_dir/toolchain/build}"
install_dir="${WASP1_LLVM_INSTALL_DIR:-$llvm_s1_dir/toolchain/install}"
cache_file="${WASP1_LLVM_CACHE_FILE:-$llvm_s1_dir/toolchain/configs/wasp1_llvm_cmake_cache.cmake}"

log()
{
  printf '%s\n' "$*"
}

if [ ! -f "$source_dir/CMakeLists.txt" ]; then
  log "FAIL LLVM source tree not found at $source_dir"
  log "INFO place llvm-project under llvm_s1/toolchain/llvm-project or set WASP1_LLVM_SOURCE_DIR"
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  log "FAIL cmake not found"
  exit 1
fi

if ! command -v ninja >/dev/null 2>&1; then
  log "FAIL ninja not found"
  exit 1
fi

mkdir -p "$build_dir"

log "INFO configuring LLVM source=$source_dir build=$build_dir install=$install_dir"
cmake -G Ninja -C "$cache_file" -S "$source_dir" -B "$build_dir" -DCMAKE_INSTALL_PREFIX="$install_dir"

log "INFO building LLVM"
cmake --build "$build_dir"

log "INFO installing LLVM"
cmake --install "$build_dir"

log "RESULT PASS local LLVM toolchain installed"
