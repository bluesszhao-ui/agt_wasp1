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
| 406ns-1096ns | Exercise data0/data1, command, busy, cmderr W1C, progbufsize, and WARL-zero abstractauto | Ownership, sticky error, capability image, and pulse behavior match | PASS |
| 1096ns-3676ns | Read/write all Program Buffer words, inject busy accesses, run 32 random accesses | DMI and full-array model agree; busy writes preserve payload | PASS |
| 3676ns-3826ns | Exercise NOP, reserved op, unknown address, and read-only writes | Response codes and state preservation match | PASS |
| 3826ns-3856ns | Replace consumed response with a new request | Zero-bubble response slot replacement succeeds | PASS |
| 3856ns-4816ns | Run 16 random data0 patterns | Every data bit round-trips under response backpressure | PASS |
| 4816ns-5006ns | Clear dmactive and attempt inactive executor/Program Buffer writes | All DM state clears and inactive writes have no effect | PASS |

## 4. Coverage Summary

```text
tb_debug_dmi_regs coverage: pass=205 read=89 write=74 status=4 pulse=2 busy=5 error=2 backpressure=163 zero_bubble=1 random=16 progbuf=4 progbuf_random=32
tb_debug_dmi_regs PASS
```

Coverage includes all four Program Buffer addresses, full-array comparison,
busy read and write side effects, dmactive clear, inactive write rejection, 32
seeded Program Buffer accesses, and every existing DMI control/transport case.

## 5. Capability Boundary

`abstractcs` now advertises `datacount=2 progbufsize=4`. `abstractauto` is
WARL-zero: reads return zero and writes succeed without enabling autoexec.
Postexec dispatch and core instruction execution are verified by the abstract,
debug-top, core, and wasp1 OpenOCD/GDB reports.
