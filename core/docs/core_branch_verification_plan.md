# core_branch Verification Plan

## 1. Strategy

`tb_core_branch` is a self-checking SystemVerilog testbench with a reference
branch comparator.

The testbench uses 1ns combinational settle steps because `core_branch` has no
clocked state.

## 2. Planned Cases

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Idle | No branch or jump | Fall through to `pc + 4` |
| Branch pairs | Taken and not-taken form for every branch op | Correct `taken_o` and target |
| Signed compares | Negative/positive BLT/BGE cases | Signed interpretation used |
| Unsigned compares | High-bit BLTU/BGEU cases | Unsigned interpretation used |
| JAL | Forward and backward PC-relative jumps | Target is `pc + imm` |
| JALR | Odd and wraparound targets | Target bit zero is clear |
| Priority | Multiple control-flow flags asserted | JAL then JALR priority |
| Random branches | Deterministic random branch comparisons | RTL matches reference model |

## 3. Coverage Goals

The bench must cover at least 6 taken branches, 6 not-taken branches, 2 signed
edge cases, 2 unsigned edge cases, 4 jump cases, 2 priority cases, and 100
random branch cases.
