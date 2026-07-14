# FT2232H Debugger Rev A Fabrication Notes

## Board Definition

```text
finished size: 110 mm x 65 mm
layers: 4
finished thickness: 1.6 mm
finish: ENIG
outer copper: 1 oz minimum
inner copper: 1 oz minimum
solder mask: both sides
silkscreen: both sides
controlled impedance: USB D+/D- differential pair, 90 ohm nominal
```

The fabrication house must calculate the dielectric stack for its process and
confirm the final USB trace width and gap before release. The current native
layout uses the project differential-pair geometry as the design baseline; the
board must not be ordered before that impedance review is signed off.

## Manufacturing Outputs

Run the release target only from a final-DRC-clean source board:

```text
make -C ftdi_debugger kicad-pcb-manufacturing
```

The target writes generated outputs under `ftdi_debugger/build/manufacturing/`:

```text
Gerber X2 copper, mask, silkscreen, and board-edge layers
separate plated and non-plated Excellon drill files plus maps/report
component position CSV with DNP U2 excluded
IPC-D-356 electrical test netlist
board statistics JSON
top and mirrored-bottom assembly PDFs
```

## Release Gates

```text
KiCad ERC: zero violations
final PCB DRC: zero errors and zero unconnected pads
schematic parity: zero errors
J1/J2 board-local footprint warnings: independently reviewed
USB pair impedance: confirmed against the selected fabricator stackup
Gerber/drill viewer review: completed by a second reviewer
BOM manufacturer part numbers and lifecycle: confirmed
assembly polarity and pin-1 review: completed
```

The two local-footprint warnings are not blanket exclusions. Their pad maps,
mechanical holes, board-edge position, and mating orientation must be checked
against the ordered J1 and J2 manufacturer drawings for every release.
