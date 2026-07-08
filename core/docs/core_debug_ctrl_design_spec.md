# core_debug_ctrl Design Spec

## 1. Scope

`core_debug_ctrl` is a small sequential FSM that controls the core-side Debug
Mode hooks. It has no programmer-visible CSRs; it only coordinates pipeline
drain/freeze, decoded trigger entry requests, and Debug Module status.

## 2. Editable Diagram

```text
editable source: core/docs/diagrams/core_debug_ctrl_fsm.graffle
preview export:  none
detail level:    L3
clock domain:    SEQ clk=clk_i rst=rst_ni
```

The OmniGraffle source uses the project timing-class colors:

```text
SEQ  pale green
COMB pale amber/yellow
IF   pale blue
```

## 3. Block Diagram

```text
Legend: IF=interface, COMB=combinational logic, SEQ=clocked state

 IF debug request/status pins
 halt_req_i/trigger_req_i/resume_req_i/step_req_i
 pipe_idle_i/retire_valid_i/debug_busy_i
        |
        v
 +--------------------------------+
 | COMB next-state and priority   |
 | halt/trigger > resume/step     |
 | busy blocks resume/step        |
 +---------------+----------------+
                 |
                 v
 +--------------------------------+
 | SEQ clk=clk_i rst=rst_ni       |
 | state_q                        |
 | RUNNING/HALT_PENDING/HALTED/   |
 | STEP_RUNNING                   |
 +---------------+----------------+
                 |
                 v
 +--------------------------------+
 | COMB output decode             |
 | stop_fetch/freeze_pipe/status  |
 +---------------+----------------+
                 |
                 v
 IF core pipeline control and DM status
```

## 4. FSM States

| State | Meaning | Key outputs |
| --- | --- | --- |
| `DBG_RUNNING` | Normal execution. | `running_o=1`, `halted_o=0`, no freeze. |
| `DBG_HALT_PENDING` | Fetch stopped while existing work drains. | `stop_fetch_o=1`, neither running nor halted. |
| `DBG_HALTED` | Pipeline is empty and Debug Mode owns GPR access. | `halted_o=1`, `freeze_pipe_o=1`, `stop_fetch_o=1`. |
| `DBG_STEP_RUNNING` | One instruction is released from halted state. | `running_o=1` until one retirement then re-halt. |

## 5. Transition Priority

Reset:

```text
state_q <- DBG_RUNNING
```

Transitions:

```text
DBG_RUNNING:
  (halt_req_i || trigger_req_i) && pipe_idle_i && !debug_busy_i -> DBG_HALTED
  halt_req_i || trigger_req_i                                  -> DBG_HALT_PENDING

DBG_HALT_PENDING:
  !halt_req_i && resume_req_i               -> DBG_RUNNING
  pipe_idle_i && !debug_busy_i              -> DBG_HALTED

DBG_HALTED:
  halt_req_i                                -> DBG_HALTED
  !halt_req_i && step_req_i && !debug_busy_i -> DBG_STEP_RUNNING
  !halt_req_i && resume_req_i && !debug_busy_i -> DBG_RUNNING

DBG_STEP_RUNNING:
  halt_req_i || trigger_req_i || retire_valid_i:
    pipe_idle_i                             -> DBG_HALTED
    otherwise                               -> DBG_HALT_PENDING
```

## 6. Output Logic

`stop_fetch_o` is asserted combinationally when `halt_req_i` or `trigger_req_i`
is visible, even before the FSM samples the request. This prevents an extra
instruction from being accepted behind a debug halt or trigger entry request.

`freeze_pipe_o` is asserted only in `DBG_HALTED`. During `DBG_HALT_PENDING`,
fetch is stopped but decode/execute are allowed to drain normally.

`running_o` is asserted in `DBG_RUNNING` and `DBG_STEP_RUNNING`. During
`DBG_HALT_PENDING`, both `running_o` and `halted_o` are zero so the Debug Module
can distinguish "not yet halted" from "already halted".

## 7. Target Support

The FSM is target-neutral synthesizable logic. IC and Virtex-7 builds use the
same behavior.
