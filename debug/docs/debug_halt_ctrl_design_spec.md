# debug_halt_ctrl Design Spec

## 1. Scope

`debug_halt_ctrl` is a single-hart transaction controller. It does not modify
the core pipeline, register file, CSRs, or Debug Mode entry PC; those remain
core responsibilities for the later integration milestone.

## 2. Editable Control Diagram

editable source: `debug/docs/diagrams/debug_halt_ctrl_block.graffle`
preview export: none
detail level: L3
clock domains: `clk_i/rst_ni` for every `SEQ` block

The editable OmniGraffle diagram separates DM intent inputs, transition-priority
logic, the transaction FSM, request decode, core-control/status interfaces,
sticky status registers, and the DM status image into explicit `IF`, `COMB`,
and `SEQ` timing-class blocks. The transaction state, sticky acknowledgement
registers, transition logic, and request decode are not combined into a single
mixed-timing block.

The historical PNG `debug/docs/images/debug_halt_ctrl_fsm.png` remains as a
reference export.

## 3. Transaction FSM

| State | Meaning | Request output |
| --- | --- | --- |
| `IDLE` | No outstanding core control operation | none |
| `HALT_WAIT` | Waiting for `core_halted_i` | `core_halt_req_o=1` |
| `RESUME_WAIT` | Waiting for `core_running_i` | `core_resume_req_o=1` |

Transitions:

```text
IDLE -> HALT_WAIT:
  dmactive_i && haltreq_i && !core_halted_i

HALT_WAIT -> IDLE:
  !dmactive_i || !haltreq_i || core_halted_i || hart_reset_event_i

IDLE -> RESUME_WAIT:
  dmactive_i && !haltreq_i && resumereq_i && !core_running_i

RESUME_WAIT -> IDLE:
  !dmactive_i || (!haltreq_i && core_running_i) ||
  (haltreq_i && core_halted_i) || hart_reset_event_i

RESUME_WAIT -> HALT_WAIT:
  dmactive_i && haltreq_i && !core_halted_i
```

An already halted halt request and an already running resume request remain in
`IDLE`. The latter sets `resumeack_q` without issuing an unnecessary core pulse.

## 4. Sticky Status Registers

`resumeack_q` reset value is zero. A new resume transaction clears the previous
value. Resume completion sets it, and it then holds through ordinary idle
cycles so software polling can observe it.

`havereset_q` reset value is one. Runtime priority is:

```text
1. asynchronous rst_ni -> set
2. hart_reset_event_i  -> set and abort the transaction FSM
3. dmactive_i && ackhavereset_i -> clear
4. otherwise hold
```

## 5. Request Outputs

The request decode is combinational and separate from the state register:

```text
core_halt_req_o   = dmactive_i && state_q == HALT_WAIT
core_resume_req_o = dmactive_i && state_q == RESUME_WAIT
```

DM deactivation therefore suppresses requests without waiting for another state
transition. Hart status outputs are direct core-status mirrors.

## 6. Target Behavior

The implementation uses target-neutral synthesizable logic and includes
`wasp1_target_defs.svh`. Target selection does not change FSM or status behavior.
