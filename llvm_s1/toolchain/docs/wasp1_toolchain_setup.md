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

`ld.lld` may come from a separate Homebrew `lld` formula. The environment script
exports `WASP1_LD` from `WASP1_LLVM_ROOT/bin/ld.lld`,
`/opt/homebrew/opt/lld/bin/ld.lld`, `/usr/local/opt/lld/bin/ld.lld`, or PATH.

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
make -C llvm_s1 build-toolchain
```

The make target runs `scripts/build_local_llvm.sh`, which is equivalent to:

```text
cd llvm_s1/toolchain/build
cmake -G Ninja -C ../configs/wasp1_llvm_cmake_cache.cmake ../llvm-project/llvm
ninja
ninja install
```

The cache installs into `llvm_s1/toolchain/install`, which is the first project
local path discovered by the smoke-test environment script.

The build script does not download LLVM. If the source tree is elsewhere, set:

```text
WASP1_LLVM_SOURCE_DIR=/path/to/llvm-project/llvm make -C llvm_s1 build-toolchain
```

## 4. Expected First Pass

A complete toolchain should make these steps pass:

```text
make -C llvm_s1 toolchain
REQUIRE_RISCV_TOOLCHAIN=1 make -C llvm_s1 test
```

On this workstation, the strict smoke target is known to pass with:

```text
WASP1_LLVM_ROOT=/opt/homebrew/opt/llvm
WASP1_LD=/opt/homebrew/opt/lld/bin/ld.lld
```

The next milestone after this is converting the linked ELF into an OTP image and
loading it into the `wasp1` top-level simulation.

## 5. Local Source Checkout

The local LLVM source checkout is intentionally ignored by the wasp1 git repo
because it is a large third-party tree. The current checkout is:

```text
path: llvm_s1/toolchain/llvm-project
upstream: https://github.com/llvm/llvm-project.git
commit: 14d9c0c46
sparse paths: llvm, clang, lld
```

This source tree is the baseline for future wasp1-specific LLVM patches under
`llvm_s1/toolchain/patches`.
