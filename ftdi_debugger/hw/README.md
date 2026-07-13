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

The checked-in Rev A source package is:

```text
kicad/wasp1_ft2232h_debugger_revA/wasp1_ft2232h_debugger_revA.kicad_sch
schematic/wasp1_ft2232h_debugger_revA_schematic.md
schematic/wasp1_ft2232h_debugger_revA.pdf
schematic/svg/
netlist/wasp1_ft2232h_debugger_revA_nets.csv
bom/wasp1_ft2232h_debugger_revA_bom.csv
```

Its detailed electrical design and editable architecture diagram are:

```text
../docs/ftdi_debugger_revA_design_spec.md
../docs/diagrams/ftdi_debugger_revA_block.graffle
```

This is not yet a PCB release. The native four-sheet KiCad hierarchy passes
KiCad 10 ERC with zero errors and zero warnings. PCB capture and DRC remain the
next hardware milestone.

The PDF is a stable five-page A3 review preview assembled from individually
rendered sheets. The native KiCad hierarchy remains the electrical source of
truth; SVG exports provide vector page review.

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
