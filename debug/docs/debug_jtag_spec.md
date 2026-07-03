# debug_jtag Spec

## 1. Scope

`debug_jtag` is the stage-1 JTAG-facing debug integration wrapper. It connects
the verified `debug_jtag_dtm` transport to the verified `debug` Debug Module.

The wrapper adds no new architectural registers. JTAG-visible transport state is
owned by `debug_jtag_dtm`; DMI-visible Debug Module state is owned by `debug`.

## 2. External Contract

| Interface or signal | Direction | Required behavior |
| --- | --- | --- |
| `clk_i`, `rst_ni` | input | Debug Module/system clock and active-low reset. |
| `tck_i`, `trst_ni` | input | JTAG TAP clock and active-low TAP reset. |
| `tms_i`, `tdi_i`, `tdo_o` | JTAG pins | Standard serial TAP controls/data. |
| `debug_if.dm core_debug` | initiator/control | Halt/resume/GPR debug channel to the single core. |
| `hart_reset_event_i` | input | One-cycle hart reset observation for sticky `dmstatus.havereset`. |
| `dmactive_o` | output | Debug Module active state from `dmcontrol.dmactive`. |
| `ndmreset_o` | output | Non-debug reset request from `dmcontrol.ndmreset`. |
| `dtm_hardreset_o` | output | One-`tck_i` pulse from `DTMCS.dmihardreset`. |

## 3. Required Behavior

JTAG DMI scans must reach the Debug Module register file through the internal
`debug_dmi_if` link. The integrated path must support:

```text
IDCODE and DTMCS scans
DMI read/write/NOP scans
Debug Module activation through dmcontrol.dmactive
haltreq and resumereq delivery to core_debug
dmstatus running/halted/resumeack/havereset reporting
RV32 GPR Access Register abstract commands
```

## 4. Unsupported Stage-1 Scope

The following remain outside this wrapper:

```text
SoC top-level JTAG package pin muxing
OpenOCD/GDB external process test
single-step
program buffer
abstract memory access
debug ROM
```

## 5. Target Support

The wrapper is structural and target-neutral. Target macros must not change the
JTAG instruction behavior, DMI protocol behavior, Debug Module register map, or
core-debug side effects.
