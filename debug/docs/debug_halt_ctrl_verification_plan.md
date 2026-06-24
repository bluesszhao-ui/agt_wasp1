# debug_halt_ctrl Verification Plan

## 1. Goals

Verify the halt/resume transaction FSM and sticky hart status independently of
the DMI register file and core pipeline implementation.

## 2. Case Matrix

| Case | Stimulus | Expected result |
| --- | --- | --- |
| Reset | Assert `rst_ni=0` | requests/ack clear; havereset sets |
| Inactive | Toggle halt/resume while `dmactive=0` | no core request |
| Reset ack | Pulse ack while active | havereset clears |
| Reset priority | Assert reset event with ack | reset report sets and FSM aborts |
| Halt | Request halt with delayed core response | halt request holds until halted |
| Halt cancel | Clear halt before core response | halt request cancels |
| Already halted | Request halt while halted | no unnecessary request |
| Resume | Request resume with delayed core response | resume request holds until running |
| Sticky ack | Remove resumereq after completion | resumeack remains observable |
| New resume | Start another resume transaction | old resumeack clears |
| Already running | Resume a running core | immediate ack, no core request |
| Priority | Assert halt and resume together | halt path wins |
| Deactivate | Drop dmactive during a wait | request and resumeack clear |
| Random latency | Repeat halt/resume with deterministic delays | every request/status sequence matches |

## 3. Coverage Counters

The testbench must report checks for halt, resume, cancellation, priority,
reset, sticky acknowledgement, inactive behavior, held-request cycles, and
deterministic-random iterations.

## 4. Target Matrix

```text
make -C debug lint
make -C debug lint-ic
make -C debug lint-fpga-v7
make -C debug sim
```

All commands must pass before committing this module.
