# common Spec

## 1. Purpose

`common` provides shared definitions and small reusable RTL utilities used by
all wasp1 hardware modules.

## 2. Required Contents

`common` must provide:

```text
global address map constants
AHB-Lite protocol constants and enums
interrupt IDs
CSR addresses and trap cause constants
target selection macros
common interfaces
reset/synchronization helpers
small generic buffering helpers
```

## 3. External Contract

Shared constants in `wasp1_pkg.sv` are the single source of truth for RTL
address decoding and software-visible register offsets until generated headers
are introduced.

Target macros in `wasp1_target_defs.svh` must select exactly one effective
implementation target:

```text
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
WASP1_TARGET_SIM_GENERIC
```

When no target macro is explicitly selected, generic simulation is the default.

## 4. Interface Requirements

Common interfaces must use synthesizable SystemVerilog `interface` constructs
and expose modports that preserve directionality.

`debug_if` must provide independently owned hart-control, GPR/memory abstract
access, and Program Buffer execution channels. The execution request carries a
32-bit instruction plus a two-bit word index; its completion response carries a
sticky-until-accepted error indication.

Reset-related utilities must use explicit reset polarity in their port names.

## 5. Out of Scope

`common` must not instantiate SoC-visible peripherals, memories, core logic, or
target-specific hard macros directly.

## 6. Verification Requirements

`common` must lint as a complete filelist and must compile under the default
target macro behavior.
