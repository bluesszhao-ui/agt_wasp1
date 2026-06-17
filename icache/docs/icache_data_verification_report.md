# icache_data Verification Report

## 1. Result

Status: PASS.

## 2. Testbench

```text
testbench: icache/tb/tb_icache_data.sv
filelist:  icache/filelists/tb_icache_data.f
target:    make -C icache sim-icache-data
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-30ns | Hold and release reset. | Data contents are ignored by the reference model. | PASS: no reset-dependent check required. |
| 30ns-80ns | Refill address A and read each word offset. | Full line and all word selects match. | PASS: line and word selects matched. |
| 80ns-120ns | Refill address C at another index. | Address C matches and address A remains intact. | PASS: index independence matched. |
| 120ns-150ns | Refill address B at same index as A. | New line replaces old line. | PASS: conflict replacement matched. |
| 150ns-170ns | Assert refill while looking up same index before the edge. | Old line remains visible before the edge. | PASS: pre-edge old data observed. |
| 170ns-190ns | Check same index after the write edge. | New line is visible. | PASS: post-edge new data observed. |
| 190ns-919ns | Run 140 deterministic-random operations. | Reference line array matches every lookup. | PASS: all random operations matched. |

## 4. Coverage Summary

```text
tb_icache_data coverage: pass_count=151 refill=78 lookup=74 word=4 conflict=1 random=140
tb_icache_data PASS
```

## 5. Commands

Executed:

```text
make -C icache lint
make -C icache sim-icache-data
```

Full milestone validation is tracked with the current commit:

```text
make -C icache lint-ic
make -C icache lint-fpga-v7
make -C icache sim
make lint
```
