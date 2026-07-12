# ftdi_debugger Pinout and Schematic Constraints

## 1. Purpose

This document freezes the stage-1 FT2232H debugger pin mapping used by the
checked-in OpenOCD configuration. It is the schematic-input contract for the
first hardware revision.

The debugger is outside the wasp1 chip RTL. It connects a host USB port to the
wasp1 JTAG pins and reserves a second FTDI channel for UART console or OTP
programming.

## 2. FT2232H Channel Assignment

| FT2232H channel | Mode | Function |
| --- | --- | --- |
| Channel A | MPSSE | JTAG to wasp1 Debug Module |
| Channel B | UART | wasp1 UART console / OTP programming transport |

Channel A is selected in OpenOCD with:

```text
ftdi channel 0
```

## 3. Channel A JTAG Mapping

| FT2232H signal | OpenOCD bit | Direction from debugger | wasp1 target signal | Reset/idle intent |
| --- | ---: | --- | --- | --- |
| ADBUS0 | `0x0001` | Output | `jtag_tck_i` | Low when idle |
| ADBUS1 | `0x0002` | Output | `jtag_tdi_i` | Low when idle |
| ADBUS2 | `0x0004` | Input | `jtag_tdo_o` | Input, no drive |
| ADBUS3 | `0x0008` | Output | `jtag_tms_i` | High when idle |
| ADBUS4 | `0x0010` | Output | `jtag_trst_ni` | High inactive |
| ADBUS5 | `0x0020` | Output | target `srst_ni` if present | High inactive |
| ADBUS6 | `0x0040` | Output | board `TARGET_EN` | High only after OpenOCD configures Channel A |

The matching OpenOCD low-byte configuration is:

```text
ftdi layout_init 0x0078 0x007b
ftdi layout_signal nTRST -data 0x0010 -oe 0x0010
ftdi layout_signal nSRST -data 0x0020 -oe 0x0020
```

`0x0078` drives TMS, nTRST, nSRST, and TARGET_EN high at initialization.
`0x007b` makes TCK, TDI, TMS, nTRST, nSRST, and TARGET_EN outputs while
leaving TDO as an input. A 100 kOhm board pulldown holds TARGET_EN low before
OpenOCD takes ownership.

## 4. Channel B UART Mapping

| FT2232H signal | Direction from debugger | wasp1 target signal | Requirement |
| --- | --- | --- | --- |
| BDBUS0 | Output | `uart_rx_i` | Host TX drives target RX through level shifting |
| BDBUS1 | Input | `uart_tx_o` | Target TX drives host RX through level shifting |
| BDBUS2..BDBUS7 | Unused in stage 1 | NC/test pads optional | Do not drive target pins without a documented use |

The UART channel should enumerate as a standard FTDI serial port. No custom USB
firmware is required.

## 5. Target Header

The first hardware revision should expose one keyed target header:

| Pin | Signal | Direction | Requirement |
| ---: | --- | --- | --- |
| 1 | `VREF` | Target to debugger | Target IO reference voltage sense |
| 2 | `GND` | Ground | Adjacent ground for signal return |
| 3 | `TCK` | Debugger to target | JTAG clock |
| 4 | `GND` | Ground | Adjacent ground for signal return |
| 5 | `TMS` | Debugger to target | JTAG mode select |
| 6 | `GND` | Ground | Adjacent ground for signal return |
| 7 | `TDI` | Debugger to target | JTAG data into target |
| 8 | `TDO` | Target to debugger | JTAG data out of target |
| 9 | `nTRST` | Debugger to target | Optional TAP reset, pull up on target side |
| 10 | `nSRST` | Debugger to target | Optional system reset, pull up on target side |
| 11 | `UART_TXD` | Target to debugger | Target UART TX |
| 12 | `UART_RXD` | Debugger to target | Target UART RX |
| 13 | `GND` | Ground | Cable return |
| 14 | `NC/KEY` | No connect | Key or reserved pin |

Schematic work may change the mechanical connector, but any changed pinout must
update this document, the PCB silk, and `openocd/wasp1_ft2232h_reference.cfg`
in the same commit.

## 6. Electrical Constraints

The debugger must not drive target-facing JTAG, reset, or UART outputs unless a
valid `VREF` is present and OpenOCD has asserted `TARGET_EN`.

Target-facing IO must be level shifted to `VREF`. The stage-1 allowed target
range is:

```text
1.8 V <= VREF <= 3.3 V
```

Recommended schematic constraints:

```text
USB connector: ESD protection and controlled shield/ground strategy
FT2232H: 12 MHz reference crystal or oscillator per datasheet circuit
EEPROM: optional but footprint recommended for product string/serial config
VREF sense: comparator plus TARGET_EN safety gating
JTAG/UART level shifters: high-Z target side when VREF invalid or TARGET_EN low
TCK/TMS/TDI/nTRST/nSRST: series damping footprints near driver
TDO/UART_TXD: no debugger-side pull that fights target output
Reset pins: target-side pull-ups define inactive high
Indicators: USB power and VREF-present LEDs
```

## 7. Bring-Up Expectations

The first board must pass the same chip-side debug flow as remote-bitbang:

```text
OpenOCD TAP IDCODE 0x100001cf
hart 0 XLEN=32
misa=0x40000100
two triggers discovered
GDB register read
GDB native stepi
GDB hbreak at 0x4
UART loopback or target-console smoke
```
