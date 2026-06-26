# frontend Design Spec

## 1. Scope

`frontend` integrates its first three leaf submodules: `frontend_pc`,
`frontend_fetch`, and `frontend_ibuf`. The current top-level wrapper supports a
single redirect input and drives it directly into PC retargeting plus fetch/ibuf
flush. A separate `frontend_redirect` arbitration leaf is deferred until later
multi-source redirect integration.

## 2. Editable Block Diagram

```text
editable source: frontend/docs/diagrams/frontend_block.graffle
preview export:  none
detail level:    L2
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates redirect/flush fanout, PC state, fetch classify/request
logic, fetch outstanding state, fetch response muxing, ibuf FIFO state, ibuf pop
logic, and the instruction memory/core interfaces. The wrapper itself owns no
additional sequential state beyond the child SEQ blocks shown in the diagram.

Legacy PNG integration diagram:

```text
frontend/docs/images/frontend_state.png
```

## 3. Current Implementation Status

| Submodule | Status | Notes |
| --- | --- | --- |
| `frontend_pc` | Implemented | PC register, redirect priority, stall hold, misalignment observation. |
| `frontend_fetch` | Implemented | One-outstanding instruction request, misaligned local fault, flush drop. |
| `frontend_redirect` | Planned | Will arbitrate branch/trap/debug redirects if needed. |
| `frontend_ibuf` | Implemented | Flushable two-entry FIFO for instruction responses and metadata. |
| `frontend` | Implemented | Top-level PC/fetch/ibuf integration with direct single-source redirect. |

## 4. State Ownership

At this milestone, frontend sequential state exists in `frontend_pc`,
`frontend_fetch`, and `frontend_ibuf`. The state diagrams are documented in:

```text
frontend/docs/images/frontend_pc_state.png
frontend/docs/images/frontend_fetch_state.png
frontend/docs/images/frontend_ibuf_state.png
frontend/docs/images/frontend_state.png
```

The `frontend` wrapper owns no additional sequential state beyond instantiated
child modules.

## 5. Redirect and Flush Behavior

`redirect_valid_i` is wired to:

```text
frontend_pc.redirect_valid_i
frontend_fetch.flush_i
frontend_ibuf.flush_i
```

This means a redirect captures the new PC, suppresses or kills stale fetch work,
and clears any queued instruction responses in the same clock domain.
