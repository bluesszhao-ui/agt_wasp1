# dcache Verification Plan

## 1. Goals

Verify D-cache leaves and integrations module by module. Current milestones
verify `dcache_tag`, `dcache_data`, `dcache_refill`, and `dcache_store`.

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

## 4. dcache_data

`tb_dcache_data` mirrors cache-line storage in a reference model and covers:

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Whole-line refill | Write all words in a line | Lookup returns refilled line |
| Word select | Read each word offset | Correct 32-bit word returned |
| Byte merge | Store one byte lane | Only selected byte changes |
| Half/word merge | Store multi-byte masks | Selected lanes change together |
| Zero strobe | Store with no lanes selected | Line remains unchanged |
| Conflict refill | Same index, different line | New line replaces old contents |
| Refill/store priority | Simultaneous update | Refill line wins |
| Random stream | Mixed refill/store/lookup | Reference model matches DUT |

## 5. dcache_refill

`tb_dcache_refill` models the downstream memory path and covers:

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Normal refill | Read one complete line | Completed line matches reference |
| Request backpressure | Hold downstream `req_ready` low | Request valid/address remain stable |
| Response wait states | Delay downstream responses | No early line completion |
| Output backpressure | Hold `line_ready_i` low | Completed line remains stable |
| Error beat | One response has error | `line_error_o` asserted |
| Flush abort | Flush active refill | No completed line emitted |
| Random stream | Random stalls/errors | Reference model matches DUT |

## 6. dcache_store

`tb_dcache_store` models the downstream memory path and covers:

| Case | Purpose | Expected Result |
| --- | --- | --- |
| Byte store | Verify size/strobe pass-through | One data write and clean completion |
| Halfword store | Verify request/output backpressure | Payload remains stable under stalls |
| Word store error | Verify downstream error propagation | `done_error_o` asserted |
| Zero-strobe passthrough | Preserve captured strobe value | Request and completion strobe remain zero |
| Flush abort | Flush active store | No completion emitted |
| Random stream | Random sizes/strobes/stalls/errors | Reference expectations match DUT |

## 7. Time Base

Testbenches use:

```text
timescale: 1ns/1ps
clock period: 10ns
clock frequency: 100MHz
```
