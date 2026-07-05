# dcache Verification Report

## 1. Result

```text
Command: make -C dcache sim-dcache
Result : PASS
```

Simulation summary:

```text
tb_dcache coverage: pass_count=529 load_miss=22 load_hit=34 store_hit=15 store_miss=1 store_update=14 conflict=1 invalidate=1 err=6 flush=2 uncached=5 backpressure=99 mem_req=111 mem_rsp=109 random=12
```

Lint summary:

```text
Command: make -C dcache lint
Result : PASS
```

## 2. Time-Sequenced Action Table

| Time | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-60ns | Apply reset and initialize core/downstream memory models | Cache idle, no request or response | PASS |
| 60ns-250ns | Basic load miss followed by same-word and same-line hits | Refill issues four reads; later loads hit | PASS |
| 250ns-430ns | Store-hit word and byte writes | Downstream writes occur; later load hits return merged data | PASS |
| 430ns-610ns | Store miss followed by load to same address | Store does not allocate; later load refills stored value | PASS |
| 610ns-760ns | Store-hit downstream error | Core sees error and cached word remains old value | PASS |
| 760ns-1060ns | Conflict replacement sequence | New line replaces old direct-mapped index; old line misses | PASS |
| 1060ns-1220ns | Invalid instruction/size/alignment requests | Error response only; no downstream request | PASS |
| 1220ns-1420ns | Refill error and recovery refill | Failed line remains invalid; next load refills successfully | PASS |
| 1420ns-1700ns | Invalidate after a filled line | Previously hit line misses and refills after invalidate | PASS |
| 1700ns-1850ns | Flush active load miss and active store | Active work aborts without response/update | PASS |
| 1850ns-2200ns | Uncached MMIO reads/writes | Repeated reads to the same INTC and OTP-register addresses both issue downstream requests and may return different data; write passes address/data/strobes without cache update | PASS |
| 2200ns-8000ns | 12 deterministic-random fill/hit/store-hit streams | Reference memory/cache expectations match DUT | PASS |

## 3. Coverage Summary

| Coverage Item | Status |
| --- | --- |
| Integrated load miss/refill path | Covered |
| Integrated load hit path | Covered |
| Store hit write-through and cache merge | Covered |
| Store miss no-write-allocate | Covered |
| Store downstream error | Covered |
| Direct-mapped conflict replacement | Covered |
| Invalidate forwarding | Covered |
| Refill error and recovery | Covered |
| Load/store flush abort paths | Covered |
| Uncached MMIO load/store bypass | Covered |
| Downstream request/response backpressure | Covered |
| Core response backpressure | Covered |
| Deterministic random integrated stream | Covered |

## 4. Residual Risk

`dcache` is verified with a self-checking downstream memory model. Later `tile`
and SoC integration will verify interaction with the real core pipeline, I-cache,
and AHB-facing memory path.
