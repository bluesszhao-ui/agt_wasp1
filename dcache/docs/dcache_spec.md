# dcache Spec

## 1. Purpose

`dcache` is the first-level data-cache module family for wasp1. It sits between
the core load/store path and the later tile/bus memory path.

## 2. Required Submodules

```text
dcache
dcache_tag
dcache_data
dcache_ctrl
dcache_refill
dcache_store
dcache_uncached
```

## 3. Functional Requirements

The complete D-cache must:

```text
accept core data-memory requests through a lightweight valid/ready interface
support byte, halfword, and word load/store accesses
use direct-mapped tag/data storage
allocate cache lines on load miss
return load hits from the cached line
issue one downstream word read per line word during refill
route non-cacheable MMIO/device accesses as single uncached transactions
propagate downstream load/refill errors as data access faults
write stores through to downstream memory
update the cached line on a store hit after downstream write success
avoid allocating a new line on a store miss
support invalidation for reset/control/debug flows
avoid programmer-visible behavior differences across IC and FPGA targets
```

## 4. Policy

The initial wasp1 D-cache policy is intentionally minimal:

```text
organization: direct mapped
line size: parameterized, default 16 bytes
write policy: write-through
write miss policy: no-write-allocate
replacement: direct-mapped index replacement
coherency: no hardware snoop in this milestone
```

Store miss no-write-allocate keeps the first implementation small and avoids
dirty eviction state. A later revision may add write buffering or allocation
without changing the software-visible memory model.

## 5. Current First Leaf

`dcache_tag` provides:

```text
direct-mapped lookup index/tag extraction
valid/tag storage
hit/miss indication
refill tag update
refill-error invalid handling
global invalidate
```

`dcache_data` provides:

```text
direct-mapped line storage
whole-line refill writes
lookup index decode
little-endian 32-bit word selection
store-hit byte-lane merge updates
refill-over-store deterministic priority
```

`dcache_refill` provides:

```text
line-aligned load-miss refill start acceptance
one downstream data word read per line word
request and response backpressure handling
little-endian cache-line assembly
sticky refill error reporting
flush abort
```

`dcache_store` provides:

```text
one downstream write-through store transaction per accepted start
request and response backpressure handling
pass-through address, size, write data, and byte strobes
downstream write error reporting
flush abort
```

`dcache_ctrl` provides:

```text
core load/store request acceptance
cacheable versus uncached request steering
load hit response from cached data
load miss refill allocation and response
uncached load/store response forwarding without tag/data allocation
store write-through sequencing on hit and miss
successful store-hit cache data update
store miss no-write-allocate policy enforcement
invalid request fault response
flush abort forwarding to refill/store/uncached leaves
```

`dcache_uncached` provides:

```text
one downstream transaction for each non-cacheable load or store
single-word read behavior for MMIO, avoiding cache-line side-effect reads
no tag/data allocation or cache update
request/response backpressure handling
flush abort
```

The integrated `dcache` top provides:

```text
real tag/data/control/refill/store leaf interconnection
one core data request/response port
one downstream data memory request/response port
address-window cacheability classification
combinational downstream mux between refill, store, and uncached sequencers
top-level invalidate forwarding to tag valid bits
top-level flush forwarding through control to active refill/store/uncached work
```

Default cacheable address windows are the executable/read-only OTP data window,
I-SRAM, and D-SRAM. The OTP programming register window and peripheral MMIO
regions are non-cacheable by default so volatile software reads observe current
device state and writes are not merged into cache lines.

## 6. Target Requirements

D-cache RTL must support:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```

Target macros may select storage implementation attributes, but must not change
hit/miss, refill, store, invalidate, error, or data response behavior.
