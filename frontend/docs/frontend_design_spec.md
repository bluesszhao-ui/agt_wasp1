# frontend Design Spec

## 1. Scope

`frontend` is currently implemented through its first two leaf submodules:
`frontend_pc` and `frontend_fetch`. The top-level `frontend` wrapper, redirect
arbitration, and instruction buffer are staged after these leaves are verified.

## 2. Planned Block Diagram

```text
                  redirect
                     |
                     v
               +-------------+
 boot_pc ----->| frontend_pc |---- pc_valid/pc/misaligned
 stall/ready ->|             |
               +------+------+ 
                      |
                      v
               +-------------+
               | frontend_fetch |
               +------+------+
                      |
                      v
               +-------------+
               | frontend_ibuf |
               +-------------+
```

## 3. Current Implementation Status

| Submodule | Status | Notes |
| --- | --- | --- |
| `frontend_pc` | Implemented | PC register, redirect priority, stall hold, misalignment observation. |
| `frontend_fetch` | Implemented | One-outstanding instruction request, misaligned local fault, flush drop. |
| `frontend_redirect` | Planned | Will arbitrate branch/trap/debug redirects if needed. |
| `frontend_ibuf` | Planned | Will decouple fetch response from core consumption. |
| `frontend` | Planned | Will integrate the frontend submodules. |

## 4. State Ownership

At this milestone, frontend sequential state exists in `frontend_pc` and
`frontend_fetch`. The state diagrams are documented in:

```text
frontend/docs/images/frontend_pc_state.png
frontend/docs/images/frontend_fetch_state.png
```
