# icache_refill Verification Plan

## 1. Verification Scope

Verify start handshakes, line address alignment, downstream request encoding,
request backpressure, response latency, line assembly order, output
backpressure, response error aggregation, flush abort, and deterministic-random
refill timing.

## 2. Testbench

```text
testbench: icache/tb/tb_icache_refill.sv
filelist:  icache/filelists/tb_icache_refill.f
target:    make -C icache sim-icache-refill
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Normal refill | Refill one 16-byte line with no stalls and compare assembled line. |
| Request backpressure | Hold downstream `req_ready` low and verify request remains stable. |
| Response latency | Delay downstream responses and verify no early completion. |
| Output backpressure | Hold `line_ready_i` low and verify completed line remains stable. |
| Error aggregation | Inject an error on one response and verify `line_error_o`. |
| Flush abort | Flush after an accepted request and verify no completed line is produced. |
| Random timing | Run 20 deterministic-random refills with variable stalls and errors. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-30ns | Hold and release reset. | Refill controller is idle. |
| 30ns-120ns | Run normal aligned refill. | Four word reads complete one line with no error. |
| 120ns-360ns | Run refill with request/response/output backpressure. | Requests and completed line hold stable until accepted. |
| 360ns-460ns | Inject an error on beat 2. | Completed line has `line_error_o=1`. |
| 460ns-500ns | Start a refill and assert flush after first request. | Controller returns idle and no line completes. |
| 500ns-5000ns | Run 20 deterministic-random refills. | Reference line/error checks match every refill. |

## 5. Pass Criteria

Simulation must finish with `tb_icache_refill PASS`, all self-checks passing,
and minimum counters for starts, requests, responses, completions, errors,
flush, backpressure, and random coverage.
