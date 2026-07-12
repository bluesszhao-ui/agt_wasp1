# debug_progbuf_exec Design Spec

## 1. Scope

`debug_progbuf_exec` owns sequencing and result policy for one Program Buffer
operation. It does not own storage, DMI decode, abstract-command dispatch, or
instruction execution inside the core.

## 2. Editable L3 Diagram

editable source: `debug/docs/diagrams/debug_progbuf_exec_fsm.graffle`
generator source: `debug/dv/generate_debug_progbuf_exec_diagram.py`
preview export: none
detail level: L3
clock domain: `clk_i/rst_ni`

The diagram uses separate IF, COMB, and SEQ blocks, then expands all five FSM
states. It shows the asynchronous reset path, normal request/response arcs,
local EBREAK termination, missing-EBREAK error, hart-loss result, DM abort, and
one-cycle completion behavior. Native line segments, V-shaped arrowheads,
visible 5pt grid, and shape/line clearance pass the repository audit.

## 3. State And Registers

| Register | Reset | Meaning |
| --- | --- | --- |
| `state_q` | `EXEC_IDLE` | Protocol ownership and output phase |
| `index_q` | zero | Current Program Buffer word |
| `completion_error_q` | `CMDERR_NONE` | Result held through COMPLETE |

No instruction payload register is needed. `instr_o` reads `words_i[index_q]`,
and integration must prevent Program Buffer writes while the abstract executor
is busy. ISSUE holds `index_q` stable under request backpressure; WAIT holds it
stable until the matching response.

## 4. Transition Table

| Current state | Condition, in priority order | Next state | Sequential side effect |
| --- | --- | --- | --- |
| IDLE | `start_i && dmactive_i && hart_halted_i` | CHECK | index=0, error=NONE |
| IDLE | `start_i && dmactive_i && !hart_halted_i` | COMPLETE | error=HALT_RESUME |
| CHECK | `!dmactive_i` | IDLE | scrub index/error |
| CHECK | `!hart_halted_i` | COMPLETE | error=HALT_RESUME |
| CHECK | current word is EBREAK | COMPLETE | retain error=NONE |
| CHECK | otherwise | ISSUE | none |
| ISSUE | `!dmactive_i` | IDLE | scrub index/error |
| ISSUE | `!hart_halted_i` | COMPLETE | error=HALT_RESUME |
| ISSUE | `instr_valid_o && instr_ready_i` | WAIT | instruction becomes outstanding |
| WAIT | `!dmactive_i` | IDLE | silently abort and scrub |
| WAIT | `!hart_halted_i` | COMPLETE | error=HALT_RESUME |
| WAIT | response with `instr_rsp_error_i` | COMPLETE | error=EXCEPTION |
| WAIT | successful response at final physical word | COMPLETE | error=EXCEPTION, no EBREAK |
| WAIT | other successful response | CHECK | index increments once |
| COMPLETE | unconditional | IDLE | no additional side effect |

Reset asynchronously selects IDLE and clears index/error before every runtime
condition. A busy `start_i` has no transition and cannot replace the operation.

## 5. Output Decode

`busy_o` is high in every state except IDLE. `done_o` is high only in COMPLETE.
The instruction request is valid only in ISSUE while DM and halted state remain
qualified. Response ready is similarly confined to WAIT. These gates stop new
handshakes immediately if integration removes execution permission.

## 6. EBREAK Policy

The controller consumes `PROGBUF_EBREAK_INSN` locally instead of sending it to
the ordinary core trap machinery. This prevents the debug terminator from
modifying machine trap CSRs. `impebreak` remains zero, so executing word three
without seeing EBREAK is an exception rather than implicit success.

## 7. Target Behavior

The FSM and register widths are target-neutral. Target macros do not alter
state encoding, handshake behavior, or abstract error mapping.
