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
editable block diagram, native four-sheet KiCad schematic, routed four-layer
PCB, Windows/Linux host setup, tested UART OTP client, and a simulated RV32I
I-SRAM target loader are present. ERC has
zero violations; final PCB DRC has zero errors, zero unconnected pads, and zero
schematic parity errors. The ADBUS6 `FT_TARGET_EN` gate keeps the target
isolated until OpenOCD explicitly enables it after MPSSE setup. Independent
local manufacturing review now passes, including Gerber/drill geometry, 48
fitted placement rows, and full production-BOM coverage. Fabrication is still
HOLD pending board-shop USB impedance sign-off, second-person CAM review,
procurement confirmation, and physical board bring-up.

Run the documentation/config consistency check with:

```text
make -C ftdi_debugger lint
make -C ftdi_debugger host-test
make -C ftdi_debugger kicad-pcb-placement-drc
make -C ftdi_debugger kicad-pcb-final-drc
make -C ftdi_debugger kicad-pcb-manufacturing
make -C ftdi_debugger kicad-manufacturing-release
```
