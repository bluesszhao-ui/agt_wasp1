# wasp1 LLVM Toolchain Setup

## 1. Toolchain Discovery

The BSP smoke tests use `llvm_s1/scripts/wasp1_toolchain_env.sh` to discover
tool paths. Discovery order is:

```text
1. WASP1_LLVM_ROOT from the caller
2. llvm_s1/toolchain/install
3. /opt/homebrew/opt/llvm
4. /usr/local/opt/llvm
5. clang/llvm-objcopy/llvm-objdump from PATH
```

To inspect the selected tools:

```text
cd llvm_s1
scripts/wasp1_toolchain_env.sh
make toolchain
```

To force a specific install:

```text
cd llvm_s1
export WASP1_LLVM_ROOT=/path/to/llvm
eval "$(scripts/wasp1_toolchain_env.sh)"
make test
```

## 2. Strict Validation

Default smoke tests allow missing RISC-V code generation and binary utilities to
be reported as `SKIP`, which keeps ordinary development machines useful. A
toolchain machine or CI job should run:

```text
REQUIRE_RISCV_TOOLCHAIN=1 make -C llvm_s1 test
```

That mode fails if RV32I object generation, startup assembly, ELF linking, or
binary image generation cannot run.

## 3. Local LLVM Build

After placing LLVM source under `llvm_s1/toolchain/llvm-project`, configure a
minimal RISC-V LLVM build with:

```text
cd llvm_s1/toolchain/build
cmake -G Ninja -C ../configs/wasp1_llvm_cmake_cache.cmake ../llvm-project/llvm
ninja
ninja install
```

The cache installs into `llvm_s1/toolchain/install`, which is the first project
local path discovered by the smoke-test environment script.

## 4. Expected First Pass

A complete toolchain should make these steps pass:

```text
make -C llvm_s1 toolchain
REQUIRE_RISCV_TOOLCHAIN=1 make -C llvm_s1 test
```

The next milestone after this is converting the linked ELF into an OTP image and
loading it into the `wasp1` top-level simulation.
