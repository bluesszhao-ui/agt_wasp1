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

## 6. Target Requirements

D-cache RTL must support:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```

Target macros may select storage implementation attributes, but must not change
hit/miss, refill, store, invalidate, error, or data response behavior.
