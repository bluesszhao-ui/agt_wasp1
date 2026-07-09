# wasp1 FT2232H Debugger Rev A Schematic Input

## 1. Purpose

This document is the Rev A schematic-input package for the external wasp1 FTDI
debugger. It is not a PCB release. It freezes the intended schematic pages,
major parts, and board-level signal ownership before the EDA schematic is drawn.

The design goal is:

```text
one USB cable -> FT2232H Channel A JTAG + FT2232H Channel B UART
```

Channel A must work with OpenOCD's standard `ftdi` adapter driver. Channel B is
reserved for the UART console and OTP programming flow.

## 2. Schematic Page Plan

| Page | Title | Main content |
| ---: | --- | --- |
| 1 | USB and local power | USB-C USB2 connector, ESD, CC resistors, polyfuse, 3.3 V rail |
| 2 | FT2232H core | FT2232H, 12 MHz clock, optional EEPROM, USB D+/D-, local decoupling |
| 3 | VREF and level shifting | target VREF sense, VREF-valid comparator, JTAG/UART level shifters |
| 4 | Target connector and indicators | keyed target header, series damping, LEDs, test points |

## 3. Core Parts

| Refdes | Function | Preferred part class | Design note |
| --- | --- | --- | --- |
| J1 | Host USB connector | USB-C receptacle, USB2-only | Add 5.1 kOhm pulldowns on CC1/CC2 |
| U1 | USB/JTAG/UART bridge | FT2232HL or equivalent FT2232H family part | Channel A is MPSSE JTAG; Channel B is UART |
| Y1 | FTDI reference clock | 12 MHz crystal or oscillator | Follow the FTDI datasheet load-capacitance guidance |
| U2 | FTDI EEPROM | 93LC56B/93C56 class, optional footprint | Allows product string and serial programming |
| U3 | VREF-valid detector | Low-power comparator or supervisor | Enables target-facing drivers only when VREF is valid |
| U4 | Debugger-to-target level shifter | 8-bit dual-supply direction-fixed translator | Drives TCK/TMS/TDI/nTRST/nSRST/UART_RXD toward target |
| U5 | Target-to-debugger level shifter | 2-bit dual-supply direction-fixed translator | Receives TDO/UART_TXD from target |
| J2 | Target connector | Keyed 2x7 header | Pinout follows `docs/ftdi_debugger_pinout.md` |

## 4. Voltage And Enable Policy

The debugger has two IO domains:

| Domain | Nominal rail | Owner | Notes |
| --- | --- | --- | --- |
| `VCC_3V3` | 3.3 V | debugger board | FT2232H local IO side and LEDs |
| `VREF` | 1.8 V to 3.3 V | target board | target-facing level-shifter side |

Target-facing outputs must be high-Z when `VREF_VALID=0`. The Rev A schematic
implements this by tying the output enable of U4 and U5 to `VREF_VALID` with the
polarity required by the selected level-shifter parts.

The debugger must not back-power the target through JTAG, reset, UART, ESD
parts, pull-ups, or indicator circuits.

## 5. FT2232H Channel A Mapping

| FT2232H signal | OpenOCD bit | Board net | Target signal | Direction |
| --- | ---: | --- | --- | --- |
| ADBUS0 | `0x0001` | `FT_A_TCK` | `TCK` | debugger to target |
| ADBUS1 | `0x0002` | `FT_A_TDI` | `TDI` | debugger to target |
| ADBUS2 | `0x0004` | `FT_A_TDO` | `TDO` | target to debugger |
| ADBUS3 | `0x0008` | `FT_A_TMS` | `TMS` | debugger to target |
| ADBUS4 | `0x0010` | `FT_A_NTRST` | `nTRST` | debugger to target |
| ADBUS5 | `0x0020` | `FT_A_NSRST` | `nSRST` | debugger to target |

OpenOCD must continue to use:

```text
ftdi layout_init 0x0038 0x003b
ftdi layout_signal nTRST -data 0x0010 -oe 0x0010
ftdi layout_signal nSRST -data 0x0020 -oe 0x0020
```

## 6. FT2232H Channel B Mapping

| FT2232H signal | Board net | Target signal | Direction |
| --- | --- | --- | --- |
| BDBUS0 | `FT_B_TXD` | `UART_RXD` | debugger to target |
| BDBUS1 | `FT_B_RXD` | `UART_TXD` | target to debugger |

Channel B must enumerate as a standard FTDI serial port. No custom USB firmware
is allowed for Rev A.

## 7. Target Connector Pinout

| J2 pin | Net | Requirement |
| ---: | --- | --- |
| 1 | `VREF` | Target IO reference input |
| 2 | `GND` | Return |
| 3 | `TCK` | Series damping footprint near driver |
| 4 | `GND` | Return |
| 5 | `TMS` | Series damping footprint near driver |
| 6 | `GND` | Return |
| 7 | `TDI` | Series damping footprint near driver |
| 8 | `TDO` | No debugger-side pull that fights target output |
| 9 | `nTRST` | Active-low, target-side pull-up recommended |
| 10 | `nSRST` | Active-low, target-side pull-up recommended |
| 11 | `UART_TXD` | Target TX into debugger |
| 12 | `UART_RXD` | Debugger TX into target |
| 13 | `GND` | Return |
| 14 | `NC_KEY` | Key or no-connect |

## 8. PCB Constraints For The Later Layout Step

```text
USB D+/D-: route as controlled differential pair according to board stackup
TCK/TMS/TDI/nTRST/nSRST/UART_RXD: place series resistors near U4 outputs
TDO/UART_TXD: avoid pull devices that load target outputs
VREF: keep as sense/level-shifter rail, not a board power source
ESD: place close to USB and target connector entry points
Test points: expose VCC_3V3, VREF, VREF_VALID, TCK, TMS, TDI, TDO, GND
```

## 9. Release Gate

Before a PCB is routed, the EDA schematic must be checked against:

```text
docs/ftdi_debugger_pinout.md
openocd/wasp1_ft2232h_reference.cfg
hw/netlist/wasp1_ft2232h_debugger_revA_nets.csv
hw/bom/wasp1_ft2232h_debugger_revA_bom.csv
```

