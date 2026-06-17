# icache Design Spec

## 1. Scope

`icache` integrates `icache_tag`, `icache_data`, `icache_refill`, and
`icache_ctrl` into the first complete instruction-cache wrapper.

## 2. Integrated Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Current I-cache clock/reset domain: clk=clk_i, rst=rst_ni

 IF front_if req/rsp
        |
        v
 +----------------------------+
 | IF icache front_if.target  |
 +-------------+--------------+
               |
               v
 +----------------------------+
 | COMB icache_ctrl outputs   |
 | lookup/refill/rsp controls |
 +-------------+--------------+
               |
               v
 +----------------------------+
 | SEQ icache_ctrl            |
 | clk=clk_i rst=rst_ni       |
 | request/miss/response FSM  |
 +---+--------------------+---+
     |                    |
     v                    v
 +-----------+        +-----------+
 | COMB tag  |        | COMB data |
 | compare   |        |word select|
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
       | COMB refill update |
       | tag/data write bus |
       +---------+----------+
                 |
                 v
       +--------------------+
       | SEQ icache_refill  |
       | clk=clk_i rst=rst_ni |
       | beat/line/error FSM|
       +---------+----------+
                 |
                 v
        IF mem_if downstream
```

## 3. Current Implementation Status

| Submodule | Status | Notes |
| --- | --- | --- |
| `icache_tag` | Implemented | Direct-mapped tag/valid lookup, refill update, invalidate. |
| `icache_data` | Implemented | Cache-line data storage and 32-bit word select. |
| `icache_ctrl` | Implemented | Hit/miss control, refill start/update, and frontend response sequencing. |
| `icache_refill` | Implemented | Downstream word-read refill FSM and line assembly. |
| `icache` | Implemented | Top-level integration of control, tag, data, and refill leaves. |

## 4. State Ownership

At this milestone, I-cache sequential state exists in `icache_tag` valid/tag
storage, `icache_data` line storage, `icache_refill` FSM/line assembly state,
and `icache_ctrl` hit/miss/response FSM state. The top wrapper owns no
additional registers. The state diagrams are documented in:

```text
icache/docs/images/icache_tag_state.png
icache/docs/images/icache_data_state.png
icache/docs/images/icache_refill_fsm.png
icache/docs/images/icache_ctrl_fsm.png
```
