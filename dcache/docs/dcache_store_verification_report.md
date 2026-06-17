# dcache_store Verification Report

## 1. Scope

`tb_dcache_store` verifies `dcache_store` as a self-checking module-level
testbench with a modeled downstream memory interface.

## 2. Test Environment

```text
tool: Verilator --binary --timing
timescale: 1ns/1ps
clock period: 10ns
clock frequency: 100MHz
top: tb_dcache_store
```

## 3. Time-Sequenced Case Table

| Time Window | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset active | FSM idle, no request or completion | PASS |
| 20ns-30ns | Release reset | `start_ready_o` available in idle | PASS |
| 30ns-70ns | Byte store with no stalls | One data write request, response, and clean completion | PASS |
| 70ns-160ns | Halfword store with request/response/done backpressure | Request and completion payload remain stable | PASS |
| 160ns-200ns | Word store with downstream error | `done_error_o` reports error | PASS |
| 200ns-270ns | Zero-strobe passthrough store | Downstream request preserves zero strobe | PASS |
| 270ns-310ns | Flush after accepted request before response | Active transaction aborts, no done emitted | PASS |
| 310ns-end | 32 deterministic-random stores | Sizes, strobes, stalls, and errors match reference expectations | PASS |

## 4. Coverage Summary

The passing simulation reported:

```text
tb_dcache_store coverage: pass_count=280 start=37 req=37 rsp=36 done=36 err=14 flush=1 backpressure=88 random=32 byte=11 half=9 word=17
```

Coverage goals:

```text
accepted starts
downstream requests
downstream responses
completion handshakes
request and completion backpressure
error responses
flush abort
byte/halfword/word stores
zero-strobe passthrough
deterministic-random streams
```

## 5. Result

Result is PASS.
