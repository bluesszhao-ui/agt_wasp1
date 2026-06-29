# icache Design Spec

## 1. Scope

`icache` integrates `icache_tag`, `icache_data`, `icache_refill`, and
`icache_ctrl` into the first complete instruction-cache wrapper.

## 2. Editable Integrated Block Diagram

```text
editable source: icache/docs/diagrams/icache_block.graffle
preview export:  none
detail level:    L2
clock domains:   SEQ clk=clk_i rst=rst_ni; icache_data RAM uses clk_i only
```

The diagram separates frontend interface, control logic and state, tag state,
data state, lookup result logic, refill state, downstream memory interface, and
refill update interface. The top wrapper owns no additional sequential state.

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
