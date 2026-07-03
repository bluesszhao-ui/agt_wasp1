# debug_jtag Verification Report

## 1. Result

Status: PASS

Commands:

```text
make -C debug lint-jtag
make -C debug sim-jtag
make -C debug lint
make -C debug sim
make -C debug lint-ic
make -C debug lint-fpga-v7
```

Observed simulation summary:

```text
tb_debug_jtag coverage: pass_count=52 dmi_reads=7 dmi_writes=7 halt=1 resume=1 gpr_write=1 gpr_read=1 reset=1
tb_debug_jtag PASS
```

## 2. Time-Sequenced Action Table

| Time range | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0 ns to 80 ns | Assert `rst_ni=0` and `trst_ni=0`; initialize core-debug model and JTAG pins. | TAP, DTM, and Debug Module reset. | PASS |
| 80 ns to 210 ns | Release reset and drive TAP reset-to-idle. | Debug Module inactive; core debug controls idle. | PASS |
| 210 ns to 560 ns | Scan default 32-bit IDCODE. | IDCODE matches DTM parameter. | PASS |
| 560 ns to 1260 ns | Select `DTMCS` and scan DTMCS. | `version=1`, `abits=7`, `dmistat=0`. | PASS |
| 1260 ns to 3275 ns | Write `dmcontrol.dmactive` through JTAG DMI, then read `dmstatus`. | DM active and running hart status visible with reset sticky set. | PASS |
| 3275 ns to 6355 ns | Write halt request through JTAG DMI and model core halted. | `core_debug.halt_req` asserts then retires; halted `dmstatus` reads back. | PASS |
| 6355 ns to 9435 ns | Write resume request through JTAG DMI and model core running. | `core_debug.resume_req` asserts then retires; resumeack `dmstatus` reads back. | PASS |
| 9435 ns to 12595 ns | Write `data0`, issue Access Register write x5, complete GPR response. | Core GPR write request x5 carries `0x13572468`; `abstractcs` stays clean. | PASS |
| 12595 ns to 15495 ns | Issue Access Register read x6 and complete GPR response. | `data0` reads back `0x24681357`. | PASS |
| 15495 ns to 17000 ns | Pulse hart reset event and clear with `ackhavereset`. | Sticky `havereset` is visible then clears. | PASS |

## 3. Coverage Summary

| Metric | Observed |
| --- | ---: |
| Self-checking assertions passed | 52 |
| JTAG DMI reads | 7 |
| JTAG DMI writes | 7 |
| Halt transactions | 1 |
| Resume transactions | 1 |
| GPR write transactions | 1 |
| GPR read transactions | 1 |
| Reset sequences | 1 |

## 4. Residual Risk

The integrated debug subsystem is verified through a bit-banged JTAG model, but
not yet through an external OpenOCD/GDB process. SoC-level JTAG pin exposure and
external debugger smoke tests remain future work.
