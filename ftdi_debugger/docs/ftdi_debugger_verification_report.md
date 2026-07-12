# ftdi_debugger Verification Report

## 1. Result

Status: PASS for Rev A detailed-design collateral consistency.

This is a pre-hardware verification report. It verifies documentation and
OpenOCD configuration consistency before formal EDA schematic/PCB work starts.
It now also checks the Rev A design spec, editable architecture diagram,
schematic-input, netlist, BOM, and fail-safe target-enable policy.
Electrical and board-level checks remain TBD until hardware exists.

## 2. Command

```text
make -C ftdi_debugger lint
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0s-1s | Parse `openocd/wasp1_ft2232h_reference.cfg` | FTDI driver, VID/PID, Channel A, layout masks, JTAG TAP ID, and RISC-V target stanza are present | PASS |
| 1s-2s | Parse `docs/ftdi_debugger_pinout.md` | ADBUS/BDBUS mapping, VREF range, OpenOCD masks, IDCODE, `stepi`, and `hbreak` expectations are documented | PASS |
| 2s-3s | Parse spec, design plan, and verification plan | FT2232H channel split, OpenOCD config, GDB bring-up, USB/JTAG/UART checks are documented | PASS |
| 3s-4s | Parse Rev A schematic-input, netlist, and BOM files | ADBUS/BDBUS nets, VREF-valid gating, FT2232H, level shifters, target connector, and OpenOCD bit masks are mutually consistent | PASS |
| 4s-5s | Audit `docs/diagrams/ftdi_debugger_revA_block.graffle` | Editable drawing has a visible 5 pt grid, grid-aligned geometry, explicit native line segments, V arrowheads, timing-class colors, and no unrelated overlap | PASS |

## 4. Coverage Summary

```text
PASS openocd reference cfg
PASS pinout document
PASS spec and plans
PASS hardware package
PASS OmniGraffle coordinate/overlap audit
RESULT PASS ftdi_debugger collateral check
```

Covered collateral:

```text
FT2232H VID/PID 0x0403:0x6010
Channel A MPSSE JTAG
Channel B UART
ADBUS0..ADBUS5 JTAG/reset mapping
BDBUS0..BDBUS1 UART mapping
OpenOCD layout_init 0x0078 0x007b
ADBUS6 TARGET_EN safety gate
VREF_VALID and TARGET_EN fail-safe OE equation
nTRST/nSRST masks
wasp1 TAP expected ID 0x100001cf
GDB stepi and hbreak smoke expectations
Rev A schematic-input page plan
Rev A frozen component selections and power architecture
Rev A netlist-level FT2232H/JTAG/UART/VREF mapping
Rev A BOM key components
Editable Rev A architecture/block diagram
```

## 5. Residual Scope

The following remain for the hardware milestone:

```text
schematic ERC
PCB DRC
BOM manufacturer/footprint review
USB enumeration on a real board
VREF gating measurement
JTAG waveform/scope checks
OpenOCD FTDI attach to FPGA or silicon
GDB register/step/hbreak smoke through the FTDI board
UART console or OTP programming smoke through Channel B
```
