# ftdi_debugger Verification Plan

## 1. Goals

Verify that the FTDI debugger can replace the remote-bitbang simulation adapter
for real FPGA/board-level debug while preserving the same OpenOCD/GDB target
behavior.

## 2. Bring-Up Checks

| Check | Method | Pass Criteria |
| --- | --- | --- |
| USB enumeration | Connect to host and inspect FTDI device | FT2232H appears with expected VID/PID and serial |
| Channel mode | Run OpenOCD ftdi driver | Channel A enters MPSSE/JTAG without errors |
| VREF and ownership gating | Sweep VREF and toggle OpenOCD TARGET_EN | Level shifters enable only when VREF is valid and TARGET_EN is high |
| JTAG idle levels | Scope TCK/TMS/TDI/TDO/TRST/SRST | Idle levels match schematic and OpenOCD reset config |
| TAP scan | Run OpenOCD target probe | IDCODE `0x100001cf` is detected |
| DTM/DM discovery | Run OpenOCD RISC-V examine | hart 0, XLEN=32, and `misa=0x40000100` are detected |
| GDB attach | Run wasp1 GDB smoke/stress | GDB reads GPRs/PC, executes `stepi`, hits `hbreak *0x4`, and the stress flow hits simultaneous `hbreak *0x0` / `hbreak *0x4`, then detaches |
| UART channel | Open host serial port | wasp1 UART TX/RX path works for console/OTP tooling |
| Hardware package check | Run `make -C ftdi_debugger lint` | Pinout, OpenOCD config, Rev A design spec, schematic input, netlist, BOM, and docs remain mutually consistent |
| PCB placement DRC | Run `make -C ftdi_debugger kicad-pcb-placement-drc` | No electrical/geometry/silk/parity category remains; unconnected items are explicit until routing |
| Final PCB DRC | Run `make -C ftdi_debugger kicad-pcb-final-drc` | Zero unconnected items, shorts, clearance errors, silk violations, parity errors, and unreviewed warnings |
| Routed-board audit | Read the committed PCB through KiCad `pcbnew` | Four copper layers, filled In1.Cu GND plane, reviewed line widths/J1 orientation, substantial routing, and both USB pair skews at most 0.50 mm |
| Manufacturing output | Run `make -C ftdi_debugger kicad-pcb-manufacturing` | Final DRC passes first; nine Gerbers, separate PTH/NPTH drills, 56 populated positions, IPC-D-356, statistics, and assembly PDFs pass structural audit |
| Assembly drawing QA | Render both generated PDFs to images | Board geometry is unclipped, footprint properties do not obscure the drawing, U2 is marked DNP, and the empty bottom assembly state is explicit |

## 3. Time-Sequenced Case Table Template

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0s-5s | Plug debugger into host with target disconnected | USB enumerates; TARGET_EN pulldown and absent VREF keep target drivers high-Z | TBD |
| 5s-15s | Power target, connect VREF, then start OpenOCD | VREF alone leaves drivers disabled; TARGET_EN then enables them and reset pins idle high | TBD |
| 15s-30s | Start OpenOCD | TAP/DTM/hart detected | TBD |
| 30s-60s | Run GDB smoke/stress | register packet, PC read, `stepi`, one `hbreak`, and dual-resident `hbreak` stress pass | TBD |
| 60s-90s | Open UART channel | console or OTP programming transaction passes | TBD |
| offline | Run collateral checker | config, documentation, Rev A netlist, and BOM checks pass | PASS before hardware |
| offline | Run placement-stage PCB DRC and 3D preview | functional placement is electrically consistent and visually reviewable; unrouted nets remain explicit | PASS before routing |
| offline | Run final DRC and routed-board audit | no DRC error, unconnected pad, or parity error; both USB skew checks pass | PASS: 2 reviewed footprint warnings only |
| offline | Generate and visually review manufacturing outputs | all required files pass structural audit; top/bottom assembly plots are legible | PASS before independent release review |

## 4. Required Evidence

The final hardware milestone should archive:

```text
schematic PDF
PCB layout/gerbers
placement and final-routing DRC reports
BOM
Rev A schematic-input lint log
OpenOCD log
GDB smoke log
UART smoke log
scope captures for JTAG reset/shift timing
collateral checker log
```
