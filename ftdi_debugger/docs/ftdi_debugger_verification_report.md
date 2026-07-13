# ftdi_debugger Verification Report

## 1. Result

Status: PASS for Rev A detailed-design collateral, native schematic, and PCB
placement milestone.

This report verifies documentation, OpenOCD
configuration, native KiCad hierarchy, design spec, editable architecture
diagram, netlist, BOM, fail-safe target-enable policy, and deterministic native
PCB placement. KiCad 10.0.4 ERC passes with zero errors and zero warnings. PCB
placement DRC has zero unexpected categories and zero schematic parity issues;
170 unconnected items remain because routing has not started.

## 2. Command

```text
make -C ftdi_debugger lint
make -C ftdi_debugger kicad-erc
make -C ftdi_debugger kicad-pcb-placement-drc
```

## 3. Time-Sequenced Action Table

| Time window | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0s-1s | Parse `openocd/wasp1_ft2232h_reference.cfg` | FTDI driver, VID/PID, Channel A, layout masks, JTAG TAP ID, and RISC-V target stanza are present | PASS |
| 1s-2s | Parse `docs/ftdi_debugger_pinout.md` | ADBUS/BDBUS mapping, VREF range, OpenOCD masks, IDCODE, `stepi`, and `hbreak` expectations are documented | PASS |
| 2s-3s | Parse spec, design plan, and verification plan | FT2232H channel split, OpenOCD config, GDB bring-up, USB/JTAG/UART checks are documented | PASS |
| 3s-4s | Parse Rev A schematic-input, netlist, and BOM files | ADBUS/BDBUS nets, VREF-valid gating, FT2232H, level shifters, target connector, and OpenOCD bit masks are mutually consistent | PASS |
| 4s-5s | Parse the root and four child `.kicad_sch` files | Required sheets, U1/U4/Q1, TP8, safety nets, and unused-input termination nets exist | PASS |
| 5s-6s | Run KiCad 10.0.4 ERC over the hierarchy | No electrical-rule errors or warnings | PASS: 0 errors, 0 warnings |
| 6s-7s | Render the five-page A3 schematic preview at 100 dpi for visual QA | All pages have a light background; no page, title block, or component is clipped | PASS; mean page brightness 240-253/255 |
| 7s-8s | Audit `docs/diagrams/ftdi_debugger_revA_block.graffle` | Editable drawing has a visible 5 pt grid, grid-aligned geometry, explicit native line segments, V arrowheads, timing-class colors, and no unrelated overlap | PASS |
| 8s-9s | Parse native `.kicad_pcb`, `.kicad_dru`, and project net classes | Four copper layers, 1.6 mm stack, 57 footprints, DNP U2, board text, USB/power/JTAG classes, and local rules exist | PASS |
| 9s-10s | Run KiCad placement-stage DRC with schematic parity | No short, clearance, mask, silk, edge, or parity failures; unrouted items remain explicit | PASS: 0 unexpected categories, 170 expected unrouted items, 0 parity issues |
| 10s-11s | Render the 1600x1000 top-side 3D preview | Board outline, USB-C, FT2232H, translators, target connector, test points, and readable reference designators are visible without incoherent overlap | PASS |

## 4. Coverage Summary

```text
PASS openocd reference cfg
PASS pinout document
PASS spec and plans
PASS hardware package
PASS native KiCad schematic structure
PASS native KiCad PCB placement structure
PASS OmniGraffle coordinate/overlap audit
RESULT PASS ftdi_debugger collateral check
KiCad ERC: 0 errors, 0 warnings
KiCad PCB placement DRC: 170 expected unrouted items, 2 documented connector library overrides
Schematic preview: 5 A3 pages, 200 dpi source raster, light-background pixel audit PASS
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
Native KiCad root plus four electrical child sheets
Native KiCad 110 mm x 65 mm four-layer PCB placement
USB_DIFF, POWER, JTAG, and Default net classes
Board stackup, local DRC rules, DNP propagation, and reference-designator layout
Q1-isolated VREF indicator
U4 A7/A8 defined unused-input bias
Eight test points with net-to-reference consistency
Five-page A3 PDF and SVG review exports
```

## 5. Residual Scope

The following remain for the hardware milestone:

```text
PCB copper routing and final zero-unconnected DRC
Gerber, drill, placement, and fabrication drawing generation
BOM manufacturer/footprint review
USB enumeration on a real board
VREF gating measurement
JTAG waveform/scope checks
OpenOCD FTDI attach to FPGA or silicon
GDB register/step/hbreak smoke through the FTDI board
UART console or OTP programming smoke through Channel B
```
