# icache Spec

## 1. Purpose

`icache` is the first-level instruction-cache module family for wasp1. It sits
between `frontend` instruction fetch requests and the later tile/bus memory
path.

## 2. Required Submodules

```text
icache
icache_tag
icache_data
icache_ctrl
icache_refill
icache_uncached
```

## 3. Functional Requirements

The complete I-cache must:

```text
accept read-only instruction fetch requests
return 32-bit instruction words with fault status
use direct-mapped tag/data storage
refill cache lines from the downstream memory path
propagate downstream refill errors as instruction fetch faults
support invalidation for reset/control/debug flows
avoid programmer-visible behavior differences across IC and FPGA targets
```

## 4. Current Implemented Leaves

`icache_tag` provides:

```text
direct-mapped lookup index/tag extraction
valid/tag storage
hit/miss indication
refill tag update
refill-error invalid handling
global invalidate
```

`icache_data` provides:

```text
direct-mapped line storage
whole-line refill writes
lookup index decode
little-endian 32-bit word selection
complete line readback for cache control
```

`icache_refill` provides:

```text
line-aligned refill start acceptance
one downstream word read per line word
request and response backpressure handling
little-endian cache-line assembly
sticky refill error reporting
flush abort
```

`icache_ctrl` provides:

```text
frontend fetch request acceptance
hit response sequencing
miss refill start sequencing
refill line acceptance and tag/data update pulses
invalid request fault responses
flush abort and refill flush forwarding
```

## 5. Target Requirements

I-cache RTL must support:

```text
WASP1_TARGET_SIM_GENERIC
WASP1_TARGET_IC
WASP1_TARGET_FPGA_XILINX_VIRTEX7
```

Target macros may select storage implementation attributes, but must not change
hit/miss, refill, invalidate, error, or instruction response behavior.
