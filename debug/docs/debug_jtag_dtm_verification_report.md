# debug_jtag_dtm Verification Report

## 1. Result

Status: PASS

Command:

```text
make -C debug lint-jtag-dtm
make -C debug sim-jtag-dtm
make -C debug lint
make -C debug sim
make -C debug lint-ic
make -C debug lint-fpga-v7
```

Observed simulation summary:

```text
tb_debug_jtag_dtm coverage: pass_count=20 idcode=1 dtmcs=4 busy=3 dmi_req=3 dmi_rsp=3
tb_debug_jtag_dtm PASS
```

## 2. Time-Sequenced Action Table

| Time range | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0 ns to 60 ns | Assert `rst_ni=0`, `trst_ni=0`; initialize JTAG pins. | TAP and DMI sequencer reset. | PASS |
| 60 ns to 190 ns | Release resets and drive JTAG reset-to-idle sequence. | TAP enters Run-Test/Idle with `IDCODE` selected. | PASS |
| 190 ns to 540 ns | Scan default DR as 32-bit IDCODE. | `tdo_o` returns `IDCODE_VALUE`. | PASS |
| 540 ns to 1240 ns | Select `DTMCS` IR and scan 32-bit DTMCS. | `version=1`, `abits=7`, `idle=1`, `dmistat=0`. | PASS |
| 1240 ns to 1350 ns | Write `DTMCS.dmihardreset=1`. | `dtm_hardreset_o` pulses once and sticky status clears. | PASS |
| 1350 ns to 2630 ns | Select `DMI`, launch WRITE to `DATA0`, wait `clk_i` and TCK idle cycles, then scan NOP. | DMI model accepts request, response status success, response returns written data/address. | PASS |
| 2630 ns to 3800 ns | Launch READ from `DMSTATUS`, wait, then scan NOP. | Response status success, response data matches model register. | PASS |
| 3800 ns to 5600 ns | Configure long DMI latency and issue second non-NOP DMI scan while first request is in flight. | DMI scan returns busy and sticky busy is set. | PASS |
| 5600 ns to 6600 ns | Select `DTMCS`, read sticky status, write `dmireset`, wait, read again. | `dmistat` reports busy before clear and success after clear. | PASS |
| 6600 ns to 7600 ns | Select unsupported IR and scan one-bit DR. | Unsupported IR behaves as BYPASS with capture zero. | PASS |
| 7600 ns to 8000 ns | Final clock drain and scoreboard checks. | At least three DMI requests and responses completed. | PASS |

## 3. Coverage Summary

| Metric | Observed |
| --- | ---: |
| Self-checking assertions passed | 20 |
| IDCODE checks | 1 |
| DTMCS field checks | 4 |
| Busy/sticky checks | 3 |
| DMI requests accepted by model | 3 |
| DMI responses returned by model | 3 |

## 4. Residual Risk

This stage verifies protocol behavior against the internal DMI ready/valid
model. Integrated `debug_jtag`, SoC top-level JTAG pin exposure, and external
OpenOCD/GDB smoke are covered by later debug and wasp1 verification reports.
