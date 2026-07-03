# wasp1 FTDI Debugger

This directory tracks the external FTDI-based hardware debugger planned for
the final wasp1 bring-up flow.

The debugger is outside the wasp1 SoC RTL. It is a board-level tool that
connects a host PC running OpenOCD/GDB to the wasp1 JTAG pins.

```text
GDB -> OpenOCD -> FTDI debugger -> wasp1 JTAG pins -> debug_jtag -> debug -> core
```

Planned baseline:

```text
USB bridge: FT2232H
Channel A: MPSSE JTAG
Channel B: UART for console / OTP programming flow
Target interface: VREF-sensed level-shifted JTAG, optional SRST/TRST
Primary software: OpenOCD ftdi driver plus wasp1 target config
```

Current status: requirements and bring-up plan only; PCB/schematic files are a
later hardware milestone.

