# tile Verification Plan

## 1. Scope

This plan covers the first `tile` integration milestone:

```text
frontend + icache + core + structural instruction-path wiring
```

It explicitly does not claim D-cache integration until real `dcache` wiring and
data-path tests are added. The core side now has a valid/ready data interface,
so a later tile milestone can verify D-cache without a hidden adapter.

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
core observation outputs are visible at tile boundary
no tile-owned state exists in the first milestone
```

## 3. Testbench Strategy

The first self-checking tile testbench should instantiate real `tile` RTL and a
simple downstream memory model on `imem_if`.

Recommended memory model behavior:

```text
accept request when req_valid && req_ready
return response after configurable latency
support deterministic instruction words
inject response error for selected addresses
allow request-ready backpressure for cache-facing ports
```

Core data-memory valid/ready ports may be tied to a small model for the
instruction programs used in this milestone, but D-cache behavior must remain
out of scope until the real D-cache instance is wired.

## 4. Directed Cases

| Case | Purpose | Expected result |
| --- | --- | --- |
| Reset boot fetch | Check boot PC reaches instruction path | First frontend/I-cache request uses `boot_pc_i`. |
| Instruction hit/refill | Exercise I-cache request/response into frontend/core | Core receives instruction word and can commit simple instructions. |
| Core backpressure | Force core instruction ready low through a hazard sequence | Frontend holds or buffers according to frontend spec; no instruction is lost. |
| Redirect | Execute branch/trap redirect | Core redirect reaches frontend and next fetch uses target PC. |
| Fetch error | Inject I-cache/downstream error | Core fetch fault/trap observation is asserted according to core behavior. |
| Cache invalidate | Pulse I-cache invalidate input | Later access behaves as miss/refill according to I-cache specs. |
| Cache flush | Pulse I-cache flush while cache work active | Active I-cache transaction is aborted according to child cache specs. |
| Interrupt propagation | Drive timer/external IRQ | Core trap observation reports the interrupt path. |
| Observation pass-through | Check commit/trap/hazard outputs | Tile outputs match child core outputs. |

## 5. Time-Sequenced Action Table

The first verification report must include a table like this after the
testbench is implemented:

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-20ns | Hold reset active. | Child frontend/core/cache state reset or invalid according to child specs. | TBD |
| 20ns-80ns | Release reset and provide boot instruction memory responses. | First frontend/I-cache request targets `boot_pc_i`; first instruction stream beat reaches core. | TBD |
| 80ns-180ns | Run simple ALU/commit sequence from instruction memory. | Commit outputs match expected rd/data sequence. | TBD |
| 180ns-240ns | Force an instruction-stream stall through a load-use sequence. | Frontend/core handshake holds without instruction loss. | TBD |
| 240ns-320ns | Execute branch or trap redirect. | Frontend redirects fetch to the core-provided target PC. | TBD |
| 320ns-400ns | Inject fetch response error. | Fetch fault observations match core/cache specs. | TBD |
| 400ns-480ns | Pulse I-cache flush/invalidate during active work. | Child I-cache behavior matches flush/invalidate specs. | TBD |
| 480ns-560ns | Drive timer/external interrupts. | Core trap/interrupt observations match CSR/trap specs. | TBD |

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

## 7. Known Open Issue

D-cache tile integration is pending tile RTL wiring and verification. The
verification report for this tile milestone must explicitly state:

```text
instruction path: frontend-owned PC, integrated through I-cache
data path: D-cache not integrated unless a later tile milestone wires it
```
