# wasp1

wasp1 is a minimal single-core RV32I + Zicsr SoC project.

The hardware is implemented in synthesizable SystemVerilog and follows
Rocket Chip-like high-level module boundaries while using AHB-Lite as the SoC
interconnect.

## Baseline

```text
ISA: RV32I + Zicsr
Privilege: Machine mode only
MMU/TLB/PTW: none
RTL: SystemVerilog, .sv suffix
SoC bus: AHB-Lite
Core/cache internal interface: lightweight valid/ready request-response
Core plan: simple 3-stage pipeline
I-cache: direct-mapped, 16-byte line
D-cache: direct-mapped, 16-byte line, write-through
Debug target: RISC-V External Debug Spec 0.13.x / OpenOCD / GDB
Program storage: executable OTP
Compiler work: LLVM-based bare-metal wasp1 toolchain and BSP
```

## Top-Level Modules

```text
common
wasp1
tile
core
frontend
icache
dcache
bus
otp
sram
dma
debug
timer
intc
wdg
uart
i2c
gpio
llvm_s1
```

Each hardware module owns its own `rtl/`, `tb/`, `filelists/`, `docs/`,
`build/`, `logs/`, `wave/`, and `Makefile` directories.

## Current Status

Implemented and verified:

```text
common RTL foundation
  wasp1_pkg
  ahb_lite_if
  mem_req_rsp_if
  irq_if
  debug_if
  reset_sync
  sync_reg
  simple_fifo
  skid_buffer

bus ahb_decoder
  address decode
  one-hot select
  default select
  directed boundary tests
  deterministic random tests
```

The current early implementation path is:

```text
common -> bus -> sram -> otp -> timer -> gpio -> uart -> dma -> intc
```

See [ROADMAP.md](ROADMAP.md) for the live module progress list.

## Quick Commands

Run all currently wired lint targets:

```sh
make lint
```

Run the AHB decoder simulation:

```sh
make -C bus sim
```

Run common lint only:

```sh
make -C common lint
```

Generated build, log, and waveform outputs are ignored by git.

## Documentation

Start here:

```text
docs/index.md
```

Important project documents:

```text
docs/wasp1_architecture.md
docs/wasp1_module_hierarchy.md
docs/wasp1_memory_map.md
docs/wasp1_design_plan.md
docs/wasp1_verification_plan.md
docs/wasp1_debug_strategy.md
docs/wasp1_otp_boot_strategy.md
docs/wasp1_llvm_s1_plan.md
```

## Contributor and Agent Rules

Human contributor guidance:

```text
CONTRIBUTING.md
```

Agent workflow rules:

```text
AGENTS.md
```

## License

wasp1 is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
