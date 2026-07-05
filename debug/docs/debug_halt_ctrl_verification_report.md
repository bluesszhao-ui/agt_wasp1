# debug_halt_ctrl Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-24 |
| Tool | Verilator 5.046 |
| Generic lint | PASS |
| IC lint | PASS |
| Xilinx Virtex-7 lint | PASS |
| Self-checking simulation | PASS |
| Simulation end | `1056ns` |
| Self-check milestones | 102 |
| Simulation log | `debug/logs/tb_debug_halt_ctrl.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Time-Sequenced Action Table

The testbench prints each phase boundary. `%t` values use the 1ps simulator
resolution and are converted below to nanoseconds.

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| `0ns-36ns` | Assert and release controller reset | FSM idle, requests/ack clear, havereset set | PASS |
| `36ns-56ns` | Assert halt and resume while DM inactive | both core requests remain suppressed | PASS |
| `56ns-86ns` | Clear reset report, then overlap reset event and acknowledgement | active ack clears; reset event wins and sets again | PASS |
| `86ns-166ns` | Directed delayed halt, already-halted case, and early cancellation | request holds to halt, avoids redundant request, and cancels correctly | PASS |
| `166ns-276ns` | Directed delayed resume, sticky/new ack, already-running case, and halt priority | resume request/ack semantics and halt priority match spec | PASS |
| `276ns-326ns` | Deactivate DM during halt and reset hart during resume | requests gate low, FSM aborts, sticky state follows priority | PASS |
| `326ns-1056ns` | Eight halt/resume pairs with deterministic random core latency | every request holds until the randomized response and every status matches | PASS |

## 4. Functional Coverage Summary

| Coverage item | Count | Result |
| --- | ---: | --- |
| Self-check milestones | 102 | PASS |
| Halt transactions/classes | 10 | PASS |
| Resume transactions/classes | 10 | PASS |
| Cancellation/abort classes | 3 | PASS |
| Halt-priority classes | 2 | PASS |
| Reset/reset-event classes | 4 | PASS |
| Inactive/deactivation classes | 2 | PASS |
| Sticky resumeack checks | 10 | PASS |
| Request-held latency cycles | 39 | PASS |
| Deterministic-random halt/resume pairs | 8 | PASS |

This is functional self-check coverage. Structural code/toggle coverage is not
claimed by this milestone.

## 5. Target Matrix

| Target | Command | Result |
| --- | --- | --- |
| Generic simulation | `make -C debug lint-halt-ctrl` | PASS |
| IC | `make -C debug lint-halt-ctrl-ic` | PASS |
| Xilinx Virtex-7 FPGA | `make -C debug lint-halt-ctrl-fpga-v7` | PASS |
| Functional simulation | `make -C debug sim-halt-ctrl` | PASS |

## 6. Residual Scope

The DM-side halt/resume transaction controller is verified against a mock core.
Core pipeline Debug Mode entry/exit, DPC capture, abstract GPR access, and
top-level OpenOCD/GDB smoke are covered by downstream core/debug/wasp1
verification. DCSR cause-field refinement remains later debug scope.
