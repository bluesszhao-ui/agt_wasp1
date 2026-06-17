# icache_tag Verification Report

## 1. Result

Status: PASS.

## 2. Testbench

```text
testbench: icache/tb/tb_icache_tag.sv
filelist:  icache/filelists/tb_icache_tag.f
target:    make -C icache sim-icache-tag
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset active. | Lookup misses. | PASS: reset lookup missed. |
| 20ns-30ns | Release reset. | Lookup still misses. | PASS: reset release lookup missed. |
| 30ns-60ns | Refill address A and lookup same line. | Address A hits, same-line offset hits. | PASS: refill and offset hit matched. |
| 60ns-90ns | Lookup/refill address C with error. | Address C misses after failed refill. | PASS: failed refill stayed invalid. |
| 90ns-110ns | Refill address C without error. | Address C hits. | PASS: successful refill hit. |
| 110ns-150ns | Refill address B at same index as A. | A misses and B hits. | PASS: conflict replacement matched. |
| 150ns-170ns | Invalidate all lines. | Previously valid line misses. | PASS: invalidate cleared valid bits. |
| 170ns-877ns | Run 120 deterministic-random operations. | Reference model matches every lookup. | PASS: all random operations matched. |

## 4. Coverage Summary

```text
tb_icache_tag coverage: pass_count=154 lookup=131 hit=47 miss=84 refill=45 err=12 conflict=1 invalidate=23 random=120
tb_icache_tag PASS
```

## 5. Commands

Executed:

```text
make -C icache lint
make -C icache sim-icache-tag
```

Full milestone validation is tracked with the current commit:

```text
make -C icache lint-ic
make -C icache lint-fpga-v7
make lint
```
