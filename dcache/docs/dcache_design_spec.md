# dcache Design Spec

## 1. Scope

`dcache` integrates direct-mapped tag/data leaves, a load-refill sequencer, a
write-through store sequencer, and a control FSM. The wrapper owns no sequential
state beyond the instantiated leaves.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Current D-cache clock/reset domain: clk=clk_i, rst=rst_ni

 IF core data req/rsp
        |
        v
 +----------------------------+
 | COMB dcache_ctrl decode    |
 | load/store/hit/miss select |
 +-------------+--------------+
               |
               v
 +----------------------------+
 | SEQ dcache_ctrl            |
 | clk=clk_i rst=rst_ni       |
 | request/refill/store/rsp   |
 +---+--------------------+---+
     |                    |
     v                    v
 +-----------+        +-----------+
 | COMB tag  |        | COMB data |
 | compare   |        |word/merge |
 +-----+-----+        +-----+-----+
       |                    |
       v                    v
 +-----------+        +-----------+
 | SEQ tag   |        | SEQ data  |
 | clk/rst   |        | clk=clk_i |
 | valid/tag |        | line RAM  |
 +-----+-----+        +-----+-----+
       ^                    ^
       |                    |
       +---------+----------+
                 |
                 v
       +--------------------+
       | COMB update mux    |
       | refill/store-hit   |
       +---------+----------+
                 |
        +--------+---------+
       |                  |
       v                  v
 +--------------+   +--------------+
 | SEQ refill   |   | SEQ store    |
 | clk/rst FSM  |   | clk/rst FSM  |
 +------+-------+   +------+-------+
        |                  |
        +---------+--------+
                  |
                  v
        +-------------------+
        | COMB downstream   |
        | refill/store mux  |
        +---------+---------+
                  |
                  v
          IF downstream memory
```

`dcache_ctrl` guarantees that refill and store sequencers are not active
together. The top-level downstream mux is therefore purely combinational and
does not add arbitration state.

## 3. Planned Submodules

| Submodule | Status | Notes |
| --- | --- | --- |
| `dcache_tag` | Implemented | Direct-mapped tag/valid lookup, refill update, invalidate. |
| `dcache_data` | Implemented | Cache-line storage, load word select, store-hit byte merge. |
| `dcache_refill` | Implemented | Downstream word-read line refill for load misses. |
| `dcache_store` | Implemented | One downstream write-through transaction with backpressure. |
| `dcache_ctrl` | Implemented | Load/store hit/miss policy and response sequencing. |
| `dcache` | Implemented | Top-level D-cache integration and downstream refill/store mux. |

## 4. Policy Details

Loads:

```text
hit: return selected cached word to core
miss: refill full cache line, update tag/data, then return selected word
refill error: return response error and do not mark line valid
```

Stores:

```text
hit: issue downstream write, then merge successful write into cached line
miss: issue downstream write only, do not allocate a new cache line
downstream error: return response error and do not update cached data
```

All stores are write-through, so no dirty state or eviction writeback exists in
this initial design.

## 5. State Ownership

At this milestone, D-cache sequential state exists in `dcache_tag` valid/tag
storage, `dcache_data` line storage, `dcache_refill` refill FSM state,
`dcache_store` store FSM state, and `dcache_ctrl` control FSM state. The
`dcache` wrapper adds only combinational interconnect and the downstream mux.

State diagrams are documented in:

```text
dcache/docs/images/dcache_tag_state.png
dcache/docs/images/dcache_data_state.png
dcache/docs/images/dcache_refill_fsm.png
dcache/docs/images/dcache_store_fsm.png
dcache/docs/images/dcache_ctrl_fsm.png
```
