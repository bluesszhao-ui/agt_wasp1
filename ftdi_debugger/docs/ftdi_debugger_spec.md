# ftdi_debugger Spec

## 1. Purpose

`ftdi_debugger` is the final external hardware debugger for wasp1. It converts
host USB traffic into standard JTAG signals for the wasp1 RISC-V Debug Module
and optionally exposes a UART channel for console and OTP programming flows.

This block is not part of the wasp1 chip RTL. It is a companion hardware tool.

## 2. Required Host Flow

```text
GDB
  -> OpenOCD ftdi adapter driver
  -> FTDI USB device
  -> wasp1 JTAG header or FPGA pins
  -> debug_jtag_dtm
  -> debug
  -> core debug interface
```

The debugger must support the existing OpenOCD/GDB smoke flow already verified
with the Verilator remote-bitbang harness, including register reads, native
`stepi`, and one hardware breakpoint through `hbreak`.

## 3. Hardware Baseline

| Item | Requirement |
| --- | --- |
| USB bridge | FT2232H preferred |
| JTAG channel | FT2232H Channel A in MPSSE mode |
| UART channel | FT2232H Channel B reserved for UART console / OTP programming |
| JTAG pins | TCK, TMS, TDI, TDO |
| Reset pins | Optional nTRST and nSRST routed as controllable GPIO |
| Target voltage | Sense target VREF and level-shift JTAG/UART accordingly |
| Protection | ESD protection on external connector pins |
| Connector | One wasp1 target header carrying JTAG, reset, UART, VREF, and GND |
| Indicators | USB power, target VREF present, optional JTAG activity |

The stage-1 pinout and schematic-input constraints are frozen in:

```text
ftdi_debugger/docs/ftdi_debugger_pinout.md
```

## 4. FT2232H Reference Pin Use

The initial reference mapping is:

| FT2232H signal | Function |
| --- | --- |
| ADBUS0 | TCK |
| ADBUS1 | TDI |
| ADBUS2 | TDO |
| ADBUS3 | TMS |
| ADBUS4 | nTRST |
| ADBUS5 | nSRST |
| BDBUS0 | UART TX to target RX |
| BDBUS1 | UART RX from target TX |

This mapping may change during schematic work, but the final OpenOCD config and
PCB silk must match the chosen mapping exactly.

## 5. Software Contract

The debugger must be usable from OpenOCD without custom host software:

```text
adapter driver ftdi
transport select jtag
jtag newtap wasp1 cpu -irlen 5 -expected-id 0x100001cf
target create wasp1.cpu riscv -chain-position wasp1.cpu
```

FTDI EEPROM programming may set product strings and serial numbers, but the
debug flow must not require a private protocol.

The checked-in reference config is:

```text
ftdi_debugger/openocd/wasp1_ft2232h_reference.cfg
```

It uses FT2232H VID/PID `0x0403:0x6010`, Channel A, `layout_init 0x0038
0x003b`, nTRST bit `0x0010`, and nSRST bit `0x0020`.

## 6. Non-Goals

The stage-1 debugger does not need:

```text
USB firmware development
SWD support
trace capture
high-speed streaming trace
boundary scan tooling beyond the wasp1 JTAG chain
custom OpenOCD target driver
```
