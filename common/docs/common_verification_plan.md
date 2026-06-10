# common Verification Plan

## 1. Goals

The first `common` verification milestone checks that shared RTL compiles and
basic reusable primitives behave correctly.

Interfaces and packages are linted through Verilator. Small RTL cells receive
directed simulation testbenches as they become behaviorally important.

## 2. Initial Lint Cases

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-1ns | Parse `wasp1_pkg.sv` | Parameters and typedefs compile | TBD |
| 1ns-2ns | Parse interfaces | Modports and signal declarations compile | TBD |
| 2ns-3ns | Parse reset/sync helpers | Sequential logic compiles | TBD |
| 3ns-4ns | Parse FIFO/skid buffer | Ready/valid helpers compile | TBD |

## 3. Directed Primitive Cases

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Assert and release reset into `reset_sync` | Output reset deasserts synchronously | TBD |
| 20ns-80ns | Push one entry into `simple_fifo` | FIFO accepts data and asserts output valid | TBD |
| 80ns-140ns | Pop one entry from `simple_fifo` | Output data matches pushed data | TBD |
| 140ns-200ns | Stall `skid_buffer` output while input fires | Data is held without loss | TBD |
| 200ns-260ns | Release `skid_buffer` output | Held data is delivered once | TBD |

## 4. Checks

Initial checks:

```text
Verilator lint has no fatal errors
all files use SystemVerilog .sv suffix
ready/valid helpers do not drop data under one-cycle backpressure
reset synchronizer asserts immediately and releases after STAGES cycles
```

## 5. Future Coverage

Later verification should add:

```text
random FIFO push/pop with scoreboard
skid buffer backpressure randomization
interface protocol assertions
CDC-specific checks for synchronizer use sites
```
