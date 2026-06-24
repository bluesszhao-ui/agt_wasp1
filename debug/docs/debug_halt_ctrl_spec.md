# debug_halt_ctrl Spec

## 1. Purpose

`debug_halt_ctrl` controls halt and resume transactions for wasp1's single
hart. It sits between Debug Module register intent and the core's Debug Mode
request/status signals.

## 2. Clock and Reset

All state uses `clk_i`. `rst_ni` is asynchronous and active low. Reset aborts
pending control transactions, clears resume acknowledgement, and sets the
sticky hart-reset report.

## 3. Halt Requirements

When the active Debug Module asserts `haltreq_i` while the core is not halted,
the controller must assert `core_halt_req_o` until one of these events occurs:

```text
core_halted_i becomes 1
haltreq_i is cancelled
dmactive_i becomes 0
hart_reset_event_i occurs
```

No halt request is needed when the core already reports halted.

## 4. Resume Requirements

When `resumereq_i` is observed without a simultaneous halt request, the
controller must request resume until the core reports running. Once a resume
transaction has started, later deassertion of `resumereq_i` must not cancel the
core request.

`hart_resumeack_o` must assert when the requested hart is running. It remains
sticky so DMI polling cannot miss a short core event. A new resume transaction,
DM deactivation, hart reset, or controller reset clears the old acknowledgement.

If halt and resume are requested together, halt has priority.

## 5. Hart Status Requirements

`hart_halted_o` and `hart_running_o` directly mirror core status. The controller
must not infer one status by negating the other because the core may briefly
report neither while changing execution state.

`hart_havereset_o` is sticky. It sets on controller reset or
`hart_reset_event_i`, and clears only on `ackhavereset_i` while the Debug Module
is active. A same-cycle reset event has priority over acknowledgement.

## 6. Implementation Targets

The module must be synthesizable and behaviorally identical for generic
simulation, IC, and Xilinx Virtex-7 FPGA target macros.

## 7. Verification Requirements

Verification must cover normal and delayed halt/resume, already halted/running
cases, cancellation, halt priority, DM deactivation, sticky acknowledgement,
reset-event priority, status mirroring, and deterministic-random latencies.
