# core_debug_ctrl Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```sh
make -C core sim-core-debug-ctrl
make -C core lint
make -C core lint-ic
make -C core lint-fpga-v7
make -C core sim
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-31ns | Reset and establish running baseline. | Running asserted, halted/freeze/stop deasserted. | PASS |
| 31ns-71ns | Assert halt while pipe idle. | Fetch stop asserts immediately, halted next cycle. | PASS |
| 71ns-131ns | Assert halt while pipe not idle, then drain. | Halt-pending has stop without freeze, then halted after idle. | PASS |
| 131ns-191ns | Assert trigger while pipe not idle, then drain. | Fetch stop asserts immediately, halt-pending drains, then halted. | PASS |
| 191ns-251ns | Cancel halt-pending with resume. | Controller returns running without halted pulse. | PASS |
| 251ns-331ns | Resume while debug busy, then clear busy. | Resume blocked while busy, then running after busy clears. | PASS |
| 331ns-391ns | Single-step from halted. | Running during step, halt-pending after retire, halted after drain. | PASS |
| 391ns-416ns | Assert halt/resume/step together while halted. | Halt priority keeps halted/frozen. | PASS |

## 4. Coverage Summary

```text
tb_core_debug_ctrl coverage: pass=18 halt=6 resume=1 step=1 busy=1 cancel=1 priority=1 trigger=1
tb_core_debug_ctrl PASS
```

All planned directed paths reached their coverage goals.
