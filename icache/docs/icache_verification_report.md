# icache Verification Report

## 1. Result

```text
Command: make -C icache sim-icache
Result : PASS
```

Simulation summary:

```text
TB_ICACHE PASS pass=463 miss=26 hit=23 conflict=1 invalidate=1 error=5 flush=1 backpressure=107 mem_req=105 mem_rsp=104 random=16
```

Lint summary:

```text
Command: make -C icache lint
Result : PASS
```

## 2. Time-Sequenced Action Table

| Time | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-60ns | Reset cache, frontend model, and downstream memory model | Cache idle, no valid outputs | PASS |
| 60ns-210ns | Basic miss at `0x1008` | Four word reads, response data from refill line | PASS |
| 210ns-280ns | Same address and same-line fetches | Cache hits with no downstream request | PASS |
| 280ns-530ns | Miss/hit with downstream and frontend backpressure | Valid/address/data held stable | PASS |
| 530ns-930ns | Direct-mapped conflict replacement | New line replaces old index; old line misses again | PASS |
| 930ns-1050ns | Invalid request classes | Error responses, no downstream reads | PASS |
| 1050ns-1320ns | Refill error and recovery refill | Failed line remains invalid, later refill hits | PASS |
| 1320ns-1650ns | Invalidate after fill | Next access misses and refills | PASS |
| 1650ns-1880ns | Flush during active refill | No stale response; later fetch refills normally | PASS |
| 1880ns-6000ns | 16 deterministic-random fill/hit pairs | All randomized addresses and stalls pass | PASS |

## 3. Coverage Summary

| Coverage Item | Status |
| --- | --- |
| Integrated miss/refill path | Covered |
| Integrated hit path | Covered |
| Same-line word select | Covered |
| Conflict replacement | Covered |
| Invalid request fault | Covered |
| Refill error propagation | Covered |
| Tag invalidation | Covered |
| Flush abort recovery | Covered |
| Downstream backpressure | Covered |
| Frontend response backpressure | Covered |
| Deterministic random traffic | Covered |

## 4. Residual Risk

The integrated cache is verified at module level with an abstract downstream
memory model. Later `tile` and SoC integration must still verify interaction
with the real bus bridge, reset/debug flows, and frontend pipeline timing.
