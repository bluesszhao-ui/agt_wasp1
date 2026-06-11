# AGENTS.md

This file defines working rules for agents contributing to wasp1.

## Project Intent

wasp1 is a minimal single-core RV32I + Zicsr SoC implemented in synthesizable
SystemVerilog. It follows Rocket Chip-like high-level module boundaries while
using AHB-Lite as the SoC bus.

Key baseline:

```text
ISA: RV32I + Zicsr
Privilege: Machine mode only
MMU/TLB/PTW: none
RTL: SystemVerilog, .sv suffix
SoC bus: AHB-Lite
Core/cache internal interface: lightweight valid/ready request-response
Debug: RISC-V External Debug Spec 0.13.x target
Program storage: executable OTP
Implementation targets: IC and Xilinx Virtex-7 FPGA
Target selection: compile-time macros in common/rtl/wasp1_target_defs.svh
```

## Directory Rules

Each first-level hardware module must keep this structure:

```text
module_name/
  rtl/
  tb/
  filelists/
  build/
  logs/
  dc/
  dv/
  sw/
  wave/
  docs/
  Makefile
```

Do not place loose RTL, testbench, build, log, or waveform files in the repo
root.

`llvm_s1/` is the exception and follows the compiler/BSP structure documented in
`docs/wasp1_llvm_s1_plan.md`.

## Design Flow

Do not jump straight into top-level integration.

For each module:

```text
1. Write or update design spec
2. Write or update verification plan
3. Implement RTL
4. Add filelists and Makefile targets
5. Add self-checking testbench
6. Run lint and simulation
7. Update verification report
8. Commit only after PASS
```

Proceed module by module in the planned order unless the user explicitly changes
priority.

## Verification Standard

Smoke tests are not enough.

Each module should aim for strong functional coverage:

```text
normal path
boundary conditions
error path
inactive/idle behavior
backpressure or stall behavior when applicable
random or deterministic-random checks when useful
self-checking scoreboard or reference model when practical
coverage summary in the verification report
```

Verification reports must include a time-sequenced action table with expected
and observed results.

Default simulation timing policy:

```text
timescale: 1ns/1ps
default verification clock period: 10ns
default verification clock frequency: 100MHz
```

Pure combinational modules may not have a DUT clock, but their testbenches
should still describe case timing in 10ns verification steps where practical.
Sequential modules must use an explicit clock unless a module-specific spec
states otherwise.

## RTL Style

Use synthesizable SystemVerilog.

Prefer:

```text
logic
always_ff
always_comb
interfaces for structured connectivity
packages for shared parameters/types
one module per .sv file
clear reset behavior
self-contained parameter defaults
```

Avoid:

```text
unsynthesizable RTL in rtl/
implicit nets
ad hoc duplicated constants
large unrelated refactors
changing established interfaces without updating docs/tests
```

All RTL must support both implementation targets unless a module spec explicitly
documents why the logic is target-neutral:

```text
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
WASP1_TARGET_SIM_GENERIC
```

Target macros may select memory wrappers, FPGA synthesis attributes, clock/reset
primitives, and IO/debug implementation details. They must not change
programmer-visible behavior, AHB-Lite protocol behavior, register maps,
interrupt behavior, or debug architectural behavior.

## Git Rules

Keep commits small and aligned with verified milestones.

Before committing:

```text
make lint
module-specific simulation target
target-specific lint targets when the module has target-sensitive RTL
git status --short
```

Generated build, log, and waveform outputs should stay ignored unless the user
explicitly asks to archive them.

## Current First Implementation Path

The active early hardware path is:

```text
common
bus
  ahb_decoder
  ahb_default_slave
  ahb_slave_mux
  ahb_arbiter_2m
sram
otp
timer
gpio
uart
dma
intc
core
frontend
icache
dcache
tile
debug
wasp1
llvm_s1
```

See `docs/wasp1_design_plan.md` for the broader plan.
