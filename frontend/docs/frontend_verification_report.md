# frontend Verification Report

## 1. Result

Status: PASS.

## 2. Testbench

```text
testbench: frontend/tb/tb_frontend.sv
filelist:  frontend/filelists/tb_frontend.f
target:    make -C frontend sim-frontend
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset active. | No instruction response is visible. | PASS: no response observed. |
| 20ns-40ns | Release reset and fetch boot PC. | Request address is `0x00001000`; response pops with matching data. | PASS: boot fetch matched. |
| 40ns-110ns | Fill ibuf with two responses and hold core ready low. | Oldest entry remains visible; second entry is retained. | PASS: ibuf hold matched. |
| 110ns-150ns | Issue one more request while ibuf is full and return its response. | Memory response waits until one ibuf entry is popped. | PASS: response backpressure matched. |
| 150ns-180ns | Pop retained and delayed entries. | FIFO order is preserved. | PASS: FIFO order matched. |
| 180ns-210ns | Accept request, assert redirect, and return stale response. | Stale response is consumed and not delivered. | PASS: redirect flush matched. |
| 210ns-240ns | Redirect to misaligned PC. | Local misaligned fault is buffered and popped. | PASS: misaligned fault matched. |
| 240ns-260ns | Redirect to aligned PC and assert stall. | No new memory request is issued while stalled. | PASS: stall suppressed request. |
| 260ns-330ns | Fetch with memory error. | Core-side response has `instr_fault_o=1`. | PASS: memory error propagated. |
| 330ns-2000ns | Run 24 deterministic-random fetches. | Request/response/pop checks match expected PC/data. | PASS: all random fetches matched. |

## 4. Coverage Summary

```text
tb_frontend coverage: pass_count=175 req=30 rsp=29 pop=30 backpressure=41 redirect=2 misalign=1 stall=1 err=1 random=24
tb_frontend PASS
```

## 5. Commands

Executed:

```text
make -C frontend lint
make -C frontend sim-frontend
```

Full milestone validation is tracked with the current commit:

```text
make -C frontend lint-ic
make -C frontend lint-fpga-v7
make -C frontend sim
make lint
```
