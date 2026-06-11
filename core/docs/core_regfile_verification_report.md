# core_regfile Verification Report

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
| 0ns-35ns | Reset | Assert reset and initialize bench model | PASS |
| 35ns-51ns | Reset reads | Read all 32 logical registers | PASS |
| 55ns-85ns | x0 case | Attempt write to `x0` and read it back | PASS |
| 85ns-145ns | Directed writes | Write and read `x1`, `x2`, and `x31` | PASS |
| 145ns-165ns | Dual read | Read two written registers at once | PASS |
| 165ns-185ns | Bypass | Read `x7` while writing it | PASS |
| 185ns-418ns | Random | 32 deterministic random write/read checks | PASS |

## 4. Coverage Summary

```text
pass_count=88
reset_checks=32
write_checks=36
x0_checks=2
bypass_checks=1
random_checks=32
```

All planned cases passed.
