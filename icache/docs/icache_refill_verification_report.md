# icache_refill Verification Report

## 1. Result

Status: PASS.

## 2. Testbench

```text
testbench: icache/tb/tb_icache_refill.sv
filelist:  icache/filelists/tb_icache_refill.f
target:    make -C icache sim-icache-refill
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-30ns | Hold and release reset. | Refill controller is idle. | PASS: controller accepted first start after reset. |
| 30ns-120ns | Run normal aligned refill. | Four word reads complete one line with no error. | PASS: line data and address matched. |
| 120ns-360ns | Run refill with request/response/output backpressure. | Requests and completed line hold stable until accepted. | PASS: backpressure behavior matched. |
| 360ns-460ns | Inject an error on beat 2. | Completed line has `line_error_o=1`. | PASS: error was accumulated. |
| 460ns-500ns | Start a refill and assert flush after first request. | Controller returns idle and no line completes. | PASS: flush suppressed outputs. |
| 500ns-5000ns | Run 20 deterministic-random refills. | Reference line/error checks match every refill. | PASS: all random refills matched. |

## 4. Coverage Summary

```text
tb_icache_refill coverage: pass_count=541 start=24 req=93 rsp=92 done=23 err=12 flush=1 backpressure=176 random=20
tb_icache_refill PASS
```

## 5. Commands

Executed:

```text
make -C icache lint
make -C icache sim-icache-refill
```

Full milestone validation is tracked with the current commit:

```text
make -C icache lint-ic
make -C icache lint-fpga-v7
make -C icache sim
make lint
```
