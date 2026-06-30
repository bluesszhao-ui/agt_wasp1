# CMake cache fragment for building a minimal LLVM toolchain for wasp1.
#
# Intended use from llvm_s1/toolchain/build:
#   cmake -G Ninja -C ../configs/wasp1_llvm_cmake_cache.cmake ../llvm-project/llvm
#
# The install prefix deliberately points at llvm_s1/toolchain/install so the
# smoke-test scripts can auto-discover the freshly built toolchain.

set(CMAKE_BUILD_TYPE "Release" CACHE STRING "Release build for local toolchain use")
set(CMAKE_INSTALL_PREFIX "../install" CACHE PATH "wasp1 local LLVM install prefix")

set(LLVM_ENABLE_PROJECTS "clang;lld" CACHE STRING "Build clang and lld")
set(LLVM_TARGETS_TO_BUILD "RISCV" CACHE STRING "Build only the RISC-V backend")
set(LLVM_DEFAULT_TARGET_TRIPLE "riscv32-unknown-elf" CACHE STRING "Default target triple")
set(LLVM_ENABLE_ASSERTIONS OFF CACHE BOOL "Disable assertions for normal toolchain use")
set(LLVM_INCLUDE_BENCHMARKS OFF CACHE BOOL "Skip benchmarks")
set(LLVM_INCLUDE_EXAMPLES OFF CACHE BOOL "Skip examples")
set(LLVM_INCLUDE_TESTS OFF CACHE BOOL "Skip LLVM tests in the local toolchain build")
set(LLVM_BUILD_DOCS OFF CACHE BOOL "Skip LLVM documentation build")
set(LLVM_ENABLE_TERMINFO OFF CACHE BOOL "Avoid optional terminfo dependency")
set(LLVM_ENABLE_ZLIB OFF CACHE BOOL "Avoid optional zlib dependency")
set(LLVM_ENABLE_ZSTD OFF CACHE BOOL "Avoid optional zstd dependency")
