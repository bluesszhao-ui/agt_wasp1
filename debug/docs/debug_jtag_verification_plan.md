# debug_jtag Verification Plan

## 1. Goals

Verify the integrated JTAG-to-Debug-Module path:

```text
JTAG IDCODE and DTMCS visibility
JTAG DMI writes reaching Debug Module registers
JTAG DMI reads returning Debug Module register data
haltreq/resumereq propagation to core_debug
RV32 GPR Access Register abstract command path
hart reset sticky status and ackhavereset through JTAG DMI
```

## 2. Testbench

`tb_debug_jtag` drives only JTAG pins for DMI traffic. It uses TAP bit-bang
tasks for IR/DR scans and a simple `core_debug` behavioral model for halted,
running, and GPR response behavior.

## 3. Coverage Intent

| Area | Cases |
| --- | --- |
| Reset | Combined `rst_ni`/`trst_ni`, TAP reset-to-idle, inactive Debug Module. |
| JTAG transport | Default `IDCODE`, `DTMCS`, DMI read/write/NOP path. |
| Debug activation | `dmcontrol.dmactive` write and `dmstatus` readback. |
| Hart control | JTAG-issued halt and resume requests reaching `core_debug`. |
| Abstract command | JTAG-issued GPR write x5 and read x6. |
| Sticky status | `havereset` observation and `ackhavereset` clear. |

## 4. Pass Criteria

The integrated wrapper passes when:

```text
make -C debug lint-jtag
make -C debug sim-jtag
make -C debug lint-jtag-ic
make -C debug lint-jtag-fpga-v7
```

all complete without errors, and the simulation reports `tb_debug_jtag PASS`.
