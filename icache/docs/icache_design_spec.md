# icache Design Spec

## 1. Scope

`icache` is currently implemented through its first leaf submodule,
`icache_tag`. The data array, refill controller, uncached path, and complete
top-level I-cache wrapper are staged after this leaf is verified.

## 2. Planned Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Current I-cache clock/reset domain: clk=clk_i, rst=rst_ni

 IF frontend req/rsp
        |
        v
 +-----------------------+
 | icache_ctrl           |
 | planned SEQ+COMB      |
 +----+-------------+----+
      |             |
      v             v
 +-----------+  +-----------+
 | icache_tag|  |icache_data|
 | SEQ+COMB  |  | planned   |
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
| `icache_data` | Planned | Cache-line data storage and word select. |
| `icache_ctrl` | Planned | Hit/miss control and frontend response sequencing. |
| `icache_refill` | Planned | Downstream line refill request/response sequencing. |
| `icache_uncached` | Planned | Optional uncached instruction fetch path if needed. |
| `icache` | Planned | Top-level I-cache integration. |

## 4. State Ownership

At this milestone, I-cache sequential state exists in `icache_tag` valid/tag
storage. The state diagram is documented in:

```text
icache/docs/images/icache_tag_state.png
```
