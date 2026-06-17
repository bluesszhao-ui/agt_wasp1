# frontend_fetch Design Spec

## 1. Scope

`frontend_fetch` is a one-outstanding instruction fetch controller. It bridges
PC requests from `frontend_pc` to the common `mem_req_rsp_if` instruction memory
interface and returns instruction responses to the later ibuf/core side.

## 2. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state
Clock/reset domain for all SEQ blocks: clk=clk_i, rst=rst_ni

 IF pc_valid/pc/misaligned
           |
           v
 +-----------------------+
 | COMB accept/classify  |---- misaligned ----+
 +----------+------------+                    |
           | aligned                          v
           v                           +------------------+
 +-----------------------+             | COMB local fault |
 | COMB imem req driver  |             +---------+--------+
 +----------+------------+                       |
           |                                    |
           v                                    v
 +-----------------------+             +-------------------+
 | SEQ clk_i/rst_ni      |------------>| COMB response mux |---- IF instr_valid/pc/instr/fault
 | state_q, pc_q, kill_q |<----flush---|                   |
 +----------+------------+             +-------------------+
           |
           v
 IF imem response consume/drop
```

PNG state diagram:

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
