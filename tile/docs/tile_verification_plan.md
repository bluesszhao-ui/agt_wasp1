# tile Verification Plan

## 1. Scope

This plan covers the integrated `tile` milestone:

```text
frontend + icache + core + dcache + structural I/D path wiring
```

Both downstream memory ports are exercised with independently backpressured,
self-checking memory models.

## 2. Verification Goals

The tile testbench must prove:

```text
boot_pc_i reaches frontend
frontend fetch requests are translated into legal I-cache requests
I-cache responses reach frontend instruction buffering
frontend instruction stream reaches core instruction inputs
core ready backpressure reaches frontend
core redirect output reaches frontend redirect input
I-cache downstream memory requests are visible on tile imem_if
cache flush/invalidate inputs reach I-cache
core load/store requests pass through D-cache
D-cache load miss, load hit, store hit, write-through, and error behavior
D-cache flush/invalidate controls reach the cache
core observation outputs are visible at tile boundary
no tile-owned state exists
```

## 3. Testbench Strategy

The self-checking tile testbench instantiates real `tile` RTL and a
simple downstream memory model on `imem_if`.

Recommended memory model behavior:

```text
accept request when req_valid && req_ready
return response after configurable latency
support deterministic instruction words
inject response error for selected addresses
allow request-ready backpressure for cache-facing ports
```

The test program performs dependent loads, stores, branches, and redirects so
that cache integration is checked through architectural commits rather than
only through hierarchical signal observation.

## 4. Directed Cases

| Case | Purpose | Expected result |
| --- | --- | --- |
| Reset boot fetch | Check boot PC reaches instruction path | First frontend/I-cache request uses `boot_pc_i`. |
| Instruction hit/refill | Exercise I-cache request/response into frontend/core | Core receives instruction word and can commit simple instructions. |
| Core backpressure | Force core instruction ready low through a hazard sequence | Frontend holds or buffers according to frontend spec; no instruction is lost. |
| Redirect | Execute branch/trap redirect | Core redirect reaches frontend and next fetch uses target PC. |
| Fetch error | Inject a one-shot I-cache refill error | Faulted instruction suppresses writeback; a later clean refill recovers. |
| Cache invalidate | Pulse I-cache invalidate input | Later access behaves as miss/refill according to I-cache specs. |
| Cache flush | Pulse I-cache flush while cache work active | Active I-cache transaction is aborted according to child cache specs. |
| Interrupt propagation | Drive timer/external IRQ | Core trap observation reports the interrupt path. |
| Observation pass-through | Check commit/trap/hazard outputs | Tile outputs match child core outputs. |
| D-cache load miss/hit | Execute repeated loads in one cache line | First load refills; later load returns cached/updated data. |
| D-cache store hit | Store to a refilled line | Downstream write-through occurs and cached bytes update after success. |
| D-cache backpressure | Stall downstream request/response | Core holds the LSU instruction and issues no duplicate transaction. |
| D-cache error | Inject refill response error | Core reports `lsu_fault_o` and suppresses load writeback per the current core contract. |
| D-cache invalidate | Invalidate a resident line | Next load refills the line again. |

## 5. Time-Sequenced Action Table

The measured 0ns-5226ns action/result table is maintained in
`tile_verification_report.md`. It records every reset boundary, program phase,
cache maintenance pulse, injected error, interrupt action, and observed result.

## 6. Coverage Targets

Minimum functional coverage counters:

```text
reset_seen
boot_fetch_seen
frontend_req_seen
icache_front_req_seen
icache_downstream_req_seen
frontend_rsp_seen
core_instr_seen
core_instr_backpressure_seen
redirect_seen
redirect_target_fetch_seen
fetch_error_seen
icache_flush_seen
icache_invalidate_seen
dcache_load_miss_seen
dcache_load_hit_seen
dcache_store_seen
dcache_write_through_seen
dcache_backpressure_seen
dcache_error_seen
dcache_flush_seen
dcache_invalidate_seen
timer_irq_seen
external_irq_seen
commit_seen
trap_seen
hazard_seen
```

Recommended stronger coverage:

```text
deterministic-random instruction memory latency
deterministic-random I-cache flush/invalidate spacing
instruction miss followed by hit
fetch downstream response error on different refill beats
redirect while instruction buffer contains younger work
```

## 7. Integration Boundary

The tile keeps instruction and data downstream initiators separate. Arbitration
and conversion to the SoC AHB-Lite masters belong to the later SoC integration
boundary and are not inferred by this testbench.
