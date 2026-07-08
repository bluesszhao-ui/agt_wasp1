# ftdi_debugger Hardware

This directory is reserved for the final FTDI debugger hardware collateral:

```text
schematic source
schematic PDF
PCB layout
gerbers
BOM
assembly notes
bring-up notes
```

No schematic or PCB source is checked in yet.

The first schematic revision must follow:

```text
../docs/ftdi_debugger_pinout.md
../openocd/wasp1_ft2232h_reference.cfg
```

Before PCB work, keep the schematic pin mapping, target connector silk, and
OpenOCD layout masks synchronized. The repository-level static check is:

```text
make -C ftdi_debugger lint
```
