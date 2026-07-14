# FT2232H Debugger Rev A Manufacturing Release Checklist

## Release Disposition

```text
engineering package: PASS
fabrication release: HOLD - DO NOT ORDER
review date: 2026-07-14
```

The engineering outputs are internally consistent and reproducible.  The HOLD
is intentional: three external confirmations cannot be replaced by local DRC
or scripts.

## Automated And Local Review

| Gate | Status | Evidence |
| --- | --- | --- |
| Schematic parity | PASS | Final PCB DRC reports zero parity issues |
| PCB connectivity | PASS | Zero unconnected pads; 695 routed segments and 72 vias |
| PCB geometry | PASS | Closed 110 mm x 65 mm outline; 1.6 mm source-board thickness |
| USB routing | PASS | Pre-ESD skew 0.463216 mm; post-ESD skew 0.414214 mm; both <= 0.50 mm |
| J1 geometry | PASS | 16 signal pads, 4 plated shell slots, 2 NPTH pegs, reviewed D+/D- pad order |
| J2 geometry | PASS | 14 pins on a 2.54 mm grid with 1.0 mm drills and keyed vertical footprint |
| Gerber set | PASS | Nine X2 layers, common absolute 4.6 metric coordinates, expected polarity |
| Board profile | PASS | Four-edge closed profile, 350 mm perimeter, no output coordinates outside it |
| Drill set | PASS | 65 x 0.30 mm vias, 7 x 0.40 mm vias, 14 x 1.00 mm PTH, 4 plated slots, 2 x 0.65 mm NPTH |
| Placement output | PASS | 48 unique top-side fitted references; U2 and TP1-TP8 excluded |
| Production BOM | PASS | All 57 board references covered: 48 POP, 1 DNP, 8 PCB_ONLY |
| Assembly drawing render | PASS | Top drawing legible and unclipped; sparse mirrored bottom drawing is intentional |
| Electrical-test data | PASS | IPC-D-356 identification and USB_VBUS net records present |

## External Release Gates

| Gate | Status | Required sign-off |
| --- | --- | --- |
| Fabricator impedance review | HOLD | Fabricator stackup calculation confirms 90 ohm nominal USB D+/D- and accepted width/gap |
| Independent visual CAM review | HOLD | Second person opens Gerbers and drills in a CAM viewer and signs layer order, polarity, slots, outline, and drill alignment |
| Procurement review | HOLD | Buyer rechecks stock, lifecycle, MOQ, lead time, and exact suffixes; J2 primary had zero distributor stock at the 2026-07-14 check |
| First-article assembly | HOLD | Polarity, pin 1, connector keying, solder joints, and pre-power resistance checks signed |
| Physical bring-up | HOLD | USB enumeration, rails, VREF isolation, OpenOCD/GDB JTAG, and UART OTP smoke pass on hardware |

## Ordered-Part Controls

```text
J1: GCT USB4105-GF-A-120
J2 primary: Samtec TST-107-01-L-D
J2 approved mechanical/plating candidate: TST-107-01-G-D
U1: FTDI FT2232HL-REEL
CCORE: Murata GRM188R61A335KE15D
```

The J2 alternate is not an automatic AVL substitution. Procurement must
confirm plating and mating-cable requirements before use. Every change to J1,
J2, U4, U5, U1, CCORE, the stackup, or USB geometry requires an engineering
change review and regeneration of all manufacturing outputs.

## Sign-Off

| Role | Name | Date | Result / notes |
| --- | --- | --- | --- |
| PCB design owner |  |  |  |
| Independent CAM reviewer |  |  |  |
| Fabricator CAM engineer |  |  |  |
| Procurement |  |  |  |
| Assembly first-article reviewer |  |  |  |
| Bring-up owner |  |  |  |
