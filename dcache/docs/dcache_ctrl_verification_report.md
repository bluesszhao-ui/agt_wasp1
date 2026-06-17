# dcache_ctrl Verification Report

## 1. Result

```text
Command: make -C dcache sim-dcache-ctrl
Result : PASS
```

Simulation summary:

```text
tb_dcache_ctrl coverage: pass_count=232 load_hit=12 load_miss=9 store_hit=8 store_miss=6 invalid=12 refill_start=10 refill_update=9 store_start=15 store_update=4 err=22 flush=2 backpressure=86 random=32
```

Lint summary:

```text
Command: make -C dcache lint
Result : PASS
```

## 2. Time-Sequenced Action Table

| Time | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-50ns | Apply reset and initialize core/refill/store models | Controller idle, no valid outputs | PASS |
| 50ns-140ns | Word/byte/halfword load hits | Responses equal mocked cached word | PASS |
| 140ns-300ns | Load misses with refill completion | Refill start, tag/data update, selected word response | PASS |
| 300ns-380ns | Load miss with refill error | Response error asserted and tag refill error asserted | PASS |
| 380ns-520ns | Store hit and store hit with backpressure | Store starts, successful hit updates cached data | PASS |
| 520ns-610ns | Store miss | Store starts, no allocation or data update | PASS |
| 610ns-700ns | Store hit with downstream error | Response error asserted, no data update | PASS |
| 700ns-850ns | Invalid instruction/size/alignment requests | Error response, no refill/store/update pulse | PASS |
| 850ns-960ns | Flush active load miss and active store | Active work aborted, no response/update emitted | PASS |
| 960ns-990ns | Post-flush load hit | Controller accepts new request normally | PASS |
| 990ns-2600ns | 32 deterministic-random transactions | Mixed load/store/invalid/error/backpressure cases pass | PASS |

## 3. Coverage Summary

| Coverage Item | Status |
| --- | --- |
| Load hit path | Covered |
| Load miss refill path | Covered |
| Load refill error path | Covered |
| Store hit write-through path | Covered |
| Store miss no-write-allocate path | Covered |
| Store downstream error path | Covered |
| Store-hit data update pulse | Covered |
| Invalid request path | Covered |
| Refill and store flush abort paths | Covered |
| Core response backpressure | Covered |
| Refill/store start backpressure | Covered |
| Deterministic random mix | Covered |

## 4. Residual Risk

`dcache_ctrl` is verified as a leaf using mock tag/data/refill/store models.
Full D-cache integration will verify that real `dcache_tag`, `dcache_data`,
`dcache_refill`, and `dcache_store` instances connect without timing or ordering
mismatches.
