# icache_tag Verification Plan

## 1. Verification Scope

Verify reset, lookup hit/miss behavior, index decoding, refill update, refill
error invalid behavior, conflict replacement, invalidate priority, and
deterministic-random lookup/refill/invalidate traffic.

## 2. Testbench

```text
testbench: icache/tb/tb_icache_tag.sv
filelist:  icache/filelists/tb_icache_tag.f
target:    make -C icache sim-icache-tag
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Reset | Check lookup misses during and after reset. |
| Refill hit | Refill a line and check lookup hit. |
| Same-line offset | Check a different word offset in the same line still hits. |
| Different-index miss | Lookup an unfilled index. |
| Refill error | Issue failed refill and check the line remains invalid. |
| Conflict replacement | Refill same index with a different tag and check old tag misses/new tag hits. |
| Invalidate | Clear valid bits and check previous hit misses. |
| Random traffic | Run 120 deterministic-random lookup/refill/error/invalidate operations. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-20ns | Hold reset active. | Lookup misses. |
| 20ns-30ns | Release reset. | Lookup still misses. |
| 30ns-60ns | Refill address A and lookup same line. | Address A hits, same-line offset hits. |
| 60ns-90ns | Lookup/refill address C with error. | Address C misses after failed refill. |
| 90ns-110ns | Refill address C without error. | Address C hits. |
| 110ns-150ns | Refill address B at same index as A. | A misses and B hits. |
| 150ns-170ns | Invalidate all lines. | Previously valid line misses. |
| 170ns-877ns | Run 120 deterministic-random operations. | Reference model matches every lookup. |

## 5. Pass Criteria

Simulation must finish with `tb_icache_tag PASS`, all self-checks passing, and
minimum counters for lookup, hit, miss, refill, error, conflict, invalidate, and
random coverage.
