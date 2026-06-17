# icache_ctrl Verification Report

## 1. Result

```text
Command: make -C icache sim-icache-ctrl
Result : PASS
```

Simulation summary:

```text
TB_ICACHE_CTRL PASS pass=162 hits=8 misses=15 invalid=11 refill_starts=16 updates=15 errors=19 flushes=1 backpressure=61 random=24
```

Lint summary:

```text
Command: make -C icache lint
Result : PASS
```

## 2. Time-Sequenced Action Table

| Time | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-50ns | Apply reset and initialize frontend/refill models | Controller idle, no valid outputs | PASS |
| 50ns-80ns | Basic hit request | Response data equals hit word, error clear | PASS |
| 80ns-150ns | Hit with response backpressure | Response remains stable while ready is low | PASS |
| 150ns-240ns | Invalid write/size/alignment/instruction cases begin | Each invalid request returns error | PASS |
| 240ns-360ns | Remaining invalid request cases | No refill start or tag/data update | PASS |
| 360ns-430ns | Basic miss and refill completion | Refill start, tag/data update, selected word response | PASS |
| 430ns-560ns | Miss with refill-start and response backpressure | Refill start and response are held stable | PASS |
| 560ns-660ns | Miss with refill error | Tag update error and frontend response error asserted | PASS |
| 660ns-730ns | Flush active miss after refill start | Active work aborted, no response/update | PASS |
| 730ns-760ns | Post-flush hit request | Controller accepts new request normally | PASS |
| 760ns-2000ns | 24 deterministic-random transactions | Mixed hit/miss/invalid/error/backpressure cases pass | PASS |

## 3. Coverage Summary

| Coverage Item | Status |
| --- | --- |
| Hit path | Covered |
| Miss/refill path | Covered |
| Invalid request path | Covered |
| Refill error path | Covered |
| Flush abort path | Covered |
| Frontend response backpressure | Covered |
| Refill start backpressure | Covered |
| Tag/data update pulse | Covered |
| Deterministic random mix | Covered |

## 4. Residual Risk

`icache_ctrl` is verified as a leaf using mock tag/data/refill models. Full
cache integration will verify that real `icache_tag`, `icache_data`, and
`icache_refill` instances connect without timing or ordering mismatches.
