# debug_abstract_cmd Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-07-07 |
| Tool | Verilator 5.046 |
| Generic lint | PASS |
| Self-checking simulation | PASS |
| Simulation end | `2386ns` |
| Self-check milestones | 234 |
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
| `206ns-386ns` | Read local `misa`, `mstatus`, `dcsr`, and core-supplied `dpc`; set and clear `dcsr.step`; accept optional CSR probe writes as no-ops | local CSR reads update data0; DCSR writes update only the step bit; optional probe writes do not issue GPR requests | PASS |
| `386ns-546ns` | Directed Access Memory word read with postincrement, byte write, halfword read, and bus-error response | halted-core memory request fields, lane extraction, strobes, data0/data1 updates, and BUS cmderr match expectation | PASS |
| `546ns-706ns` | Transfer-disabled no-op and unsupported type/size/options/registers plus running-hart command | no-op succeeds; unsupported maps to NOTSUP; running maps to HALT_RESUME | PASS |
| `706ns-916ns` | Lose halted state in ISSUE/WAIT, deactivate DM in ISSUE/WAIT, inject busy command, reset active command | flush/error/abort priorities and captured fields remain correct | PASS |
| `916ns-2386ns` | Run 20 deterministic-random valid GPR commands with randomized issue/response delay and error injection | every decoded request and completion matches the reference model | PASS |

## 4. Functional Coverage Summary

| Coverage item | Count | Result |
| --- | ---: | --- |
| Self-check milestones | 234 | PASS |
| Read command classes | 13 | PASS |
| Write command classes | 16 | PASS |
| Local CSR read classes | 6 | PASS |
| Local CSR write classes | 3 | PASS |
| Memory read classes | 3 | PASS |
| Memory write classes | 1 | PASS |
| Transfer-disabled no-op | 1 | PASS |
| Unsupported encoding classes | 6 | PASS |
| Halt/resume errors | 3 | PASS |
| Downstream exception/bus errors | 5 | PASS |
| Issue backpressure cycles | 38 | PASS |
| Response wait cycles | 34 | PASS |
| Flush/abort classes | 4 | PASS |
| Busy command ignored | 1 | PASS |
| Reset-while-busy abort | 1 | PASS |
| Deterministic-random commands | 20 | PASS |

This milestone reports functional self-check coverage, not structural
code/toggle coverage.

## 5. Target Matrix

| Target | Command | Result |
| --- | --- | --- |
| Generic simulation | `make -C debug lint-abstract-cmd` | PASS |
| IC | `make -C debug lint-abstract-cmd-ic` | PASS |
| Xilinx Virtex-7 FPGA | `make -C debug lint-abstract-cmd-fpga-v7` | PASS |
| Functional simulation | `make -C debug sim-abstract-cmd` | PASS |

## 6. Residual Scope

The RV32 GPR Access Register decoder/controller, OpenOCD/GDB CSR probe path,
and physical Access Memory byte/half/word controller are verified against mock
GPR and memory transports. Program-buffer execution, System Bus Access, and
architectural CSR side effects beyond `dcsr.step` remain future work. Full
OpenOCD/GDB smoke is covered at the wasp1 top level.
