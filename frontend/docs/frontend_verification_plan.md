# frontend Verification Plan

## 1. Verification Scope

Verify the integrated `frontend_pc -> frontend_fetch -> frontend_ibuf` path as
one first-level frontend module. The scope covers reset PC generation,
instruction-memory request encoding, fetch response buffering, core-side
backpressure, full-buffer response backpressure, redirect flush, misaligned
redirect fault generation, stall behavior, memory error propagation, and
deterministic-random response delays.

## 2. Testbench

```text
testbench: frontend/tb/tb_frontend.sv
filelist:  frontend/filelists/tb_frontend.f
target:    make -C frontend sim-frontend
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Reset | Hold reset and verify no instruction response is visible. |
| Boot PC | Release reset and check first instruction request uses `boot_pc_i`. |
| Request encoding | Check read-only word instruction request fields on every accepted fetch. |
| Fetch-to-ibuf path | Deliver memory response and pop matching PC/instruction from the core side. |
| Core backpressure | Hold `instr_ready_i` low and verify the ibuf holds the oldest entry. |
| Full-buffer response stall | Fill the ibuf and verify an outstanding fetch response waits for space. |
| Redirect flush | Flush an outstanding request and verify stale memory response is dropped. |
| Misaligned redirect | Redirect to an unaligned PC and verify local fault response. |
| Stall | Assert `stall_i` and verify new memory requests are suppressed. |
| Memory error | Return `rsp_err` and verify `instr_fault_o` is set. |
| Random latency | Run 24 deterministic-random fetches with variable response/pop delays. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-20ns | Hold reset active. | No instruction response is visible. |
| 20ns-40ns | Release reset and fetch boot PC. | Request address is `0x00001000`; response pops with matching data. |
| 40ns-110ns | Fill ibuf with two responses and hold core ready low. | Oldest entry remains visible; second entry is retained. |
| 110ns-150ns | Issue one more request while ibuf is full and return its response. | Memory response waits until one ibuf entry is popped. |
| 150ns-180ns | Pop retained and delayed entries. | FIFO order is preserved. |
| 180ns-210ns | Accept request, assert redirect, and return stale response. | Stale response is consumed and not delivered. |
| 210ns-240ns | Redirect to misaligned PC. | Local misaligned fault is buffered and popped. |
| 240ns-260ns | Redirect to aligned PC and assert stall. | No new memory request is issued while stalled. |
| 260ns-330ns | Fetch with memory error. | Core-side response has `instr_fault_o=1`. |
| 330ns-end | Run 24 deterministic-random fetches. | Request/response/pop checks match expected PC/data. |

## 5. Pass Criteria

Simulation must finish with `tb_frontend PASS`, all self-checks passing, and
minimum counters for request, response, pop, backpressure, redirect,
misalignment, stall, memory error, and random coverage.
