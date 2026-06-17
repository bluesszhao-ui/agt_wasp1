# dcache Verification Plan

## 1. Goals

Verify D-cache leaves and integrations module by module. The first milestone
verifies `dcache_tag`.

## 2. Planned Coverage

Complete `dcache` verification must cover:

```text
load hit
load miss refill
load refill error
store hit write-through and cache update
store miss no-write-allocate
store downstream error
byte/half/word access sizes
frontend/core response backpressure
downstream request/response backpressure
invalidate and flush behavior
direct-mapped conflict replacement
deterministic-random access streams
```

## 3. First Leaf: dcache_tag

`tb_dcache_tag` will mirror tag/valid state in a reference model and cover:

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Reset lookup | Valid bits clear on reset | Lookup misses |
| Refill hit | Successful refill marks line valid | Lookup hits same tag/index |
| Same-line offset | Different byte offset in same line | Lookup still hits |
| Different index | Unfilled index | Lookup misses |
| Refill error | Failed refill does not mark valid | Lookup misses |
| Conflict replacement | Same index, different tag | New tag hits, old tag misses |
| Invalidate | Clear all valid bits | Previously hit line misses |
| Random stream | Mixed refill/error/invalidate/lookup | Reference model matches DUT |

## 4. Time Base

Testbenches use:

```text
timescale: 1ns/1ps
clock period: 10ns
clock frequency: 100MHz
```
