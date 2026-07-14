# FT2232H Debugger Rev A Assembly Notes

## Population

U2 is DNP by default. Populate it only when custom FTDI descriptors or a fixed
serial-number policy are required. All other references are populated unless a
released BOM revision explicitly says otherwise.

TP1 through TP8 are exposed 1.0 mm PCB copper pads, not fitted test-point
components. They are intentionally excluded from the procurement BOM and
pick-and-place output. The Rev A position CSV therefore contains 48 fitted
components.

All components are mounted on the top side in Rev A. The mirrored bottom
assembly drawing therefore contains only through-hole and mechanical-hole
locations; this sparse result is intentional.

## Critical Orientation

```text
J1: shell opening faces the left board edge
J2: keyed shroud opening follows the target-cable drawing
U1: verify LQFP pin 1 before reflow
U3/U6/U7/Q1: verify SOT pin 1/orientation marks
D1/D2: verify LED cathode marks
ESD1/ESD2: verify pin 1 and connector-side placement
```

Inspect the fine-pitch U1, U4, and U5 pins for bridges. Confirm that every J1
shield/mechanical pad is soldered and that all J2 through-hole pins have full
barrel fill.

CCORE is `GRM188R61A335KE15D` (3.3 uF, 10 V, X5R, 0603). FTDI specifies a
minimum 3.3 uF VCORE filter capacitor; do not substitute a lower effective
capacitance after DC-bias derating review.

## Pre-Power Checks

```text
VBUS to GND: no short
VCC_3V3 to GND: no short
VCORE to GND: no short
VREF to VCC_3V3: open circuit
SHIFT_OE_N: pulled high while target VREF is absent
FT_TARGET_EN: held low before OpenOCD ownership
```

Power from a current-limited USB source for first bring-up. Verify VCC_3V3 and
VCORE before connecting a wasp1 target. Physical bring-up then follows
`ftdi_debugger/docs/ftdi_debugger_verification_plan.md`.
