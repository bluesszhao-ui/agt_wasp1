# ahb_sram Spec

## 1. Purpose

`ahb_sram` provides a reusable AHB-Lite SRAM slave for I-SRAM and D-SRAM style
memory windows.

## 2. Interface Requirements

The module must expose an AHB-Lite slave interface with clock and active-low
reset. `HREADY` may be always high in the first implementation.

## 3. Access Requirements

The SRAM must support:

```text
byte reads/writes
halfword reads/writes
word reads/writes
```

Writes must update only the addressed byte lanes. Reads must return the full
32-bit word containing the addressed byte lane.

## 4. Error Requirements

Selected active transfers must return ERROR for:

```text
out-of-range address
misaligned halfword access
misaligned word access
unsupported HSIZE
```

Errored writes must not modify memory.

## 5. Target Requirements

The module must support IC, Virtex-7 FPGA, and generic simulation targets. The
external AHB behavior must not change across targets.

## 6. Verification Requirements

Verification must cover reset, all supported sizes, byte lanes, unselected
behavior, range/alignment errors, and deterministic random word accesses.
