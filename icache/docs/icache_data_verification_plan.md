# icache_data Verification Plan

## 1. Verification Scope

Verify line refill writes, lookup index decode, full-line readback, word-offset
selection, different-index independence, same-index replacement, write visibility
after the clock edge, and deterministic-random refill/lookup traffic.

## 2. Testbench

```text
testbench: icache/tb/tb_icache_data.sv
filelist:  icache/filelists/tb_icache_data.f
target:    make -C icache sim-icache-data
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Refill write | Write a complete line and read it back. |
| Word select | Check all four 32-bit word offsets in a 16-byte line. |
| Index independence | Refill a second index and verify the first index is intact. |
| Conflict replacement | Refill the same index with a new line and verify replacement. |
| Write timing | Check old data before the refill edge and new data after the edge. |
| Random traffic | Run 140 deterministic-random lookup/refill operations. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-30ns | Hold and release reset. | Data contents are ignored by the reference model. |
| 30ns-80ns | Refill address A and read each word offset. | Full line and all word selects match. |
| 80ns-120ns | Refill address C at another index. | Address C matches and address A remains intact. |
| 120ns-150ns | Refill address B at same index as A. | New line replaces old line. |
| 150ns-170ns | Assert refill while looking up same index before the edge. | Old line remains visible before the edge. |
| 170ns-190ns | Check same index after the write edge. | New line is visible. |
| 190ns-919ns | Run 140 deterministic-random operations. | Reference line array matches every lookup. |

## 5. Pass Criteria

Simulation must finish with `tb_icache_data PASS`, all self-checks passing, and
minimum counters for refill, lookup, word-select, conflict, and random coverage.
