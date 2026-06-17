# icache Design Spec

## 1. Scope

`icache` is currently implemented through `icache_tag`, `icache_data`,
`icache_refill`, and `icache_ctrl`. The complete top-level I-cache wrapper is
staged after these leaves are verified.

## 2. Planned Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Current I-cache clock/reset domain: clk=clk_i, rst=rst_ni

 IF frontend req/rsp
        |
        v
 +-----------------------+
 | icache_ctrl           |
 | COMB control          |
 +----+-------------+----+
      |
      v
 +-----------------------+
 | icache_ctrl state     |
 | SEQ clk=clk_i rst=rst_ni |
 +----+-------------+----+
      |             |
      v             v
 +-----------+  +-----------+
 | tag COMB  |  |data COMB  |
 | compare   |  |word select|
 +-----+-----+  +-----+-----+
       |              |
       v              v
 +-----------+  +-----------+
 | tag SEQ   |  |data SEQ   |
 | valid/tag |  |line RAM   |
 +-----+-----+  +-----+-----+
       \           /
        v         v
      +-------------+
      |refill COMB  |
      |req/rsp ctrl |
      +------+------+
             |
             v
      +-------------+
      |refill SEQ   |
      |FSM/line buf |
      +------+------+
             |
             v
      IF downstream memory path
```

## 3. Current Implementation Status

| Submodule | Status | Notes |
| --- | --- | --- |
| `icache_tag` | Implemented | Direct-mapped tag/valid lookup, refill update, invalidate. |
| `icache_data` | Implemented | Cache-line data storage and 32-bit word select. |
| `icache_ctrl` | Implemented | Hit/miss control, refill start/update, and frontend response sequencing. |
| `icache_refill` | Implemented | Downstream word-read refill FSM and line assembly. |
| `icache` | Planned | Top-level I-cache integration. |

## 4. State Ownership

At this milestone, I-cache sequential state exists in `icache_tag` valid/tag
storage, `icache_data` line storage, `icache_refill` FSM/line assembly state,
and `icache_ctrl` hit/miss/response FSM state. The state diagrams are
documented in:

```text
icache/docs/images/icache_tag_state.png
icache/docs/images/icache_data_state.png
icache/docs/images/icache_refill_fsm.png
icache/docs/images/icache_ctrl_fsm.png
```
