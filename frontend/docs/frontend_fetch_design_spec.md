# frontend_fetch Design Spec

## 1. Scope

`frontend_fetch` is a one-outstanding instruction fetch controller. It bridges
PC requests from `frontend_pc` to the common `mem_req_rsp_if` instruction memory
interface and returns instruction responses to the later ibuf/core side.

## 2. Editable Block Diagram

```text
editable source: frontend/docs/diagrams/frontend_fetch_block.graffle
preview export:  none
detail level:    L2
clock domains:   SEQ clk=clk_i rst=rst_ni
```

The diagram separates PC classification, instruction-memory request drive,
local misaligned-fault logic, one-outstanding fetch state, response mux/drop
logic, and instruction-memory/output interfaces.

Legacy PNG state diagram:

```text
frontend/docs/images/frontend_fetch_state.png
```

## 3. State

| State element | Reset value | Description |
| --- | --- | --- |
| `state_q` | `FETCH_IDLE` | Whether a memory request is outstanding. |
| `pc_q` | `0` | PC captured with the outstanding memory request. |
| `kill_q` | `0` | Outstanding response must be consumed and dropped. |

## 4. FSM

```text
FETCH_IDLE
  aligned pc_valid && imem req_ready && !flush -> FETCH_WAIT, capture pc_i
  misaligned pc_valid && instr_ready && !flush -> stay IDLE, local fault response
  otherwise -> stay IDLE

FETCH_WAIT
  rsp_valid && rsp_ready -> FETCH_IDLE, clear kill
  flush_i -> stay WAIT, set kill
  otherwise -> stay WAIT
```

`rsp_ready` is asserted when the outstanding response can either be delivered to
the consumer or dropped because `kill_q`/`flush_i` is active.

## 5. Request Encoding

Instruction memory requests are always:

```text
req_write = 0
req_size  = 2  (word)
req_wdata = 0
req_wstrb = 0
req_instr = 1
req_addr  = pc_i
```

## 6. Priority Notes

Flush suppresses new request acceptance while idle and kills an already
outstanding request while waiting. Misaligned PC faults are not emitted during
flush because the flushed PC is no longer architecturally live.
