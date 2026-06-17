# dcache_refill Verification Report

## 1. Result

```text
Command: make -C dcache sim-dcache-refill
Result : PASS
```

Simulation summary:

```text
tb_dcache_refill coverage: pass_count=541 start=24 req=93 rsp=92 done=23 err=12 flush=1 backpressure=176 random=20
tb_dcache_refill PASS
```

Lint summary:

```text
Command: make -C dcache lint
Result : PASS
```

## 2. Time-Sequenced Action Table

| Time | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-30ns | Reset release | Refill idle, no memory request | PASS |
| 30ns-150ns | Normal refill | Four data word reads, aligned line output | PASS |
| 150ns-420ns | Request/response/output backpressure refill | Valid/address/data held stable | PASS |
| 420ns-560ns | Refill with error on one beat | Completed line has sticky error | PASS |
| 560ns-620ns | Flush after first request | Outputs suppressed, no line completion | PASS |
| 620ns-5000ns | 20 deterministic-random refills | Random stalls/errors match reference model | PASS |

## 3. Coverage Summary

| Coverage Item | Status |
| --- | --- |
| Start handshake | Covered |
| Line address alignment | Covered |
| Data read request encoding | Covered |
| `req_instr=0` data access marking | Covered |
| One request per line word | Covered |
| Response line assembly | Covered |
| Sticky error accumulation | Covered |
| Request backpressure | Covered |
| Response wait states | Covered |
| Completed-line backpressure | Covered |
| Flush abort | Covered |
| Deterministic random stream | Covered |

## 4. Residual Risk

`dcache_refill` is verified as a standalone leaf with a downstream memory model.
Later `dcache_ctrl` and top-level D-cache integration must verify that only load
misses start allocation refills and that store misses use the store path
instead.
