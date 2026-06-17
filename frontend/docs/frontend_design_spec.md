# frontend Design Spec

## 1. Scope

`frontend` integrates its first three leaf submodules: `frontend_pc`,
`frontend_fetch`, and `frontend_ibuf`. The current top-level wrapper supports a
single redirect input and drives it directly into PC retargeting plus fetch/ibuf
flush. A separate `frontend_redirect` arbitration leaf is deferred until later
multi-source redirect integration.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Current frontend clock/reset domain: clk=clk_i, rst=rst_ni

 IF boot_pc/stall/redirect
              |
              v
 +------------------------+
 | frontend_pc            |
 | SEQ clk_i/rst_ni       |
 +-----------+------------+
             | IF pc_valid/pc/misaligned
             v
 +------------------------+       IF imem_if
 | frontend_fetch         |<----------------------> instruction cache/memory
 | SEQ+COMB clk_i/rst_ni  |
 +-----------+------------+
             | IF fetch response
             v
 +------------------------+
 | frontend_ibuf          |
 | SEQ+COMB clk_i/rst_ni  |
 +-----------+------------+
             | IF instr_valid/ready/pc/instr/fault
             v
        core/tile side

 redirect_valid_i also drives COMB/SEQ flush behavior in frontend_fetch and
 frontend_ibuf.
```

PNG integration diagram:

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
