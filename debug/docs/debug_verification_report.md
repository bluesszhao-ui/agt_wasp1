# debug Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-07-03 |
| Tool | Verilator 5.046 |
| Generic lint | PASS: `make -C debug lint` |
| IC lint | PASS: `make -C debug lint-ic` |
| Virtex-7 lint | PASS: `make -C debug lint-fpga-v7` |
| Simulation | PASS: `make -C debug sim` |
| Top simulation end | `606ns` |
| Top self-check milestones | 28 |
| Top simulation log | `debug/logs/tb_debug.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
clock period = 10ns
clock frequency = 100MHz
```

## 3. Top-Level Time-Sequenced Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| `0ns-36ns` | Assert reset for three clocks and release | DM outputs, DMI response, and core debug requests are idle | PASS |
| `36ns-66ns` | Read inactive `dmstatus` | version 2 and authenticated fields visible | PASS |
| `66ns-246ns` | Activate DM, request halt, report core halted, then request resume and report running | halt/resume requests drive core and retire; dmstatus halted/resumeack fields match | PASS |
| `246ns-396ns` | Write data0 and issue Access Register write x5 | core GPR request writes x5 with `0xA5A51234`; abstractcs remains clean | PASS |
| `396ns-466ns` | Issue Access Register read x6 and return core data | data0 reads back `0x6A6A5678` | PASS |
| `466ns-526ns` | Issue Access Register read of `dpc` while the core model supplies a nonzero captured PC | data0 reads back the core Debug PC value | PASS |
| `526ns-566ns` | Issue unsupported Access Register size and clear cmderr | cmderr reports NOTSUP, then W1C clear returns it to zero | PASS |
| `566ns-606ns` | Pulse hart reset event and acknowledge havereset | dmstatus.havereset sets and clears | PASS |

## 4. Top Functional Coverage Summary

| Coverage item | Count | Result |
| --- | ---: | --- |
| Self-check milestones | 28 | PASS |
| DMI reads | 10 | PASS |
| DMI writes | 11 | PASS |
| Halt transaction | 1 | PASS |
| Resume transaction | 1 | PASS |
| GPR write transaction | 1 | PASS |
| GPR read transaction | 1 | PASS |
| DPC CSR read transaction | 1 | PASS |
| Abstract error and clear | 1 | PASS |
| Reset/reset-sticky classes | 2 | PASS |

Leaf-level random/backpressure/error coverage remains recorded in:

```text
debug_dmi_regs_verification_report.md
debug_halt_ctrl_verification_report.md
debug_reg_access_verification_report.md
debug_abstract_cmd_verification_report.md
debug_jtag_dtm_verification_report.md
debug_jtag_verification_report.md
```

## 5. Residual Scope

OpenOCD/GDB end-to-end smoke is covered by the wasp1 top-level verification
report. Single-step, program buffer, abstract memory access, debug ROM, general
CSR access beyond the debugger probe set, and multi-hart behavior beyond
nonexistent-hart reporting remain future work.
