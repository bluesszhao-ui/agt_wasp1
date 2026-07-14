# FT2232H Debugger Rev A Manufacturing Review Report

## Result

The Rev A engineering manufacturing package passes local automated and visual
review. Fabrication release remains **HOLD - DO NOT ORDER** pending fabricator
impedance sign-off, independent human CAM review, and procurement availability
confirmation.

This distinction matters: DRC proves consistency with the present design
rules, but it cannot choose a board shop's dielectric materials, inspect a CAM
view with independent human judgment, or guarantee current component stock.

## Review Sequence

| Sequence | Action | Expected | Observed |
| --- | --- | --- | --- |
| 1 | Run final KiCad DRC and schematic parity | No routing, clearance, or parity failures | PASS: 0 errors, 0 unconnected pads, 0 parity errors; 2 reviewed local-footprint warnings |
| 2 | Read the committed PCB with KiCad `pcbnew` | Frozen outline, stack, J1/J2 geometry, test-pad attributes, and USB routing | PASS: 110 mm x 65 mm, 1.6 mm, J1/J2 exact geometry, TP1-TP8 PCB-only |
| 3 | Parse Gerber X2 independently of the board source | Nine correctly identified layers in one coordinate system | PASS: expected functions/polarities and all coordinates within the profile |
| 4 | Reconstruct the Edge.Cuts graph | One closed manufacturable outline | PASS: four vertices, four edges, 350 mm perimeter |
| 5 | Parse Excellon tools, hits, and routed slots | Drill inventory agrees with board statistics and connector geometry | PASS: 86 round PTH, 4 plated slots, 2 NPTH |
| 6 | Audit pick-and-place records | Only physical fitted parts are emitted | PASS: corrected from 56 to 48 rows by excluding PCB-only TP1-TP8 |
| 7 | Cross-check production BOM against all board footprints | Exact MPN, package, population, source, and lifecycle-review date per reference | PASS: 48 POP, 1 DNP, 8 PCB_ONLY |
| 8 | Rasterize top and bottom assembly PDFs | No clipping, overlap, or unintended bottom-side population | PASS |

## Findings Resolved

### PCB-only test pads in placement output

TP1-TP8 use `TestPoint_Pad_D1.0mm`, which is an exposed copper pad rather than
a purchased component. The board generator had overridden the footprint
library's BOM/position exclusions, causing eight false placement rows. The
override was removed, the committed PCB and schematic were corrected, and the
manufacturing audit now requires exactly 48 fitted rows.

### Board-thickness reporting

The source-board finished thickness and copper-plus-dielectric stack both equal
1.6 mm. KiCad statistics report 1.6200 mm because the modeled 0.01 mm solder
mask on each side is included. Fabrication notes now state the distinction so
1.62 mm is not ordered as the substrate thickness.

### VCORE capacitor specification

The earlier descriptive BOM called CCORE 3.3 uF X7R in 0603. The production
selection is now Murata `GRM188R61A335KE15D`, 3.3 uF, 10 V, X5R, 0603. This
matches the board footprint and FTDI's minimum 3.3 uF VCORE filter requirement.

### Connector order codes

J1 is fixed to GCT `USB4105-GF-A-120`. J2 is fixed to Samtec
`TST-107-01-L-D`, with `TST-107-01-G-D` listed only as a procurement-controlled
candidate. Automated geometry checks freeze J1's USB pad order, shell slots,
and locating holes and J2's 2.54 mm pin grid and drill size.

## Remaining Holds

1. The board shop must calculate and sign the 90 ohm USB differential geometry
   for its actual four-layer materials and copper process.
2. A second person must inspect the Gerber/drill package in a CAM viewer.
3. Procurement must recheck exact suffixes, MOQ, stock, lifecycle, and approved
   alternates immediately before order placement.
4. First-article assembly and physical OpenOCD/GDB/UART bring-up remain
   hardware-only evidence.

The controlled gate and signature table are in
`hw/fabrication/wasp1_ft2232h_debugger_revA_release_checklist.md`.
