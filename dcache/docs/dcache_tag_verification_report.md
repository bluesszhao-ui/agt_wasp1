# dcache_tag Verification Report

## 1. Result

```text
Command: make -C dcache sim-dcache-tag
Result : PASS
```

Simulation summary:

```text
tb_dcache_tag coverage: pass_count=144 lookup=131 hit=47 miss=84 refill=45 err=13 conflict=1 invalidate=13 random=120
tb_dcache_tag PASS
```

Lint summary:

```text
Command: make -C dcache lint
Result : PASS
```

## 2. Time-Sequenced Action Table

| Time | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset low and perform reset lookup | Valid bits clear, lookup misses | PASS |
| 20ns-30ns | Release reset and lookup same index/tag | Lookup still misses | PASS |
| 30ns-60ns | Successful refill for address A | Address A hits | PASS |
| 60ns-70ns | Lookup different offset in same line | Same tag/index hits | PASS |
| 70ns-80ns | Lookup unfilled different index | Lookup misses | PASS |
| 80ns-110ns | Refill-error update for address C | Address C remains miss | PASS |
| 110ns-140ns | Successful refill for address C | Address C hits | PASS |
| 140ns-180ns | Same-index conflict replacement | New tag hits, old tag misses | PASS |
| 180ns-200ns | Global invalidate | Previous hit line misses | PASS |
| 200ns-799ns | 120 deterministic-random operations | Reference model matches DUT | PASS |

## 3. Coverage Summary

| Coverage Item | Status |
| --- | --- |
| Reset invalid state | Covered |
| Refill hit | Covered |
| Same-line offset hit | Covered |
| Different-index miss | Covered |
| Refill error invalid | Covered |
| Conflict replacement | Covered |
| Global invalidate | Covered |
| Deterministic random stream | Covered |

## 4. Residual Risk

`dcache_tag` is verified as a standalone leaf. Later D-cache milestones must
verify that `dcache_ctrl`, `dcache_data`, refill, and store sequencing drive the
tag update and lookup ports with the intended cycle timing.
