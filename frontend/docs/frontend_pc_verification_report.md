# frontend_pc Verification Report

## 1. Result

Status: PASS.

## 2. Testbench

```text
testbench: frontend/tb/tb_frontend_pc.sv
filelist:  frontend/filelists/tb_frontend_pc.f
target:    make -C frontend sim-frontend-pc
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset active. | `pc_o=boot_pc_i`, `pc_valid_o=0`. | PASS: reset PC and invalid request matched. |
| 20ns-30ns | Release reset. | `pc_valid_o=1`, PC still boot PC. | PASS: valid asserted after reset release. |
| 30ns-50ns | Assert ready for two accepted fetches. | PC advances by 4 each cycle. | PASS: sequential advance matched. |
| 50ns-60ns | Deassert ready. | PC holds with valid high. | PASS: ready-low hold matched. |
| 60ns-70ns | Assert stall and ready. | PC holds and valid deasserts. | PASS: stall blocked valid and advance. |
| 70ns-80ns | Redirect while stalled. | Redirect target is captured. | PASS: redirect captured during stall. |
| 80ns-90ns | Release stall and ready high. | PC advances from redirected target. | PASS: post-redirect advance matched. |
| 90ns-100ns | Redirect to misaligned target. | Misaligned flag asserts. | PASS: misaligned flag asserted. |
| 100ns-110ns | Redirect while ready is high. | Redirect wins over sequential advance. | PASS: redirect priority matched. |
| 110ns-1110ns | Random ready/stall/redirect combinations. | Model and DUT stay matched. | PASS: 100 deterministic-random cycles matched. |

## 4. Coverage Summary

```text
tb_frontend_pc coverage: pass_count=110 reset=2 advance=3 hold=1 stall=1 redirect=3 misalign=1 random=100
tb_frontend_pc PASS
```

## 5. Commands

Executed:

```text
make -C frontend lint
make -C frontend sim-frontend-pc
```

Target macro lint is tracked with the current commit validation:

```text
make -C frontend lint-ic
make -C frontend lint-fpga-v7
```
