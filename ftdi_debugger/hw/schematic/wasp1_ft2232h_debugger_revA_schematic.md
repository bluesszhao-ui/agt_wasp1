# wasp1 FT2232H Debugger Rev A Schematic Input

## 1. Purpose

This document records the Rev A schematic contract for the external wasp1 FTDI
debugger. The corresponding native KiCad 10 hierarchy is implemented under
`hw/kicad/wasp1_ft2232h_debugger_revA/`. It is not yet a PCB release.

The design goal is:

```text
one USB cable -> FT2232H Channel A JTAG + FT2232H Channel B UART
```

Channel A must work with OpenOCD's standard `ftdi` adapter driver. Channel B is
reserved for the UART console and OTP programming flow.

## 2. Schematic Page Plan

| Page | Title | Main content |
| ---: | --- | --- |
| 1 | wasp1 FT2232H Debugger Rev A | Root hierarchy and four electrical child sheets |
| 2 | USB and local power | USB-C USB2 connector, ESD, CC resistors, polyfuse, 3.3 V rail |
| 3 | FT2232H core clock and EEPROM | FT2232H, 12 MHz clock, optional EEPROM, USB D+/D-, local decoupling |
| 4 | VREF detection and level shifting | Target VREF sense, fail-safe enable gate, translators, isolated VREF LED |
| 5 | Target connector ESD and test access | Keyed target header, damping, ESD, and eight test points |

## 3. Core Parts

| Refdes | Function | Preferred part class | Design note |
| --- | --- | --- | --- |
| J1 | Host USB connector | USB-C receptacle, USB2-only | Add 5.1 kOhm pulldowns on CC1/CC2 |
| U1 | USB/JTAG/UART bridge | FT2232HL, LQFP-64 | Channel A is MPSSE JTAG; Channel B is UART |
| Y1 | FTDI reference clock | ECS-3225MVQ-120-CN-TR, 12 MHz oscillator | 3.3 V, +/-25 ppm HCMOS drives OSCI; OSCO is no-connect |
| U2 | FTDI EEPROM | 93LC56BT-I/SN, SOIC-8, optional footprint | Allows product string and serial programming |
| U3 | VREF-valid detector | TLV7041DBVR open-drain comparator | Releases VREF_VALID high above the 1.57 V nominal threshold |
| U4 | Debugger-to-target level shifter | SN74AXC8T245PWR | Drives TCK/TMS/TDI/nTRST/nSRST/UART_RXD toward target |
| U5 | Target-to-debugger level shifter | SN74AXC2T245RSWR | Receives TDO/UART_TXD from target |
| U6 | Local 3.3 V regulator | AP2112K-3.3TRG1, SOT-25 | Generates VCC_3V3 from protected USB VBUS |
| U7 | Fail-safe enable gate | SN74LVC1G00DBVR NAND | SHIFT_OE_N is low only when VREF_VALID and TARGET_EN are high |
| Q1 | VREF LED isolation | 2N7002, SOT-23 | Drives D2 without loading the comparator output |
| J2 | Target connector | Keyed 2x7 header | Pinout follows `docs/ftdi_debugger_pinout.md` |

## 4. Voltage And Enable Policy

The debugger has two IO domains:

| Domain | Nominal rail | Owner | Notes |
| --- | --- | --- | --- |
| `VCC_3V3` | 3.3 V | debugger board | FT2232H local IO side and LEDs |
| `VREF` | 1.8 V to 3.3 V | target board | target-facing level-shifter side |

Target-facing outputs must be high-Z when `VREF_VALID=0` or `TARGET_EN=0`.
ADBUS6 is pulled down so the board remains isolated while FT2232H is in its
power-up UART mode. OpenOCD changes ADBUS6 to a high output through
`layout_init 0x0078 0x007b`. U7 generates active-low `SHIFT_OE_N`; a pull-up
keeps both translator OEs disabled if U7 is unpowered.

The debugger must not back-power the target through JTAG, reset, UART, ESD
parts, pull-ups, or indicator circuits.

The VREF-valid LED is not connected directly across `VREF_VALID`. Q1 senses the
comparator output at its gate and sinks D2 current from `VCC_3V3`, preserving
the logic-high margin at U7. Unused U4 A7/A8 inputs each have a 10 kOhm
pulldown; their bidirectional pins are not hard-shorted to ground.

## 5. FT2232H Channel A Mapping

| FT2232H signal | OpenOCD bit | Board net | Target signal | Direction |
| --- | ---: | --- | --- | --- |
| ADBUS0 | `0x0001` | `FT_A_TCK` | `TCK` | debugger to target |
| ADBUS1 | `0x0002` | `FT_A_TDI` | `TDI` | debugger to target |
| ADBUS2 | `0x0004` | `FT_A_TDO` | `TDO` | target to debugger |
| ADBUS3 | `0x0008` | `FT_A_TMS` | `TMS` | debugger to target |
| ADBUS4 | `0x0010` | `FT_A_NTRST` | `nTRST` | debugger to target |
| ADBUS5 | `0x0020` | `FT_A_NSRST` | `nSRST` | debugger to target |
| ADBUS6 | `0x0040` | `FT_TARGET_EN` | board enable gate | local safety control |

OpenOCD must continue to use:

```text
ftdi layout_init 0x0078 0x007b
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
TARGET_EN: 100 kOhm pulldown at U1/enable-gate input
SHIFT_OE_N: 100 kOhm pullup to VCC_3V3; route to U4/U5 active-low OE pins
ESD: place close to USB and target connector entry points
Test points: expose VCC_3V3, VCORE, VREF, VREF_VALID, TARGET_EN,
SHIFT_OE_N, TCK, TDO, GND
```

## 9. Release Gate

The native schematic must pass KiCad ERC with no errors or warnings before a
PCB is routed, and it must be checked against:

```text
docs/ftdi_debugger_pinout.md
openocd/wasp1_ft2232h_reference.cfg
hw/netlist/wasp1_ft2232h_debugger_revA_nets.csv
hw/bom/wasp1_ft2232h_debugger_revA_bom.csv
```
