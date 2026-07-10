# wasp1 Memory Macro Replacement

## 1. Scope

This document fixes the memory implementation and gate-count accounting policy
for wasp1.

Large program/data memories are not standard-cell register arrays:

```text
I-SRAM -> memory macro
D-SRAM -> memory macro
OTP    -> executable OTP/NVM macro
```

The open RTL keeps behavioral macro models for simulation and FPGA inference,
but IC synthesis must replace the macro boundary modules with technology SRAM
and OTP compiler instances or blackboxes.

## 2. Macro Boundaries

| Logical memory | AHB wrapper | Macro boundary | DC blackbox stub |
| --- | --- | --- | --- |
| I-SRAM | `ahb_sram` | `wasp1_sram_macro` | `sram/dc/wasp1_sram_macro_blackbox.sv` |
| D-SRAM | `ahb_sram` | `wasp1_sram_macro` | `sram/dc/wasp1_sram_macro_blackbox.sv` |
| OTP data | `ahb_otp` | `wasp1_otp_macro` | `otp/dc/wasp1_otp_macro_blackbox.sv` |

The AHB wrappers keep address decode, transfer alignment, error response,
status registers, lock/unlock rules, and OTP programming legality checks in
normal RTL. Only the large storage array moves behind the macro boundary.

## 3. Default Capacities

| Memory | Default logical size | Bit capacity |
| --- | ---: | ---: |
| I-SRAM | 64KB | 524,288 bits |
| D-SRAM | 64KB | 524,288 bits |
| OTP data window | 64KB minus 256B register window | 522,240 bits |

For physical planning, OTP may be rounded to a 64KB macro if the compiler does
not offer an exact 63.75KB data macro.

## 4. Gate-Count Accounting

Report synthesis size in two separate buckets:

```text
standard-cell logic gates:
  core, caches/controllers, bus, debug, DMA, peripherals, wrappers

memory macro capacity/area:
  I-SRAM, D-SRAM, OTP bitcell arrays and vendor periphery
```

Do not convert the three large memories into flip-flop gate count. If they are
accidentally inferred as standard cells, the result can become a multi-million
gate artifact and will not represent the intended chip.

Current early estimate:

```text
standard-cell logic excluding I-SRAM/D-SRAM/OTP bitcells: about 45k-75k gates
large memory macros: about 1.5Mbit total logical capacity
```

## 5. Macro Timing Contract

The logical macro wrappers currently expose:

```text
word address
32-bit data
byte write enables for SRAM
accepted program pulse for OTP
read data available to the AHB wrapper within the existing one-cycle response
```

If the selected IC SRAM or OTP macro has registered outputs, extra adapter logic
must be inserted under the macro boundary or the AHB wrapper must be updated
with documented wait-state behavior. Any such change must preserve the
software-visible memory map, OTP programming rules, and AHB-Lite correctness.

## 6. Verification Commands

The macro-boundary RTL change is verified by:

```text
make -C sram lint
make -C sram lint-ic
make -C sram lint-fpga-v7
make -C sram sim
make -C otp lint
make -C otp lint-ic
make -C otp lint-fpga-v7
make -C otp sim
make -C wasp1 lint
make -C wasp1 lint-ic
make -C wasp1 lint-fpga-v7
```
