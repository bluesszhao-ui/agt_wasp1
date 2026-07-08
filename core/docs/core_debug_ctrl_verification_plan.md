# core_debug_ctrl Verification Plan

## 1. Scope

Verify the standalone Debug Mode control FSM with directed self-checking cases.

## 2. Testbench

```text
testbench: core/tb/tb_core_debug_ctrl.sv
filelist:  core/filelists/tb_core_debug_ctrl.f
target:    make -C core sim-core-debug-ctrl
clock:     10ns period, 100MHz
timescale: 1ns/1ps
```

## 3. Cases

| Case | Stimulus | Expected result |
| --- | --- | --- |
| Reset/running | Reset then release with idle pipe. | `running_o=1`, halted/freeze/stop deasserted. |
| Immediate halt | Assert halt while pipe is idle. | `stop_fetch_o` asserts immediately, next state halted. |
| Drain halt | Assert halt while pipe is not idle, then make idle. | Fetch stops, FSM waits, then halted. |
| Trigger halt | Assert trigger while pipe is not idle, then make idle. | Fetch stops immediately, FSM waits, then halted. |
| Cancel pending | Assert halt while not idle, then deassert halt and assert resume. | FSM returns running. |
| Busy resume block | Halt, assert resume while `debug_busy_i=1`. | FSM remains halted until busy clears. |
| Step | Halt, assert step, retire one instruction, drain. | FSM runs one instruction then re-enters halted. |
| Halt priority | Halted state with halt/resume/step all high. | FSM remains halted. |

## 4. Coverage Goal

The testbench must report coverage counters for halt, trigger, resume, step,
busy block, cancel, and priority paths. All counters must be non-zero.
