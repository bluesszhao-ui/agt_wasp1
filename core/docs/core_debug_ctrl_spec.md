# core_debug_ctrl Spec

## 1. Purpose

`core_debug_ctrl` owns the minimal core-side Debug Mode state required by the
RISC-V external debug path. It converts Debug Module halt/resume/step requests
into frontend stop/freeze controls and reports hart `halted`/`running` status.

## 2. Required Behavior

The controller must:

```text
reset to normal running state
stop accepting new frontend instructions as soon as halt_req_i is visible
wait for pipe_idle_i before reporting halted_o
keep the drained pipeline frozen while halted
block resume and step while debug_busy_i is asserted
allow resume from halted state when halt_req_i is low
allow a one-instruction step from halted state when step_req_i is asserted
return to halt-pending after one retire_valid_i during step
give halt_req_i priority over resume_req_i and step_req_i
```

## 3. Interface Contract

| Signal | Direction | Meaning |
| --- | --- | --- |
| `clk_i`, `rst_ni` | input | Core/debug state clock and active-low reset. |
| `halt_req_i` | input | Request entry to Debug Mode. |
| `resume_req_i` | input | Request exit from Debug Mode. |
| `step_req_i` | input | Request one retired instruction before re-halt. |
| `pipe_idle_i` | input | Pipeline and LSU outstanding state are drained. |
| `retire_valid_i` | input | One instruction retires in step-running state. |
| `debug_busy_i` | input | A halted GPR response is pending or being accepted. |
| `stop_fetch_o` | output | Stop frontend instruction acceptance. |
| `freeze_pipe_o` | output | Hold the drained pipeline while halted. |
| `halted_o` | output | Hart is halted in Debug Mode. |
| `running_o` | output | Hart is in normal run or step-running state. |

## 4. Non-Goals

This controller does not implement DCSR/DPC, trigger matching, JTAG DTM, or
OpenOCD packet transport. Those belong to later debug integration milestones.

## 5. Verification Requirements

Verification must cover reset/running, immediate halt, halt while draining,
halt-pending cancel, resume, debug-busy resume blocking, single-step re-halt,
and halt priority over simultaneous resume/step.
