# ftdi_debugger Hardware

This directory holds the FTDI debugger hardware collateral:

```text
schematic source
schematic PDF
PCB layout
gerbers
BOM
assembly notes
bring-up notes
```

The first checked-in Rev A schematic-input package is:

```text
schematic/wasp1_ft2232h_debugger_revA_schematic.md
netlist/wasp1_ft2232h_debugger_revA_nets.csv
bom/wasp1_ft2232h_debugger_revA_bom.csv
```

This is not yet a PCB release. It is the reviewable source of truth for drawing
the formal EDA schematic and then the board layout.

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
