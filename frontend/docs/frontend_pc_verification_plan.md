# frontend_pc Verification Plan

## 1. Verification Scope

Verify reset loading, request valid generation, sequential advance, backpressure
hold, stall behavior, redirect priority, misalignment reporting, and
deterministic-random priority combinations.

## 2. Testbench

```text
testbench: frontend/tb/tb_frontend_pc.sv
filelist:  frontend/filelists/tb_frontend_pc.f
target:    make -C frontend sim-frontend-pc
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Reset | Hold reset for two cycles and check boot PC with invalid request. |
| Reset release | Check valid becomes high after reset release. |
| Sequential advance | Assert ready and check `pc + 4`. |
| Ready hold | Deassert ready and check PC hold. |
| Stall hold | Assert stall and check `pc_valid_o=0` and PC hold. |
| Redirect | Assert redirect and check target capture. |
| Redirect priority | Assert redirect with ready and check redirect wins. |
| Redirect during stall | Assert redirect while stalled and check target capture. |
| Misalignment | Redirect to an unaligned target and check flag. |
| Random priority | Run 100 deterministic-random ready/stall/redirect cycles. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-20ns | Hold reset active. | `pc_o=boot_pc_i`, `pc_valid_o=0`. |
| 20ns-30ns | Release reset. | `pc_valid_o=1`, PC still boot PC. |
| 30ns-50ns | Assert ready for two accepted fetches. | PC advances by 4 each cycle. |
| 50ns-60ns | Deassert ready. | PC holds with valid high. |
| 60ns-70ns | Assert stall and ready. | PC holds and valid deasserts. |
| 70ns-80ns | Redirect while stalled. | Redirect target is captured. |
| 80ns-90ns | Release stall and ready high. | PC advances from redirected target. |
| 90ns-100ns | Redirect to misaligned target. | Misaligned flag asserts. |
| 100ns-110ns | Redirect while ready is high. | Redirect wins over sequential advance. |
| 110ns-1110ns | Random ready/stall/redirect combinations. | Model and DUT stay matched. |

## 5. Pass Criteria

Simulation must finish with `tb_frontend_pc PASS`, all self-checks passing, and
minimum coverage counters for reset, advance, hold, stall, redirect,
misalignment, and random tests.
