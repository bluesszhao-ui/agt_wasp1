# core_alu Verification Report

## 1. Run Summary

| Item | Result |
| --- | --- |
| Date | 2026-06-11 |
| Tool | Verilator 5.046 |
| Lint command | `make -C core lint` |
| IC lint command | `make -C core lint-ic` |
| FPGA lint command | `make -C core lint-fpga-v7` |
| Simulation command | `make -C core sim` |
| Lint result | PASS |
| Target lint result | PASS for generic, IC, and Xilinx Virtex-7 FPGA macro builds |
| Simulation result | PASS |
| Self-check count | 217 |
| Lint log | `core/logs/lint.log` |
| Simulation log | `core/logs/tb_core_alu.log` |

## 2. Timebase

```text
timescale = 1ns/1ps
combinational checks use 1ns settle steps
```

## 3. Case Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| Directed | ADD small and wraparound operands | Result matches 32-bit addition | PASS |
| Directed | SUB underflow and edge operands | Result matches 32-bit subtraction | PASS |
| Directed | SLL with shamt 31 and masked shamt | Result uses `rhs[4:0]` | PASS |
| Directed | SLT signed positive/negative cases | Signed compare result correct | PASS |
| Directed | SLTU unsigned high/low cases | Unsigned compare result correct | PASS |
| Directed | XOR/OR/AND pattern operands | Bitwise result correct | PASS |
| Directed | SRL/SRA positive and negative operands | Logical and arithmetic shifts differ correctly | PASS |
| Random | 200 deterministic random op/operand checks | Result matches reference model | PASS |
| Directed | Invalid op encoding | Result is zero | PASS |

## 4. Functional Coverage Summary

| Coverage item | Result |
| --- | --- |
| Total self-checks | 217 |
| Directed edge checks | 16 |
| Signed-specific checks | 4 |
| Deterministic random checks | 200 |
| Per-op hits | ADD 27, SUB 19, SLL 19, SLT 22, SLTU 17, XOR 23, SRL 19, SRA 27, OR 23, AND 20 |

## 5. Target Compile Matrix

| Target | Macro | Command | Result |
| --- | --- | --- | --- |
| Generic simulation | `WASP1_TARGET_SIM_GENERIC` by default | `make -C core lint` | PASS |
| IC | `WASP1_TARGET_IC` | `make -C core lint-ic` | PASS |
| Xilinx Virtex-7 FPGA | `WASP1_TARGET_FPGA_XILINX_VIRTEX7` | `make -C core lint-fpga-v7` | PASS |
