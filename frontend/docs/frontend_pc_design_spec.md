# frontend_pc Design Spec

## 1. Scope

`frontend_pc` is a small sequential PC register and valid generator for the
instruction frontend.

## 2. Editable Block Diagram

```text
editable source: frontend/docs/diagrams/frontend_pc_block.graffle
preview export:  none
detail level:    L1
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates external PC control inputs, the combinational update
priority mux, the PC/valid sequential state, derived output logic, and the PC
output interface.

Legacy PNG state diagram:

```text
frontend/docs/images/frontend_pc_state.png
```

## 3. State

| State element | Reset value | Update behavior |
| --- | --- | --- |
| `pc_q` | `boot_pc_i` | Redirect target, `pc_q + 4` on fetch fire, or hold. |
| `valid_q` | `0` | Set to `1` after reset release and remains high. |

## 4. Update Priority

Runtime update priority is:

```text
1. redirect_valid_i
2. pc_valid_o && fetch_ready_i
3. hold
```

Reset has asynchronous priority over all runtime behavior.

## 5. Derived Signals

```text
pc_o            = pc_q
pc_valid_o      = valid_q && !stall_i
pc_misaligned_o = |pc_q[1:0]
fetch_fire      = pc_valid_o && fetch_ready_i
```

## 6. Rationale

Redirect is accepted even during stall. This keeps branch/trap/debug retargeting
responsive while a downstream fetch path is blocked. Misaligned PCs are flagged
rather than rounded so exception behavior can be implemented by later
frontend/fetch/trap integration.
