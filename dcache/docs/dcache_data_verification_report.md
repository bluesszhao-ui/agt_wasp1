# dcache_data Verification Report

## 1. Result

```text
Command: make -C dcache sim-dcache-data
Result : PASS
```

Simulation summary:

```text
tb_dcache_data coverage: pass_count=249 refill=74 lookup=176 store=62 byte_lane=102 word=4 conflict=1 priority=1 random=160
tb_dcache_data PASS
```

Lint summary:

```text
Command: make -C dcache lint
Result : PASS
```

## 2. Time-Sequenced Action Table

| Time | Action | Expected Result | Observed Result |
| --- | --- | --- | --- |
| 0ns-30ns | Reset release; data contents ignored | No architectural data assumption | PASS |
| 30ns-90ns | Refill address A and read all word offsets | Whole line stored; all word selects correct | PASS |
| 90ns-150ns | Byte, halfword, word, and zero-strobe store merges | Selected byte lanes update only after clock edge | PASS |
| 150ns-210ns | Refill different index C and re-read A | Different index does not disturb A | PASS |
| 210ns-250ns | Same-index conflict refill B | New line replaces old index | PASS |
| 250ns-270ns | Simultaneous refill and store | Refill priority wins | PASS |
| 270ns-1150ns | 160 deterministic-random refill/store/lookup operations | Reference model matches DUT | PASS |

## 3. Coverage Summary

| Coverage Item | Status |
| --- | --- |
| Whole-line refill | Covered |
| Combinational lookup line read | Covered |
| All word offsets | Covered |
| Byte lane store merge | Covered |
| Halfword and word store masks | Covered |
| Zero-strobe hold | Covered |
| Write visible after clock edge | Covered |
| Same-index replacement | Covered |
| Refill-over-store priority | Covered |
| Deterministic random stream | Covered |

## 4. Residual Risk

`dcache_data` is verified as a standalone leaf. Later controller integration
must verify that store-hit updates are generated only after downstream
write-through success and that refill/store requests are not issued
simultaneously in normal operation.
