# dcache_ctrl Spec

## 1. Purpose

`dcache_ctrl` is the data-cache control leaf. It accepts core data-memory
requests, consumes tag/data lookup results, starts load-miss cache-line refills,
starts write-through store transactions, updates tag/data leaves when allowed,
and returns exactly one core response for each accepted request unless flushed.

## 2. Interfaces

Clock/reset:

```text
clk_i   D-cache control clock
rst_ni  active-low asynchronous reset
flush_i synchronous abort for active control work
```

Core interface:

```text
core_if.target
  accepts load and store data requests
  req_instr must be 0
  req_size supports byte, halfword, and word
  response data is the selected 32-bit word for loads and zero for stores
  response error marks data access fault
```

Cacheability input:

```text
req_cacheable_i
  sampled with an accepted core request
  1 routes legal requests through tag/data/refill/store cache policy
  0 routes legal requests through the uncached sequencer with no allocation
```

Tag/data lookup:

```text
lookup_valid_o  qualifies lookup_addr_o for tag comparison
lookup_addr_o   address presented to tag and data leaves
tag_hit_i       hit result for lookup_addr_o
data_word_i     cached data word for lookup_addr_o
```

Refill interface:

```text
refill_start_valid_o/refill_start_ready_i/refill_start_addr_o
  starts a cache-line refill for a load miss

refill_line_valid_i/refill_line_ready_o/refill_line_addr_i/refill_line_data_i/refill_line_error_i
  transfers one completed refill line back to the cache
```

Store interface:

```text
store_start_valid_o/store_start_ready_i
store_start_addr_o/store_start_size_o/store_start_wdata_o/store_start_wstrb_o
  starts one write-through store transaction

store_done_valid_i/store_done_ready_o
store_done_addr_i/store_done_size_i/store_done_wdata_i/store_done_wstrb_i/store_done_error_i
  completes the write-through store transaction
```

Uncached interface:

```text
uncached_start_valid_o/uncached_start_ready_i
uncached_start_addr_o/uncached_start_write_o/uncached_start_size_o
uncached_start_wdata_o/uncached_start_wstrb_o
  starts one non-cacheable load or store transaction

uncached_done_valid_i/uncached_done_ready_o
uncached_done_rdata_i/uncached_done_error_i
  completes the non-cacheable transaction
```

Tag/data update:

```text
tag_refill_valid_o/tag_refill_addr_o/tag_refill_error_o
data_refill_valid_o/data_refill_addr_o/data_refill_line_o
  pulse when a completed load-miss refill line is accepted

data_store_valid_o/data_store_addr_o/data_store_wdata_o/data_store_wstrb_o
  pulse only after a successful downstream store hit
```

## 3. Functional Requirements

`dcache_ctrl` must:

```text
accept one core request at a time
use req_cacheable_i to steer legal non-cacheable requests away from tag/data
return load hits from data_word_i
start exactly one refill for a load miss
select the requested 32-bit word from the completed refill line
return refill_line_error_i as the load-miss response error
write tag and data leaves when a refill line is accepted
issue stores through the store sequencer on both hit and miss
update cached data after successful store hit only
avoid allocating a new cache line on store miss
avoid updating cached data on store downstream error
fault invalid core requests without starting refill/store work
complete uncached loads/stores without tag/data refill or store-hit updates
hold responses stable under core response backpressure
hold refill/store/uncached starts stable under subordinate backpressure
abort active work when flush_i is asserted
forward flush_i to refill, store, and uncached sequencers
```

Invalid core requests are:

```text
instruction-side requests with req_instr=1
size encoding 3
halfword requests with addr[0] != 0
word requests with addr[1:0] != 0
```

## 4. Cache Policy

Loads:

```text
hit:  return cached word
miss: allocate line through refill, update tag/data, return selected word
error: propagate refill error and keep tag invalid through tag_refill_error_o
```

Stores:

```text
hit:  write through, then update cached bytes if downstream write succeeds
miss: write through only, no allocation
error: propagate store error and do not update cached data
```

Uncached:

```text
load:  start one uncached read and return uncached_done_rdata_i
store: start one uncached write and return zero data plus error status
update: never pulse tag/data update outputs for uncached work
```

## 5. Target Behavior

The controller contains only target-neutral registers and combinational logic.
The following target macros must not change its programmer-visible behavior:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```
