# debug_abstract_cmd Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-07-12 |
| Tool | Verilator 5.046 |
| Generic lint | PASS |
| Self-checking simulation | PASS |
| L3 diagram audit | PASS: `debug_abstract_cmd_fsm.graffle` |
| Simulation end | `3266ns` |
| Self-check milestones | 304 |
| Simulation log | `debug/logs/tb_debug_abstract_cmd.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Time-Sequenced Action Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| `0ns-36ns` | Assert and release reset | idle, busy low, no request/error/data0 pulse | PASS |
| `36ns-206ns` | Directed GPR read, write, delayed issue/response, and downstream error | fields hold; reads update data0; writes do not; error maps to EXCEPTION | PASS |
| `206ns-986ns` | Read local probe CSRs and DCSR/DPC; exercise both trigger slots, dual execute enable, load-only, store-only, combined load/store, slot isolation, out-of-range `tselect`, and WARL-invalid writes | local CSR behavior matches; execute/load/store outputs follow only the selected slot's legal type/action/match/M/access bits and share the slot's `tdata2` address | PASS |
| `986ns-1286ns` | Exercise no-transfer postexec, local CSR postexec, GPR-read then postexec, transfer-error suppression, and executor exception | start ordering, deferred data0, busy lifetime, and cmderr propagation match | PASS |
| `1286ns-1446ns` | Directed Access Memory word read with postincrement, byte write, halfword read, and bus-error response | halted-core memory request fields, lane extraction, strobes, data0/data1 updates, and BUS cmderr match expectation | PASS |
| `1446ns-1586ns` | Transfer-disabled no-op and unsupported type/size/options/registers plus running-hart command | no-op succeeds; unsupported maps to NOTSUP; running maps to HALT_RESUME | PASS |
| `1586ns-1796ns` | Lose halted state in ISSUE/WAIT, deactivate DM in ISSUE/WAIT, inject busy command, reset active command | flush/error/abort priorities and captured fields remain correct | PASS |
| `1796ns-3266ns` | Run 20 deterministic-random valid GPR commands with randomized issue/response delay and error injection | every decoded request and completion matches the reference model | PASS |

## 4. Functional Coverage Summary

| Coverage item | Count | Result |
| --- | ---: | --- |
| Self-check milestones | 304 | PASS |
| Read command classes | 13 | PASS |
| Write command classes | 16 | PASS |
| Local CSR read classes | 22 | PASS |
| Local CSR write classes | 17 | PASS |
| Trigger CSR cases | 14 | PASS |
| Memory read classes | 3 | PASS |
| Memory write classes | 1 | PASS |
| Transfer-disabled no-op | 1 | PASS |
| Unsupported encoding classes | 5 | PASS |
| Halt/resume errors | 3 | PASS |
| Downstream exception/bus errors | 6 | PASS |
| Issue backpressure cycles | 38 | PASS |
| Response wait cycles | 42 | PASS |
| Flush/abort classes | 4 | PASS |
| Busy command ignored | 1 | PASS |
| Reset-while-busy abort | 1 | PASS |
| Deterministic-random commands | 20 | PASS |
| Postexec classes | 5 | PASS |

This milestone reports functional self-check coverage, not structural
code/toggle coverage.

The editable L3 diagram passes:

```text
python3 docs/tools/audit_graffle_diagram.py debug/docs/diagrams/debug_abstract_cmd_fsm.graffle
plutil -lint debug/docs/diagrams/debug_abstract_cmd_fsm.graffle
```

## 5. Target Matrix

| Target | Command | Result |
| --- | --- | --- |
| Generic simulation | `make -C debug lint-abstract-cmd` | PASS |
| IC | `make -C debug lint-abstract-cmd-ic` | PASS |
| Xilinx Virtex-7 FPGA | `make -C debug lint-abstract-cmd-fpga-v7` | PASS |
| Functional simulation | `make -C debug sim-abstract-cmd` | PASS |

## 6. Residual Scope

The RV32 GPR Access Register decoder/controller, OpenOCD/GDB CSR probe path,
two-slot execute/load/store trigger CSR configuration path, physical Access Memory
byte/half/word controller, and Access Register postexec orchestration are
verified against mock GPR, memory, and Program Buffer executor transports.
Precise core-side load/store trigger match and halt behavior is covered by the
core datapath verification report. OpenOCD/GDB breakpoint and data-watchpoint
flows plus real halted-core Program Buffer execution are covered at the wasp1
top level. System Bus Access and architectural CSR side effects beyond
`dcsr.step` remain future work.
