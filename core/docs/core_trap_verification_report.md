# core_trap Verification Report

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
| 0ns-1ns | Idle | No trap, MRET, or IRQ | PASS |
| 1ns-8ns | Synchronous traps | Check all supported synchronous traps | PASS |
| 8ns-9ns | MRET | Check MRET redirect to `mepc_i` | PASS |
| 9ns-12ns | Interrupts | Check timer, external, and IRQ priority | PASS |
| 12ns-17ns | Masking and priority | Check masked IRQ, valid gating, sync/MRET/IRQ priority | PASS |

## 4. Coverage Summary

```text
pass_count=17
sync=7
irq=3
mret=1
priority=3
masked=3
```

All planned cases passed.
