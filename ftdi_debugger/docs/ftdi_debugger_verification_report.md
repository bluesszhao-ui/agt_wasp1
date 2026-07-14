# ftdi_debugger Verification Report

## 1. Result

Status: PASS for the Rev A engineering package, routed PCB, local manufacturing
audit, and host OTP protocol/client milestone. Fabrication release remains
HOLD until the external gates in the manufacturing checklist are signed.

This report verifies documentation, OpenOCD
configuration, native KiCad hierarchy, design spec, editable architecture
diagram, netlist, BOM, fail-safe target-enable policy, and deterministic native
PCB implementation. KiCad 10.0.4 ERC passes with zero errors and zero warnings.
Final PCB DRC has zero errors, zero unconnected pads, and zero schematic parity
errors. The only two warnings are reviewed local-footprint overrides for J1 and
J2.

## 2. Command

```text
make -C ftdi_debugger lint
make -C ftdi_debugger host-test
make -C ftdi_debugger kicad-erc
make -C ftdi_debugger kicad-pcb-placement-drc
make -C ftdi_debugger kicad-pcb-final-drc
make -C ftdi_debugger kicad-pcb-manufacturing
make -C ftdi_debugger kicad-manufacturing-release
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
| 10s-11s | Import the reviewed routing session, complete USB VBUS/CC2 routing, and fill the In1.Cu ground plane | Every net is routed; USB and clock paths retain a continuous ground reference | PASS: 695 segments, 72 vias, 0 unconnected pads |
| 11s-12s | Audit USB copper lengths | Both connector-to-ESD and ESD-to-U1 pair skew are at most 0.50 mm | PASS: 0.463216 mm pre-ESD, 0.414214 mm post-ESD |
| 12s-13s | Run final KiCad DRC with schematic parity | Zero errors, unconnected pads, and parity errors; only reviewed local-footprint warnings remain | PASS: 0 errors, 0 unconnected pads, 0 parity errors, 2 reviewed warnings |
| 13s-14s | Render the 1600x1000 top-side 3D preview | Board outline, USB-C, FT2232H, translators, target connector, test points, and readable reference designators are visible without incoherent overlap | PASS |
| 14s-15s | Export and independently parse the manufacturing package | Nine Gerber X2 layers share 4.6 metric coordinates; outline is closed; drill inventory and 48 fitted positions are exact | PASS |
| 15s-16s | Render both assembly PDFs to raster for visual QA | No clipped board geometry, property noise, or unreadable footprint field overlap; DNP U2 is visibly crossed out | PASS; top drawing clear, bottom drawing correctly shows no bottom-side components |
| 16s-17s | Compile and unit-test the host OTP package | Framing, CRC, chunking, monotonic programming, range/alignment, verify, error, sequence, and lock cases pass | PASS |
| 17s-18s | Build and model-test target I-SRAM loader | Freestanding 2320-byte RV32I image and target protocol model pass | PASS |
| 18s-19s | Run complete-SoC UART/OTP loader regression | OTP-to-I-SRAM entry, 8N1 framing, program/read, CRC/transition errors, lock, and lock rejection pass | PASS: 15 checks |
| 19s-20s | Cross-check production BOM and build deterministic release archive | 57 references map to exact populations/footprints; archive contains controlled inputs and SHA-256 manifest | PASS: 48 POP, 1 DNP, 8 PCB_ONLY |

## 4. Coverage Summary

```text
PASS openocd reference cfg
PASS pinout document
PASS spec and plans
PASS host software collateral
PASS hardware package
PASS native KiCad schematic structure
PASS native KiCad routed PCB structure
PASS OmniGraffle coordinate/overlap audit
RESULT PASS ftdi_debugger collateral check
KiCad ERC: 0 errors, 0 warnings
KiCad PCB placement DRC: 170 expected unrouted items, 2 documented connector library overrides
KiCad final PCB DRC: 0 errors, 0 unconnected pads, 0 parity errors, 2 reviewed connector library overrides
Routed PCB audit: 695 segments, 72 vias, filled In1.Cu GND plane
USB copper skew: 0.463216 mm pre-ESD, 0.414214 mm post-ESD
Manufacturing audit: 9 Gerbers, closed 110x65 mm profile, 86 round PTH, 4 plated slots, 2 NPTH, 48 placements
Manufacturing support: IPC-D-356, board statistics, top/bottom assembly PDFs
Production BOM: 48 POP, 1 DNP, 8 PCB_ONLY; exact critical MPN and footprint audit PASS
Assembly PDF raster review: PASS
Host OTP unit tests: PASS
Target OTP protocol model: PASS
RV32I I-SRAM loader: PASS, 2320 bytes
SoC UART/OTP loader: PASS, 15 checks at 862 us simulated
Schematic preview: 5 A3 pages, 200 dpi source raster, light-background pixel audit PASS
```

Covered collateral:

```text
FT2232H VID/PID 0x0403:0x6010
Channel A MPSSE JTAG
Channel B UART
Windows Interface A WinUSB and Interface B VCP setup contract
Linux libusb/VCP udev access policy
Versioned UART OTP framing with CRC32
Host-side range, alignment, 0 -> 1, explicit confirmation, and verify safeguards
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
Native KiCad 110 mm x 65 mm four-layer routed PCB
USB_DIFF, POWER, VBUS, JTAG, and Default net classes
Board stackup, local DRC rules, DNP propagation, and reference-designator layout
695 routed segments, 72 through vias, and a filled In1.Cu GND plane
0.20 mm signals, 0.25 mm local power/JTAG, and 0.50 mm USB VBUS
USB pair length matching on both sides of ESD1
Gerber X2 copper/mask/silkscreen/edge output
Separate PTH/NPTH Excellon drill streams and maps
Position CSV with DNP U2 and PCB-only TP1-TP8 excluded, IPC-D-356, and board statistics
Top and mirrored-bottom assembly drawings
Q1-isolated VREF indicator
U4 A7/A8 defined unused-input bias
Eight exposed PCB test pads with net-to-reference consistency and assembly exclusions
Five-page A3 PDF and SVG review exports
```

## 5. Residual Scope

The following remain for the hardware milestone:

```text
Fabricator stackup and 90 ohm USB impedance confirmation
Independent second-person Gerber/drill CAM viewer review
Procurement stock, MOQ, lead-time, suffix, and alternate recheck
J1/J2 automated local-footprint geometry is complete; ordered-part human drawing sign-off remains
USB enumeration on a real board
VREF gating measurement
JTAG waveform/scope checks
OpenOCD FTDI attach to FPGA or silicon
GDB register/step/hbreak smoke through the FTDI board
UART console or OTP programming smoke through Channel B
```
