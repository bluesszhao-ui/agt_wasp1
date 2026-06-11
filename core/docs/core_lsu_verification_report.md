# core_lsu Verification Report

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
| 0ns-1ns | Idle | No load/store requested | PASS |
| 1ns-11ns | Directed loads | Byte, halfword, word, signed/unsigned, misaligned loads | PASS |
| 11ns-20ns | Directed stores | Byte, halfword, word, shifted strobes, misaligned stores | PASS |
| 20ns-21ns | Response error | Assert response error | PASS |
| 21ns-121ns | Random | 100 deterministic random load/store checks | PASS |

## 4. Coverage Summary

```text
pass_count=121
load=10
store=9
misalign=5
sign=7
random=100
error=1
```

All planned cases passed.
