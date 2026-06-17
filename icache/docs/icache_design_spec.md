# icache Design Spec

## 1. Scope

`icache` is currently implemented through its first two leaf submodules,
`icache_tag` and `icache_data`. The refill controller, uncached path, control
FSM, and complete top-level I-cache wrapper are staged after these leaves are
verified.

## 2. Planned Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Current I-cache clock/reset domain: clk=clk_i, rst=rst_ni

 IF frontend req/rsp
        |
        v
 +-----------------------+
 | icache_ctrl           |
 | planned COMB control  |
 +----+-------------+----+
      |
      v
 +-----------------------+
 | icache_ctrl state     |
 | planned SEQ clk/rst   |
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
 | valid/tag |  |planned RAM|
 +-----+-----+  +-----+-----+
       \           /
        v         v
      +-------------+
      |icache_refill|
      | planned     |
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
| `icache_ctrl` | Planned | Hit/miss control and frontend response sequencing. |
| `icache_refill` | Planned | Downstream line refill request/response sequencing. |
| `icache_uncached` | Planned | Optional uncached instruction fetch path if needed. |
| `icache` | Planned | Top-level I-cache integration. |

## 4. State Ownership

At this milestone, I-cache sequential state exists in `icache_tag` valid/tag
storage and `icache_data` line storage. The state diagrams are documented in:

```text
icache/docs/images/icache_tag_state.png
icache/docs/images/icache_data_state.png
```
