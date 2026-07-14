# FT2232H Debugger Rev A Fabrication Notes

## Board Definition

```text
finished size: 110 mm x 65 mm
layers: 4
finished PCB thickness: 1.6 mm nominal
finish: ENIG
outer copper: 1 oz minimum
inner copper: 1 oz minimum
solder mask: both sides
silkscreen: both sides
controlled impedance: USB D+/D- differential pair, 90 ohm nominal
```

The KiCad source has a 1.6 mm board-thickness field.  Its four 35 um copper
layers and three dielectric layers (0.18 mm / 1.10 mm / 0.18 mm) also total
1.6 mm.  KiCad's generated statistics report 1.6200 mm because that report
adds the two modeled 0.01 mm solder-mask layers.  The purchase requirement is
therefore a nominal 1.6 mm finished PCB, not a 1.62 mm substrate.

The fabrication house must calculate the dielectric stack for its process and
confirm the final USB trace width and gap before release. The current native
layout uses the project differential-pair geometry as the design baseline; the
board must not be ordered before that impedance review is signed off. A
fabricator-adjusted stack or geometry must return through KiCad DRC and the
manufacturing audit before it becomes a released revision.

## Manufacturing Outputs

Run the release target only from a final-DRC-clean source board:

```text
make -C ftdi_debugger kicad-pcb-manufacturing
```

The target writes generated outputs under `ftdi_debugger/build/manufacturing/`:

```text
Gerber X2 copper, mask, silkscreen, and board-edge layers
separate plated and non-plated Excellon drill files plus maps/report
component position CSV with DNP U2 and PCB-only TP1-TP8 excluded (48 rows)
IPC-D-356 electrical test netlist
board statistics JSON
top and mirrored-bottom assembly PDFs
```

`make -C ftdi_debugger kicad-manufacturing-release` additionally creates a
self-contained ZIP and SHA-256 manifest under `ftdi_debugger/build/release/`.
Generated release archives are not committed.

## Release Gates

```text
KiCad ERC: zero violations
final PCB DRC: zero errors and zero unconnected pads
schematic parity: zero errors
J1 exact order code: GCT USB4105-GF-A-120
J2 exact primary order code: Samtec TST-107-01-L-D
J1/J2 board-local footprint warnings: automated geometry review passed
USB pair impedance: confirmed against the selected fabricator stackup
Gerber/drill viewer review: completed by a second reviewer
BOM manufacturer part numbers and lifecycle: confirmed
assembly polarity and pin-1 review: completed
```

The two local-footprint warnings are not blanket exclusions. Their pad maps,
mechanical holes, board-edge position, and mating orientation must be checked
against the ordered J1 and J2 manufacturer drawings for every release.

Current release disposition is **HOLD - DO NOT ORDER** until the fabricator
impedance calculation, a second-person Gerber/drill review, and procurement
availability recheck are signed in the release checklist.
