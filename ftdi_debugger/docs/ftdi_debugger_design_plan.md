# ftdi_debugger Design Plan

## 1. Partition

```text
USB-C / USB-B connector
  -> ESD and power protection
  -> FT2232H
     -> Channel A MPSSE JTAG
     -> Channel B UART
  -> target-voltage sensing and level shifters
  -> wasp1 target connector
```

## 2. Design Steps

| Step | Work Item | Output |
| ---: | --- | --- |
| 1 | Freeze connector pinout and voltage range | pinout table and schematic constraints |
| 2 | Choose FT2232H power/clock/EEPROM circuit | schematic page |
| 3 | Define JTAG/UART level shifting | schematic page and timing/voltage notes |
| 4 | Write OpenOCD FTDI config for the final pin mapping | checked-in `.cfg` |
| 5 | Build PCB | schematic, layout, BOM, assembly notes |
| 6 | Electrical bring-up | USB enumeration and voltage checks |
| 7 | JTAG bring-up | OpenOCD IDCODE/DTM/hart detection on FPGA |
| 8 | GDB bring-up | register read, halt/resume, step/breakpoint milestones |

Step 1 has a stage-1 reference output:

```text
ftdi_debugger/docs/ftdi_debugger_pinout.md
```

Steps 2 and 3 now have a Rev A schematic-input package:

```text
ftdi_debugger/hw/schematic/wasp1_ft2232h_debugger_revA_schematic.md
ftdi_debugger/hw/netlist/wasp1_ft2232h_debugger_revA_nets.csv
ftdi_debugger/hw/bom/wasp1_ft2232h_debugger_revA_bom.csv
```

The reference OpenOCD output for step 4 is:

```text
ftdi_debugger/openocd/wasp1_ft2232h_reference.cfg
```

## 3. Design Notes

Use FT2232H rather than FT232H as the default because the second channel can be
used as a UART. That keeps the final wasp1 development setup simple:

```text
one USB cable -> JTAG debug + UART console / OTP programming
```

Target VREF must define the IO level seen by the target. The debugger should
not drive JTAG or UART pins when VREF is absent.

The first schematic should implement target-facing high-Z behavior by gating
the level-shifter output enables with a valid VREF indication. JTAG reset
signals are active-low and should idle high through both OpenOCD layout data and
target-side pull-ups.

## 4. Relationship To Current Simulation

The current Verilator remote-bitbang flow proves the chip-side JTAG/DTM/DM
contract before hardware exists:

```text
current: OpenOCD -> remote_bitbang TCP -> Vwasp1 JTAG pins
final:   OpenOCD -> FT2232H MPSSE -> real wasp1 JTAG pins
```

The OpenOCD target section should remain shared between both flows where
practical.

The current chip-side smoke now includes:

```text
register read
native GDB stepi
one OpenOCD/GDB hardware breakpoint at 0x4
```

The FTDI debugger bring-up should reuse that exact GDB script before adding
board-specific stress tests.

## 5. Current Hardware Package Status

The Rev A hardware package freezes the intended FT2232H channel split, target
header, VREF-valid level-shifter enable policy, initial BOM classes, and
netlist-level signal ownership. Formal EDA schematic capture, PCB layout,
gerbers, assembly files, and physical bring-up remain later hardware steps.
