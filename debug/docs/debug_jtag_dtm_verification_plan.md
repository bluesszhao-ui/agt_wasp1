# debug_jtag_dtm Verification Plan

## 1. Goals

Verify that `debug_jtag_dtm` provides a correct stage-1 JTAG DTM boundary:

```text
TAP reset and scan sequencing
IDCODE read
DTMCS read/write side effects
DMI READ/WRITE/NOP scan behavior
busy/sticky status handling
unknown IR fallback to BYPASS
clk_i/tck_i boundary through toggle handshake
```

## 2. Testbench

`tb_debug_jtag_dtm` drives JTAG through bit-bang tasks that traverse the TAP
state machine using `tms_i`, `tdi_i`, and sampled `tdo_o`. A behavioral DMI
target in the `clk_i` domain accepts one request, waits a programmable latency,
and returns deterministic response data.

## 3. Coverage Intent

| Area | Cases |
| --- | --- |
| Reset | `trst_ni`, `rst_ni`, reset-selected `IDCODE`. |
| TAP scans | IR update, DR capture/shift/update for `IDCODE`, `DTMCS`, `DMI`, `BYPASS`. |
| DTMCS | `version`, `abits`, `idle`, `dmistat`, `dmireset`, `dmihardreset`. |
| DMI normal path | Write request/response, read request/response, NOP response retrieval. |
| Busy path | Second non-NOP DMI scan while first request is in flight. |
| CDC | TCK-domain launch, clk-domain ready/valid, response toggle back to TCK. |
| Error containment | Unsupported IR maps to one-bit BYPASS. |

## 4. Pass Criteria

The module passes when:

```text
make -C debug lint-jtag-dtm
make -C debug sim-jtag-dtm
make -C debug lint-jtag-dtm-ic
make -C debug lint-jtag-dtm-fpga-v7
```

all complete without errors, and the simulation reports `tb_debug_jtag_dtm
PASS`.
