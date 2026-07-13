# FT2232H Debugger Rev A Design Spec

## 1. Design Objective

Rev A is a USB-powered companion debugger for wasp1. FT2232H Channel A carries
OpenOCD-compatible MPSSE JTAG, while Channel B remains a standard UART for the
console and OTP programming transport. Target-facing IO supports 1.8 V through
3.3 V without back-powering an unpowered target.

The authoritative formal EDA source belongs under:

```text
ftdi_debugger/hw/kicad/wasp1_ft2232h_debugger_revA/
```

Editable board block diagram:

```text
ftdi_debugger/docs/diagrams/ftdi_debugger_revA_block.graffle
```

The diagram uses native explicit line segments, V-shaped arrowheads, a visible
5 pt grid, and separate POWER, CLOCK, IF, and COMB blocks. No block combines
sequential and combinational timing labels.

## 2. Circuit Partition

```text
USB-C J1
  -> USBLC6-2SC6 ESD1 -> FT2232HL U1 USB PHY
  -> MF-MSMF050 F1 -> AP2112K-3.3 U6 -> VCC_3V3

FT2232HL U1
  -> Channel A ADBUS0..5 -> SN74AXC8T245 U4 -> JTAG/reset outputs
  -> Channel A ADBUS2 <- SN74AXC2T245 U5 <- target TDO
  -> Channel A ADBUS6 -> TARGET_EN safety gate
  -> Channel B BDBUS0 -> U4 -> target UART_RXD
  -> Channel B BDBUS1 <- U5 <- target UART_TXD

Target VREF
  -> TLV7041 U3 -> VREF_VALID
VREF_VALID + TARGET_EN
  -> SN74LVC1G00 U7 -> SHIFT_OE_N -> U4/U5
VREF_VALID -> 2N7002 Q1 -> isolated amber status LED D2
```

## 3. Frozen Major Components

| Refdes | Selected part | Reason |
| --- | --- | --- |
| U1 | FT2232HL, LQFP-64 | Dual channel, Channel A MPSSE plus Channel B UART; hand-assembly-friendly package |
| U2 | 93LC56BT-I/SN | Production Microwire EEPROM; optional/DNI when default FTDI descriptors are sufficient |
| U3 | TLV7041DBVR | Open-drain, rail-to-rail-input comparator powered from 3.3 V |
| U4 | SN74AXC8T245PWR | Six same-direction target outputs, 0.65 V to 3.6 V rails, Ioff and VCC isolation |
| U5 | SN74AXC2T245RSWR | Two target inputs, independent direction pins, Ioff and VCC isolation |
| U6 | AP2112K-3.3TRG1 | 600 mA USB-to-3.3 V LDO in SOT-25 |
| U7 | SN74LVC1G00DBVR | Fail-safe active-low OE generation from two active-high qualifiers |
| Q1 | 2N7002, SOT-23 | Isolates the VREF-valid logic net from D2 indicator current |
| Y1 | ECS-3225MVQ-120-CN-TR | 12 MHz, 3.3 V, +/-25 ppm oscillator meeting the FTDI OSCI tolerance |
| ESD1 | USBLC6-2SC6 | Low-capacitance USB2 D+/D- protection |
| ESD2 | TPD8E003DQDR | Eight target-header GPIO/JTAG/UART ESD channels |
| J1 | GCT USB4105-GF-A family | USB2-only Type-C receptacle with independent CC1/CC2 pins |
| J2 | Keyed 2x7, 2.54 mm IDC header | Fixed wasp1 target pinout and cable keying |

## 4. USB And Power

J1 is a USB device receptacle. CC1 and CC2 each use an independent 5.1 kOhm
1% pulldown. VBUS passes through a 500 mA hold resettable fuse before U6.
USB D+ and D- pass through ESD1 and are routed as a 90 Ohm differential pair
without stubs. U6 supplies VCC_3V3 to FT2232H VCCIO/VPHY/VPLL/VREGIN and the
local side of both translators.

FT2232H VREGOUT supplies VCORE and receives the datasheet-required minimum
3.3 uF local capacitor. Every VCCIO/VPHY/VPLL/VREGIN pin receives a 100 nF
local capacitor, with 4.7 uF bulk capacitance on VCC_3V3. REF uses 12 kOhm 1%
to ground. TEST is grounded. RESET_N is pulled high with 10 kOhm.

Y1 drives OSCI at 12 MHz; OSCO is left unconnected. U2 connects EECS and
EECLK directly and ties its DI/DO data pins to the bidirectional EEDATA net.

## 5. Target Isolation

U3 compares VREF against a nominal 1.57 V divider reference. Its open-drain
output is pulled up to VCC_3V3 and is high only for a valid target rail. The
threshold leaves margin below the minimum supported 1.8 V VREF.

FT_TARGET_EN is ADBUS6 with a 100 kOhm pulldown. At FT2232H power-up Channel A
is not yet MPSSE, so the pulldown keeps the target isolated. OpenOCD drives
ADBUS6 high only after applying:

```text
ftdi layout_init 0x0078 0x007b
```

U7 implements:

```text
SHIFT_OE_N = !(VREF_VALID && FT_TARGET_EN)
```

U4 and U5 are therefore disabled unless both the target voltage and host-side
JTAG ownership are valid. Their VCC isolation and Ioff behavior provide a
second barrier when VREF is absent.

Q1 uses `VREF_VALID` only as a MOSFET gate input. D2 current flows from
`VCC_3V3` through RLED2 and D2 into Q1, so the indicator cannot pull down the
U7 input. A 10 kOhm RVALID pullup defines the comparator logic-high level.

## 6. Signal Direction

U4 VCCA is VCC_3V3 and VCCB is VREF. Both direction banks are fixed A-to-B.
Its active channels are TCK, TDI, TMS, nTRST, nSRST, and UART_RXD. U5 uses the
same rails with each direction fixed B-to-A for TDO and UART_TXD. All U4 target
outputs include 33 Ohm series-damping footprints near U4.

Unused U4 A7 and A8 are separately biased low through 10 kOhm RU4_A7 and
RU4_A8. This avoids floating CMOS inputs while preserving the bidirectional
translator pins as ordinary protected inputs rather than hard ground shorts.

ESD2 protects the eight J2 signal pins. It is placed at J2, ahead of long board
routes. VREF is sense-only and is never connected to VCC_3V3.

## 7. PCB Constraints

```text
board: four layers preferred (signal / ground / power / signal)
USB D+/D-: 90 Ohm differential, matched within 0.5 mm, continuous ground plane
TCK: shortest target path, 33 Ohm source resistor, no stubs
ESD1/ESD2: connector-side placement before protected circuitry
U1 decoupling: each capacitor within 3 mm of its supply pin
VREF: no copper-plane use beyond U3/U4/U5 and local decoupling
target signals: keep at least 0.25 mm from USB pair
test points: VCC_3V3, VCORE, VREF, VREF_VALID, TARGET_EN, SHIFT_OE_N, TCK, TDO
```

## 8. Source References

```text
FTDI DS_FT2232H Version 2.9
TI SN74AXC8T245 datasheet SCES875C
TI SN74AXC2T245 datasheet SCES879A
TI TLV703x/TLV704x datasheet
TI TPD8E003 datasheet SLLSE38B
ST USBLC6-2SC6 datasheet
Microchip 93LC56B product data
GCT USB4105 product specification
```
