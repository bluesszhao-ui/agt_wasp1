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
| VREF detection | Power target at supported IO voltage | Debugger enables level shifters only when VREF is valid |
| JTAG idle levels | Scope TCK/TMS/TDI/TDO/TRST/SRST | Idle levels match schematic and OpenOCD reset config |
| TAP scan | Run OpenOCD target probe | IDCODE `0x100001cf` is detected |
| DTM/DM discovery | Run OpenOCD RISC-V examine | hart 0, XLEN=32, and `misa=0x40000100` are detected |
| GDB attach | Run wasp1 GDB smoke/stress | GDB reads GPRs/PC, executes `stepi`, hits `hbreak *0x4`, and the stress flow hits simultaneous `hbreak *0x0` / `hbreak *0x4`, then detaches |
| UART channel | Open host serial port | wasp1 UART TX/RX path works for console/OTP tooling |
| Hardware package check | Run `make -C ftdi_debugger lint` | Pinout, OpenOCD config, Rev A schematic input, netlist, BOM, and docs remain mutually consistent |

## 3. Time-Sequenced Case Table Template

| Time | Action | Expected result | Observed result |
| --- | --- | --- | --- |
| 0s-5s | Plug debugger into host with target disconnected | USB enumerates; target drivers remain high-Z | TBD |
| 5s-15s | Power target and connect VREF | level shifters enable; reset pins idle high | TBD |
| 15s-30s | Start OpenOCD | TAP/DTM/hart detected | TBD |
| 30s-60s | Run GDB smoke/stress | register packet, PC read, `stepi`, one `hbreak`, and dual-resident `hbreak` stress pass | TBD |
| 60s-90s | Open UART channel | console or OTP programming transaction passes | TBD |
| offline | Run collateral checker | config, documentation, Rev A netlist, and BOM checks pass | PASS before hardware |

## 4. Required Evidence

The final hardware milestone should archive:

```text
schematic PDF
PCB layout/gerbers
BOM
Rev A schematic-input lint log
OpenOCD log
GDB smoke log
UART smoke log
scope captures for JTAG reset/shift timing
collateral checker log
```
