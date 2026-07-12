# debug_progbuf_exec Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```text
make -C debug sim-progbuf-exec
make -C debug lint-progbuf-exec
make -C debug lint-progbuf-exec-ic
make -C debug lint-progbuf-exec-fpga-v7
plutil -lint debug/docs/diagrams/debug_progbuf_exec_fsm.graffle
python3 docs/tools/audit_graffle_diagram.py debug/docs/diagrams/debug_progbuf_exec_fsm.graffle
```

## 3. Time-Sequenced Action Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-36ns | Reset and idle-output checks | IDLE, no request/response ownership | PASS |
| 36ns-66ns | Pulse start while dmactive is zero and observe idle hold | No request, busy, completion, or stale error | PASS |
| 66ns-96ns | EBREAK in word zero | Success without a core request | PASS |
| 96ns-346ns | Three ordered instructions, request stalls, response latency, busy start | Stable exactly-once requests then EBREAK success | PASS |
| 346ns-396ns | Core reports execution error on word zero | Stop with `CMDERR_EXCEPTION` | PASS |
| 396ns-576ns | Execute four words without EBREAK | Four responses, then `CMDERR_EXCEPTION` | PASS |
| 576ns-666ns | Remove halted state in ISSUE and WAIT | Both points return `CMDERR_HALT_RESUME` | PASS |
| 666ns-736ns | Clear dmactive in ISSUE and WAIT | Both points abort silently and scrub state | PASS |
| 736ns-796ns | Assert asynchronous reset with an outstanding instruction | Immediate idle, no stale completion | PASS |
| 796ns-816ns | Start while hart is not halted | Complete with `CMDERR_HALT_RESUME` | PASS |
| 816ns-8376ns | Run 64 seeded programs with random EBREAK index and handshake delays | Ordered exactly-once execution and clean success | PASS |

## 4. Coverage Summary

```text
tb_debug_progbuf_exec coverage: pass=71 req=104 rsp=101 backpressure=150 exception=2 halt_loss=3 dm_abort=2 inactive_start=1 reset_abort=1 busy_start=1 random=64 index_seen=0xf
tb_debug_progbuf_exec PASS
```

All five states, all four indices, request backpressure, response latency,
immediate/late EBREAK, core exception, missing EBREAK, halt loss in ISSUE/WAIT,
DM abort in ISSUE/WAIT, inactive-DM start rejection, reset abort, busy start,
and 64 deterministic-random legal programs are covered. The three accepted
requests without responses are intentional outstanding-transaction abort cases:
halt loss, DM abort, and reset.

## 5. Residual Integration Scope

The mock core validates the sequencer contract but does not execute RV32
instructions. DMI routing, postexec dispatch, halted-core instruction injection,
architectural side-effect checks, and OpenOCD/GDB Program Buffer regression
remain gated until the complete path is integrated.
