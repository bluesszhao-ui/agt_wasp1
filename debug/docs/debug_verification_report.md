# debug DMI Register Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-23 |
| Tool | Verilator 5.046 |
| Generic lint | PASS: `make -C debug lint` |
| IC lint | PASS: `make -C debug lint-ic` |
| Virtex-7 lint | PASS: `make -C debug lint-fpga-v7` |
| Simulation | PASS: `make -C debug sim` |
| Simulation end | `2116ns` |
| Self-check milestones | 74 |
| Simulation log | `debug/logs/tb_debug_dmi_regs.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Time-Sequenced Case Table

The boundaries below are printed by the testbench and converted from the
simulator's 1ps `%t` display to nanoseconds.

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| `0ns-36ns` | Assert reset for three rising edges and release | DM registers, pulse outputs, and response valid are clear | PASS |
| `36ns-66ns` | Read inactive dmstatus identity | version=2 and authenticated=1 | PASS |
| `66ns-226ns` | Activate DM; test halt, ndmreset, resume acknowledgement, and reset-ack pulse | activation ignores other fields; levels and pulses follow priority | PASS |
| `226ns-406ns` | Drive running/halted/resume/reset state and select hart 1 | hart 0 any/all fields match; hart 1 reports nonexistent | PASS |
| `406ns-846ns` | Exercise hartinfo, data0, busy command/data rejection, W1C cmderr, accepted command, executor error | abstract register contract and one-cycle command pulse hold | PASS |
| `846ns-996ns` | Send NOP, reserved op, unknown address, and read-only write while holding responses | legal transfers succeed; illegal transfers fail; held response remains stable | PASS |
| `996ns-1026ns` | Consume one response while accepting the next request | response slot replaces data with no empty cycle | PASS |
| `1026ns-1986ns` | Write/read 16 deterministic-random data0 values | all 32 bits compare exactly for every value | PASS |
| `1986ns-2116ns` | Clear dmactive and inject stale executor result/error | DM state clears and inactive executor updates are ignored | PASS |

## 4. Functional Coverage Summary

| Coverage item | Count | Result |
| --- | ---: | --- |
| Self-check milestones | 74 | PASS |
| DMI reads | 37 | PASS |
| DMI writes | 30 | PASS |
| Hart status classes | 4 | PASS |
| Control/command pulse classes | 2 | PASS |
| Busy rejection classes | 2 | PASS |
| Failed DMI accesses | 2 | PASS |
| Stable response-backpressure checks | 67 | PASS |
| Same-edge response replacement | 1 | PASS |
| Deterministic-random data values | 16 | PASS |

The testbench also covers NOP and write-to-read-only behavior. Assertions are
implemented as immediate self-checks with fatal termination on the first
mismatch; this milestone does not yet claim structural code/toggle coverage.

## 5. Target Matrix

| Target | Macro | Result |
| --- | --- | --- |
| Generic simulation | default `WASP1_TARGET_SIM_GENERIC` | PASS |
| IC | `WASP1_TARGET_IC` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | PASS |

## 6. Residual Scope

This report covers `debug_dmi_if` and `debug_dmi_regs`. It does not yet cover
JTAG TAP/DTM scan behavior, hart halt entry, abstract GPR execution, debug ROM,
program buffer, memory access, single-step, or OpenOCD/GDB end-to-end tests.
