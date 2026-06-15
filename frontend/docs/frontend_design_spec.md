# frontend Design Spec

## 1. Scope

`frontend` is currently implemented only through its first leaf submodule,
`frontend_pc`. The top-level `frontend` wrapper and fetch/cache-facing logic are
staged after `frontend_pc` is verified.

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
| `frontend_fetch` | Planned | Will translate PC requests into instruction fetch requests. |
| `frontend_redirect` | Planned | Will arbitrate branch/trap/debug redirects if needed. |
| `frontend_ibuf` | Planned | Will decouple fetch response from core consumption. |
| `frontend` | Planned | Will integrate the frontend submodules. |

## 4. State Ownership

At this milestone, the only frontend sequential state is in `frontend_pc`. The
state diagram is documented in:

```text
frontend/docs/images/frontend_pc_state.png
```
