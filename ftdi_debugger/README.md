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

Current status: the requirements, pinout, OpenOCD config, Rev A BOM/netlist,
editable block diagram, and native four-sheet KiCad schematic are present. The
schematic passes KiCad 10 ERC with zero errors and zero warnings. The ADBUS6
`FT_TARGET_EN` gate keeps the target isolated until OpenOCD explicitly enables
it after MPSSE setup. PCB layout and board bring-up remain hardware milestones.

Run the documentation/config consistency check with:

```text
make -C ftdi_debugger lint
```
