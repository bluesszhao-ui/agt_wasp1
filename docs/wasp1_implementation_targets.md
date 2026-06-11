# wasp1 Implementation Targets

## 1. Goal

All wasp1 RTL must support both chip implementation and FPGA implementation.

The initial FPGA target is:

```text
Xilinx Virtex-7
```

Target-specific differences must be selected by compile-time macros while
keeping the module's architectural behavior and external interface stable.

## 2. Target Macros

The shared target definition header is:

```text
common/rtl/wasp1_target_defs.svh
```

Supported target macros:

| Macro | Meaning |
| --- | --- |
| `WASP1_TARGET_IC` | Chip/ASIC implementation path |
| `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | Xilinx Virtex-7 FPGA implementation path |
| `WASP1_TARGET_SIM_GENERIC` | Generic simulation path, selected by default when no target macro is defined |

Exactly one target should be selected by synthesis builds.

## 3. Design Rules

Target macros may be used for implementation details such as:

```text
SRAM macro wrapper vs FPGA BRAM inference
OTP macro/model wrapper vs FPGA RAM-based OTP model
clock/reset primitives
debug/JTAG IO cells
optional synthesis attributes
```

Target macros must not change:

```text
programmer-visible behavior
AHB-Lite protocol behavior
register map
interrupt behavior
debug architectural behavior
reset vector
```

## 4. Memory Policy

Large memories must use a stable wrapper-level interface.

For chip implementation:

```text
WASP1_TARGET_IC selects an IC memory integration path.
The first open-source RTL milestone may use a synthesizable model, but the
module boundary must allow replacement by foundry/compiler SRAM or OTP macros.
```

For Virtex-7 FPGA implementation:

```text
WASP1_TARGET_FPGA_XILINX_VIRTEX7 selects FPGA-friendly inference or primitive
wrappers. SRAM and cache data/tag arrays should infer block RAM or distributed
RAM intentionally, with attributes documented in the module spec.
```

## 5. Verification Policy

Target-sensitive modules should be linted in at least these configurations:

```text
generic simulation default
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```

Functional simulation may share the generic model when behavior is identical,
but verification reports must state which target macro configurations were
compiled.
