# frontend Design Spec

## 1. Scope

`frontend` is currently implemented through its first three leaf submodules:
`frontend_pc`, `frontend_fetch`, and `frontend_ibuf`. The top-level `frontend`
wrapper and redirect arbitration are staged after these leaves are verified.

## 2. Planned Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Current frontend clock/reset domain: clk=clk_i, rst=rst_ni

                  IF redirect
                     |
                     v
               +-----------------------+
 IF boot_pc -->| frontend_pc           |---- IF pc_valid/pc/misaligned
 IF stall/ready| SEQ clk_i/rst_ni      |
               +-----------+-----------+
                      |
                      v
               +-----------------------+
               | frontend_fetch        |
               | SEQ+COMB clk_i/rst_ni |
               +-----------+-----------+
                      |
                      v
               +-----------------------+
               | frontend_ibuf         |
               | SEQ+COMB clk_i/rst_ni |
               +-----------------------+
```

## 3. Current Implementation Status

| Submodule | Status | Notes |
| --- | --- | --- |
| `frontend_pc` | Implemented | PC register, redirect priority, stall hold, misalignment observation. |
| `frontend_fetch` | Implemented | One-outstanding instruction request, misaligned local fault, flush drop. |
| `frontend_redirect` | Planned | Will arbitrate branch/trap/debug redirects if needed. |
| `frontend_ibuf` | Implemented | Flushable two-entry FIFO for instruction responses and metadata. |
| `frontend` | Planned | Will integrate the frontend submodules. |

## 4. State Ownership

At this milestone, frontend sequential state exists in `frontend_pc`,
`frontend_fetch`, and `frontend_ibuf`. The state diagrams are documented in:

```text
frontend/docs/images/frontend_pc_state.png
frontend/docs/images/frontend_fetch_state.png
frontend/docs/images/frontend_ibuf_state.png
```
