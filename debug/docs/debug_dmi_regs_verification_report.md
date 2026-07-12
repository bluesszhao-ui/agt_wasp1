# debug_dmi_regs Verification Report

## 1. Result

Status: PASS.

## 2. Commands

```text
make -C debug sim-dmi-regs
make -C debug lint-dmi-regs
make -C debug lint-dmi-regs-ic
make -C debug lint-dmi-regs-fpga-v7
make -C debug lint
make -C debug sim
make lint
make -C wasp1 sim-openocd-gdb-smoke RBB_PORT=9831
```

## 3. Time-Sequenced Action Table

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0ns-36ns | Apply asynchronous reset | All control, abstract, response, and Program Buffer state clear | PASS |
| 36ns-66ns | Read identity status | Debug version/authentication image is correct | PASS |
| 66ns-226ns | Exercise activation, halt/resume, reset acknowledge | Required level and pulse priorities hold | PASS |
| 226ns-406ns | Exercise selected/nonexistent hart status | any/all status and request gating match hartsel | PASS |
| 406ns-1006ns | Exercise data0/data1, command, busy, cmderr W1C | Ownership, sticky error, and pulse behavior match | PASS |
| 1006ns-3586ns | Read/write all Program Buffer words, inject busy accesses, run 32 random accesses | DMI and full-array model agree; busy writes preserve payload | PASS |
| 3586ns-3736ns | Exercise NOP, reserved op, unknown address, and read-only writes | Response codes and state preservation match | PASS |
| 3736ns-3766ns | Replace consumed response with a new request | Zero-bubble response slot replacement succeeds | PASS |
| 3766ns-4726ns | Run 16 random data0 patterns | Every data bit round-trips under response backpressure | PASS |
| 4726ns-4916ns | Clear dmactive and attempt inactive executor/Program Buffer writes | All DM state clears and inactive writes have no effect | PASS |

## 4. Coverage Summary

```text
tb_debug_dmi_regs coverage: pass=202 read=87 write=73 status=4 pulse=2 busy=5 error=2 backpressure=160 zero_bubble=1 random=16 progbuf=4 progbuf_random=32
tb_debug_dmi_regs PASS
```

Coverage includes all four Program Buffer addresses, full-array comparison,
busy read and write side effects, dmactive clear, inactive write rejection, 32
seeded Program Buffer accesses, and every existing DMI control/transport case.

## 5. Capability Boundary

The storage is DMI-routable internally, but `abstractcs.progbufsize` remains
zero. This report does not claim postexec dispatch, core instruction execution,
or OpenOCD/GDB Program Buffer execution support. The existing OpenOCD/GDB smoke
still passes and observes `progbufsize=0`, confirming that the internal routing
did not create a premature capability claim.
