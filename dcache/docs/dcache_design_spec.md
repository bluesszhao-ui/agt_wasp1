# dcache Design Spec

## 1. Scope

`dcache` integrates direct-mapped tag/data leaves, a load-refill sequencer, a
write-through store sequencer, an uncached MMIO sequencer, and a control FSM.
The wrapper owns no sequential state beyond the instantiated leaves.

## 2. Editable Block Diagram

```text
editable source: dcache/docs/diagrams/dcache_block.graffle
preview export:  none
detail level:    L2
clock domains:   SEQ clk=clk_i rst=rst_ni; dcache_data RAM uses clk_i only
```

The diagram separates core data interface, control logic and state, tag state,
data state, lookup result logic, refill FSM, store FSM, uncached transaction
FSM, cacheability classification, downstream request mux, downstream memory
interface, and cache-update interface. The wrapper owns no additional
sequential state.

`dcache_ctrl` guarantees that refill, store, and uncached sequencers are not
active together. The top-level downstream mux is therefore purely combinational
and does not add arbitration state.

Default cacheability decode treats `0x0000_0000..0x0000_FEFF`,
`0x1000_0000..0x1000_FFFF`, and `0x2000_0000..0x2000_FFFF` as cacheable. The
OTP register window at `0x0000_FF00..0x0000_FFFF` and all peripheral windows are
uncached.

## 3. Planned Submodules

| Submodule | Status | Notes |
| --- | --- | --- |
| `dcache_tag` | Implemented | Direct-mapped tag/valid lookup, refill update, invalidate. |
| `dcache_data` | Implemented | Cache-line storage, load word select, store-hit byte merge. |
| `dcache_refill` | Implemented | Downstream word-read line refill for load misses. |
| `dcache_store` | Implemented | One downstream write-through transaction with backpressure. |
| `dcache_uncached` | Implemented | One uncached MMIO transaction without tag/data allocation. |
| `dcache_ctrl` | Implemented | Load/store hit/miss, uncached steering, and response sequencing. |
| `dcache` | Implemented | Top-level D-cache integration and downstream refill/store/uncached mux. |

## 4. Policy Details

Loads:

```text
cacheable hit: return selected cached word to core
cacheable miss: refill full cache line, update tag/data, then return selected word
uncached: issue one downstream read and return its response without allocation
refill error: return response error and do not mark line valid
```

Stores:

```text
cacheable hit: issue downstream write, then merge successful write into cached line
cacheable miss: issue downstream write only, do not allocate a new cache line
uncached: issue one downstream write and do not allocate or update cache data
downstream error: return response error and do not update cached data
```

All stores are write-through, so no dirty state or eviction writeback exists in
this initial design.

## 5. State Ownership

At this milestone, D-cache sequential state exists in `dcache_tag` valid/tag
storage, `dcache_data` line storage, `dcache_refill` refill FSM state,
`dcache_store` store FSM state, `dcache_uncached` single-transaction FSM state,
and `dcache_ctrl` control FSM state. The `dcache` wrapper adds only
combinational interconnect, cacheability decode, and the downstream mux.

State diagrams are documented in:

```text
dcache/docs/images/dcache_tag_state.png
dcache/docs/images/dcache_data_state.png
dcache/docs/images/dcache_refill_fsm.png
dcache/docs/images/dcache_store_fsm.png
dcache/docs/images/dcache_ctrl_fsm.png
```
