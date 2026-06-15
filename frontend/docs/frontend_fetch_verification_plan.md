# frontend_fetch Verification Plan

## 1. Verification Scope

Verify request encoding, one-outstanding response tracking, response
backpressure, misaligned local fault generation, flush/drop behavior, memory
error propagation, and deterministic-random request/response handshakes.

## 2. Testbench

```text
testbench: frontend/tb/tb_frontend_fetch.sv
filelist:  frontend/filelists/tb_frontend_fetch.f
target:    make -C frontend sim-frontend-fetch
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Coverage Goals

| Goal | Method |
| --- | --- |
| Reset | Check no instruction response during reset. |
| Request encoding | Accept aligned PC and check read-only word instruction request fields. |
| Normal response | Return memory data with associated PC. |
| Response backpressure | Hold response when consumer is not ready. |
| Misaligned PC | Generate local fault and suppress memory request. |
| Flush drop | Mark outstanding request killed and drop later response. |
| Memory error | Propagate `rsp_err` to `instr_fault_o`. |
| Random handshakes | Run 40 deterministic-random request/response transactions. |

## 4. Time-Sequenced Case Plan

| Time window | Action | Expected result |
| --- | --- | --- |
| 0ns-20ns | Hold reset active. | No instruction response. |
| 20ns-50ns | Accept aligned request and deliver response. | Request fields match; response PC/data/fault match. |
| 50ns-90ns | Deliver response while consumer not ready. | Response holds until ready. |
| 90ns-100ns | Drive misaligned PC. | Local fault response, no memory request. |
| 100ns-140ns | Accept request, assert flush, then return memory response. | Response is consumed and not delivered. |
| 140ns-170ns | Accept request with memory error response. | `instr_fault_o` asserts with response data/PC. |
| 170ns-end | Run 40 random request/response transactions. | Reference checks match every transaction. |

## 5. Pass Criteria

Simulation must finish with `tb_frontend_fetch PASS`, all self-checks passing,
and minimum counters for request, response, backpressure, misalignment, flush,
error, and random coverage.
