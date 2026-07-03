# debug_reg_access Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-24 |
| Tool | Verilator 5.046 |
| Generic lint | PASS |
| Self-checking simulation | PASS |
| Simulation end | `1866ns` |
| Self-check milestones | 181 |
| Simulation log | `debug/logs/tb_debug_reg_access.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Time-Sequenced Action Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| `0ns-36ns` | Assert reset for three clocks and release | idle, command ready, no core/upstream valid | PASS |
| `36ns-216ns` | Directed read, write, request/response backpressure, same-cycle response, and core error | fields hold, data/error propagate, exactly one response per command | PASS |
| `216ns-347ns` | Flush before core accept, during wait, with same-edge response, and during local response | request suppression, stale drain, and response discard follow phase-specific rules | PASS |
| `347ns-386ns` | Assert asynchronous reset while core request is pending | state and visible handshakes immediately return to reset contract | PASS |
| `386ns-1866ns` | Run 20 deterministic-random read/write/error transactions with random latency/backpressure | every transaction matches the reference GPR image and handshake model | PASS |

## 4. Functional Coverage Summary

| Coverage item | Count | Result |
| --- | ---: | --- |
| Self-check milestones | 181 | PASS |
| Read command classes | 12 | PASS |
| Write command classes | 16 | PASS |
| Core request-held cycles | 31 | PASS |
| Upstream response-held cycles | 22 | PASS |
| Same-cycle core responses | 5 | PASS |
| Core error responses | 3 | PASS |
| Flush phase classes | 4 | PASS |
| Stale response drains | 1 | PASS |
| Reset-while-busy aborts | 1 | PASS |
| Deterministic-random transactions | 20 | PASS |

This milestone reports functional self-check coverage, not structural
code/toggle coverage.

## 5. Target Matrix

| Target | Command | Result |
| --- | --- | --- |
| Generic simulation | `make -C debug lint-reg-access` | PASS |
| IC | `make -C debug lint-reg-access-ic` | PASS |
| Xilinx Virtex-7 FPGA | `make -C debug lint-reg-access-fpga-v7` | PASS |
| Functional simulation | `make -C debug sim-reg-access` | PASS |
| Common interface lint | `make -C common lint` | PASS |

## 6. Residual Scope

The low-level GPR transport is verified against a mock core. Abstract-command
field decoding, halted-state policy, and top-level OpenOCD/GDB smoke are
covered by downstream debug and wasp1 verification. Richer core register-file
debug behavior remains later integration scope.
