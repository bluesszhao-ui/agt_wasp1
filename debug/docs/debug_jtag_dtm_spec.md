# debug_jtag_dtm Spec

## 1. Scope

`debug_jtag_dtm` is the stage-1 JTAG Debug Transport Module for wasp1. It
provides the RISC-V Debug v0.13-style JTAG TAP entry point and converts JTAG
DMI scans into the internal `debug_dmi_if` ready/valid protocol.

The module is intended to be the OpenOCD/GDB-facing transport block once it is
connected to the verified `debug` Debug Module top.

## 2. External Interface

| Port | Direction | Description |
| --- | --- | --- |
| `clk_i` | input | System debug clock for the internal DMI ready/valid interface. |
| `rst_ni` | input | Active-low reset for the system debug clock domain and DTM state. |
| `tck_i` | input | JTAG test clock. TAP state and scan registers update in this domain. |
| `trst_ni` | input | Active-low asynchronous JTAG reset. |
| `tms_i` | input | JTAG test mode select, sampled on rising `tck_i`. |
| `tdi_i` | input | JTAG serial data input, sampled on rising `tck_i` in shift states. |
| `tdo_o` | output | JTAG serial data output, updated on falling `tck_i`. |
| `dmi` | `debug_dmi_if.dtm` | Internal ready/valid DMI master in the `clk_i` domain. |
| `dtm_hardreset_o` | output | One-`tck_i` pulse when `DTMCS.dmihardreset` is written as one. |

## 3. Supported JTAG Instructions

| IR | Name | DR width | Behavior |
| --- | --- | ---: | --- |
| `5'b00001` | `IDCODE` | 32 | Shifts `IDCODE_VALUE`. Reset instruction selects `IDCODE`. |
| `5'b10000` | `DTMCS` | 32 | Reports DTM version, DMI address width, idle recommendation, and sticky DMI status. |
| `5'b10001` | `DMI` | 41 | Shifts `{addr[6:0], data[31:0], op[1:0]}` with op/status bits first. |
| `5'b11111` | `BYPASS` | 1 | Single-bit bypass path. |
| other | unsupported | 1 | Safely treated as `BYPASS`. |

## 4. DTMCS Contract

| Field | Bits | Behavior |
| --- | ---: | --- |
| `version` | `[3:0]` | `1`, meaning RISC-V Debug v0.13 JTAG DTM. |
| `abits` | `[9:4]` | `7`, matching `debug_dmi_pkg::DMI_ADDR_WIDTH`. |
| `dmistat` | `[11:10]` | `0` clear, `2` sticky failed, `3` sticky busy. Busy has priority over failed. |
| `idle` | `[14:12]` | `1`, recommends at least one Run-Test/Idle TCK between operations. |
| `dmireset` | `[16]` | Write-one clears sticky DMI busy/error status. Reads as zero. |
| `dmihardreset` | `[17]` | Write-one clears sticky status and pulses `dtm_hardreset_o`. Reads as zero. |

## 5. DMI Transaction Contract

A non-NOP DMI scan launches one ready/valid request when no request is already
in flight. The response from a completed transaction is returned by a later DMI
scan. If software scans another non-NOP DMI request while the previous request
is still in flight, the DTM returns `DMI_RESP_BUSY` and sets sticky busy status.

NOP DMI scans do not launch a new request and are used to retrieve the previous
response.

## 6. Reset Behavior

`trst_ni` or `rst_ni` assertion returns the TAP to Test-Logic-Reset, selects
`IDCODE`, clears sticky DMI status, clears any in-flight request state, and
drives `tdo_o` low.

## 7. Target Behavior

The RTL is target-neutral. IC, Xilinx Virtex-7 FPGA, and simulation targets must
expose the same JTAG instruction behavior, DTMCS fields, DMI scan ordering, and
ready/valid contract.
