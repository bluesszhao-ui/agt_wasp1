# core_branch Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim
```

## 3. Time/Cycle Action Table

| Time | Cycle Window | Action | Result |
| --- | --- | --- | --- |
| 0ns-1ns | Idle | No branch or jump, check fall-through | PASS |
| 1ns-13ns | Branch pairs | Check taken/not-taken cases for all branch ops | PASS |
| 13ns-17ns | Jumps | Check forward/backward JAL and JALR bit clearing | PASS |
| 17ns-19ns | Priority | Check JAL and JALR priority over branch | PASS |
| 19ns-119ns | Random | 100 deterministic random branch comparisons | PASS |

## 4. Coverage Summary

```text
pass_count=119
branch_taken=6
branch_not_taken=6
signed=2
unsigned=2
jump=4
priority=2
random=100
```

All planned cases passed.
